# frozen_string_literal: true

require "telegram/bot"

module Ask
  module ChannelProviders
    module Telegram
      # Polling-based Telegram bot client.
      #
      # Receives messages via getUpdates polling and wraps the telegram-bot-ruby
      # client with a simpler interface.
      #
      # @example
      #   bot = Ask::ChannelProviders::Telegram::Bot.new(token: "123:ABC")
      #   bot.on_message { |msg| puts msg[:text] }
      #   bot.start
      #   bot.send_message(chat_id: 123, text: "Hello")
      #   bot.stop
      class Bot
        attr_reader :token, :bot_user_id
        attr_accessor :on_callback

        # @param token [String] Telegram bot token from @BotFather
        MAX_DEDUP_CACHE = 500

        def initialize(token:)
          @token = token
          @client = ::Telegram::Bot::Client.new(token)
          @running = false
          @on_message = nil
          @on_callback = nil
          @poll_thread = nil
          @last_update_id = 0
          @bot_user_id = nil
          @processed_updates = []  # ring buffer of recent update_ids
        end

        # Start polling for messages.
        #
        # @param interval [Float] seconds between polls
        # @param on_message [Proc] called with { chat_id:, user_id:, text:, date:, raw: }
        # @param on_callback [Proc] called with { callback_query_id:, data:, chat_id:, user_id:, message_id: }
        def start(interval: 1.0, &on_message)
          @on_message = on_message
          @running = true
          fetch_bot_info
          @poll_thread = Thread.new { poll_loop(interval) }
        end

        # Stop polling.
        def stop
          @running = false
          @poll_thread&.join(5) rescue nil
          @poll_thread = nil
        end

        def running?
          @running
        end

        # Send a text message to a chat.
        def send_message(chat_id:, text:, parse_mode: nil)
          $stdout.puts "[send] msg #{text.length}ch#{parse_mode ? " (#{parse_mode})" : ""}" if ENV["DEBUG"] == "1"
          params = { chat_id: chat_id, text: text }
          params[:parse_mode] = parse_mode if parse_mode
          @client.api.send_message(params)
        rescue ::Telegram::Bot::Exceptions::Base => e
          $stdout.puts "[send] FAIL: #{e.message[0..80]}" if ENV["DEBUG"] == "1"
          raise Ask::ChannelProviders::APIError, "Telegram API error: #{e.message}"
        end

        # Send a message with inline keyboard buttons.
        def send_keyboard_message(chat_id:, text:, buttons:, parse_mode: nil)
          n = buttons.flatten.length
          $stdout.puts "[send] #{n} btn(s), #{text.length}ch" if ENV["DEBUG"] == "1"
          reply_markup = { inline_keyboard: buttons }
          params = { chat_id: chat_id, text: text, reply_markup: reply_markup }
          params[:parse_mode] = parse_mode if parse_mode
          @client.api.send_message(params)
        rescue ::Telegram::Bot::Exceptions::Base => e
          $stdout.puts "[send] KEYBOARD FAIL: #{e.message[0..80]}" if ENV["DEBUG"] == "1"
          raise Ask::ChannelProviders::APIError, "Telegram API error: #{e.message}"
        end

        # Answer a callback query (required by Telegram, removes the loading spinner).
        def answer_callback_query(callback_query_id:, text: nil)
          $stdout.puts "[send] callback answer" if ENV["DEBUG"] == "1"
          params = { callback_query_id: callback_query_id }
          params[:text] = text if text
          @client.api.answer_callback_query(params)
        rescue ::Telegram::Bot::Exceptions::Base
          # Silently ignore errors
        end

        # Edit a message (for streaming updates).
        def edit_message(chat_id:, message_id:, text:, parse_mode: nil)
          $stdout.puts "[send] edit msg #{message_id} #{text.length}ch" if ENV["DEBUG"] == "1"
          params = { chat_id: chat_id, message_id: message_id, text: text }
          params[:parse_mode] = parse_mode if parse_mode
          @client.api.edit_message_text(params)
        rescue ::Telegram::Bot::Exceptions::Base => e
          desc = e.respond_to?(:data) ? (e.data[:description] || e.data["description"] || e.message) : e.message
          raise Ask::ChannelProviders::APIError, e.message unless desc.include?("message is not modified")
        end

        # Delete a message.
        def delete_message(chat_id:, message_id:)
          @client.api.delete_message(chat_id: chat_id, message_id: message_id)
        rescue ::Telegram::Bot::Exceptions::Base
          # Silently ignore if already deleted
        end

        # Get bot info.
        def me
          @me ||= @client.api.get_me
        rescue ::Telegram::Bot::Exceptions::Base => e
          raise Ask::ChannelProviders::APIError, "Failed to get bot info: #{e.message}"
        end

        private

        def fetch_bot_info
          info = me
          @bot_user_id = info.id if info
        rescue => e
          # Bot info unavailable (e.g., test tokens), continue without it
        end

        def poll_loop(interval)
          while @running
            begin
              fetch_updates
            rescue => e
              # Log error, continue polling
            end
            sleep(interval)
          end
        end

        def fetch_updates
          params = { offset: @last_update_id + 1, timeout: 5 }
          updates = @client.api.get_updates(params)
          updates = Array(updates)
          updates.each do |update|
            process_update(update)
            uid = update.respond_to?(:update_id) ? update.update_id : nil
            @last_update_id = uid if uid && uid >= @last_update_id
          end
        rescue ::Telegram::Bot::Exceptions::Base => e
          raise Ask::ChannelProviders::APIError, "Polling error: #{e.message}"
        end

        def process_update(update)
          # Dedup: skip already-processed update_ids
          uid = update.respond_to?(:update_id) ? update.update_id : nil
          if uid && @processed_updates.include?(uid)
            return
          end
          @processed_updates << uid if uid
          @processed_updates.shift if @processed_updates.length > MAX_DEDUP_CACHE

          # Handle callback queries (inline keyboard button clicks)
          if update.respond_to?(:callback_query) && update.callback_query
            handle_callback_query(update.callback_query)
            return
          end

          message = extract_message(update)
          return unless message

          chat = message.respond_to?(:chat) ? message.chat : nil
          from = message.respond_to?(:from) ? message.from : nil
          text = message.respond_to?(:text) ? message.text : nil
          return unless chat && text

          chat_type = chat.respond_to?(:type) ? chat.type.to_s : ""

          msg = {
            chat_id: chat.respond_to?(:id) ? chat.id : nil,
            user_id: from.respond_to?(:id) ? from.id : nil,
            text: text,
            date: message.respond_to?(:date) ? message.date : nil,
            is_group: %w[group supergroup].include?(chat_type),
            message_id: message.respond_to?(:message_id) ? message.message_id : nil,
            raw: message
          }

          @on_message&.call(msg)
        end

        def handle_callback_query(cq)
          return unless @on_callback
          data = cq.respond_to?(:data) ? cq.data : nil
          msg = cq.respond_to?(:message) ? cq.message : nil
          from = cq.respond_to?(:from) ? cq.from : nil
          return unless data && msg && from

          @on_callback.call(
            callback_query_id: cq.respond_to?(:id) ? cq.id : nil,
            data: data,
            chat_id: msg.respond_to?(:chat) && msg.chat.respond_to?(:id) ? msg.chat.id : nil,
            user_id: from.respond_to?(:id) ? from.id : nil,
            message_id: msg.respond_to?(:message_id) ? msg.message_id : nil,
            raw: cq
          )
        end

        def extract_message(update)
          m = update.respond_to?(:message) ? update.message : nil
          m ||= update.respond_to?(:channel_post) ? update.channel_post : nil
          m ||= update.respond_to?(:edited_message) ? update.edited_message : nil
          m
        end
      end
    end
  end
end
