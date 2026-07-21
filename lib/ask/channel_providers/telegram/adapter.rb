# frozen_string_literal: true

module Ask
  module ChannelProviders
    module Telegram
      # ChannelAdapter implementation for Telegram.
      #
      # Wraps Ask::ChannelProviders::Telegram::Bot into the Adapter interface,
      # handling message dispatch, streaming edits, and approval requests.
      class Adapter < Ask::ChannelProviders::Adapter
        # @param token [String] Telegram bot token
        # @param allowed_users [Array<Integer>] allowed user IDs (empty = all)
        # @param allowed_chats [Array<Integer>] allowed group chat IDs (empty = all)
        def initialize(token:, allowed_users: [], allowed_chats: [])
          @token = token
          @allowed_users = allowed_users
          @allowed_chats = allowed_chats
          @bot = nil
          @bot_user_id = nil
          @message_handler = nil
          @callback_handler = nil
          @pending_permissions = {}  # callback_data -> Queue for approval responses
        end

        def start(config: {}, &on_message)
          @message_handler = on_message
          @bot = Bot.new(token: @token)
          @bot.start do |msg|
            handle_incoming(msg)
          end
          @bot.on_callback = method(:handle_callback)
          @bot_user_id = @bot.bot_user_id
        end

        def stop
          @bot&.stop
          @bot = nil
        end

        def running?
          @bot&.running? || false
        end

        # Send a text message, returns the message ID.
        def send_message(chat_id, text)
          response = try_send_markdown(chat_id, text)
          response ||= @bot&.send_message(chat_id: chat_id, text: text)
          response&.dig("result", "message_id")
        rescue => e
          nil
        end

        # Edit a previously sent message (streaming updates).
        def edit_message(chat_id, message_id, text)
          return unless @bot && message_id
          try_edit_markdown(chat_id, message_id, text) ||
            @bot.edit_message(chat_id: chat_id, message_id: message_id, text: text)
        rescue => e
          nil
        end

        # Handle inline keyboard button clicks.
        def handle_callback(callback)
          cq_id = callback[:callback_query_id]
          data = callback[:data]
          chat_id = callback[:chat_id]
          user_id = callback[:user_id]

          # Answer the callback (removes loading spinner on the button)
          @bot&.answer_callback_query(callback_query_id: cq_id)

          # Check if this is a permission approval callback
          if data && data.include?(":allow")
            callback_id = data.sub(":allow", "")
            if (queue = @pending_permissions.delete(callback_id))
              queue << "allow"
              return
            end
          elsif data && data.include?(":deny")
            callback_id = data.sub(":deny", "")
            if (queue = @pending_permissions.delete(callback_id))
              queue << "deny"
              return
            end
          end

          # Forward all other callbacks to the engine's callback handler
          @callback_handler&.call(
            chat_id: chat_id,
            user_id: user_id,
            data: data,
            callback_query_id: cq_id
          )
        rescue => e
          # Silently handle callback errors
        end

        private

        def try_send_markdown(chat_id, text)
          @bot&.send_message(chat_id: chat_id, text: text, parse_mode: "Markdown")
        rescue
          nil  # fall back to plain text
        end

        def try_edit_markdown(chat_id, message_id, text)
          @bot&.edit_message(chat_id: chat_id, message_id: message_id, text: "⏳ #{text}", parse_mode: "Markdown")
        rescue
          nil  # fall back to plain text
        end

        public

        # Set a handler for non-permission callbacks (session switching, etc.)
        def set_callback_handler(handler)
          @callback_handler = handler
        end

        # Send a rich card rendered as markdown + inline keyboards.
        def send_card(chat_id, card)
          lines = []
          buttons = []

          card.sections.each do |section|
            lines << "**#{section.title}**" unless section.title.empty?
            section.components.each do |comp|
              case comp
              when Card::TextBlock
                lines << comp.content
              when Card::Button
                if comp.callback
                  buttons << [{ text: comp.label, callback_data: comp.callback }]
                elsif comp.url
                  lines << "[#{comp.label}](#{comp.url})"
                end
              when Card::Table
                lines << "| #{comp.header.join(' | ')} |"
                lines << "| #{comp.header.map { |h| '—' * h.length }.join(' | ')} |"
                comp.rows.each { |row| lines << "| #{row.join(' | ')} |" }
              when Card::Divider
                lines << "───"
              end
            end
            lines << ""
          end

          text = lines.join("\n").strip
          return if text.empty?

          if buttons.any?
            @bot&.send_keyboard_message(chat_id: chat_id, text: text, buttons: buttons)
          else
            @bot&.send_message(chat_id: chat_id, text: text, parse_mode: "Markdown")
          end
        rescue => e
          nil
        end

        # Send an approval request with inline buttons.
        # Returns the approval Queue for the engine to wait on.
        def request_approval(chat_id, tool_name:, risk_level:, details:)
          risk_label = {
            "low" => "Low Risk", "medium" => "Medium Risk",
            "high" => "High Risk", "critical" => "Critical Risk"
          }.fetch(risk_level, risk_level)

          callback_id = "perm:#{chat_id}:#{Time.now.to_i}"
          text = ["🔐 Approval Required",
                  "Tool: #{tool_name} (#{risk_label})",
                  details].join("\n")

          buttons = [
            [{ text: "✅ Approve", callback_data: "#{callback_id}:allow" },
             { text: "❌ Deny", callback_data: "#{callback_id}:deny" }]
          ]

          queue = Queue.new
          @pending_permissions[callback_id] = queue

          @bot&.send_keyboard_message(
            chat_id: chat_id, text: text, buttons: buttons
          )

          queue  # Engine waits on this queue for the decision
        rescue => e
          nil
        end

        private

        def handle_incoming(msg)
          return unless @message_handler
          return if msg[:is_group] && !group_triggered?(msg)

          chat_id = msg[:chat_id]
          user_id = msg[:user_id]
          text = msg[:text]
          return unless allowed?(chat_id, user_id, msg[:is_group])
          return if text.nil? || text.strip.empty?

          # Handle built-in commands
          case text.strip
          when "/id", "/start", "/new", "/sessions", "/status", "/projects", "/mode", "/help", "/models"
            handle_command(chat_id, user_id, text.strip)
            return
          end

          # Handle /model (with optional argument) — pass through to engine
          if text.strip == "/model" || text.strip.start_with?("/model ")
            handle_command(chat_id, user_id, text.strip)
            return
          end

          @message_handler.call(
            chat_id: chat_id,
            user_id: user_id,
            session_key: msg[:is_group] ? chat_id : user_id,
            text: text.strip,
            raw: msg
          )
        end

        def handle_command(chat_id, user_id, command)
          case command
          when "/id"
            @bot&.send_message(chat_id: chat_id, text: "Your Telegram user ID: `#{user_id}`")
          when "/start"
            @bot&.send_message(chat_id: chat_id, text: "🤖 Askoda bot active!\n\nCommands:\n/id  — get your Telegram user ID\n/new — start a new conversation\n\nJust type anything to chat with the coding agent.")
          when "/new", "/sessions", "/status", "/projects", "/mode", "/help", "/models"
            @message_handler&.call(
              chat_id: chat_id,
              user_id: user_id,
              session_key: chat_id < 0 ? chat_id : user_id,
              text: command,
              raw: nil
            )
          when "/model"
            @message_handler&.call(
              chat_id: chat_id,
              user_id: user_id,
              session_key: chat_id < 0 ? chat_id : user_id,
              text: command,
              raw: nil
            )
          else
            # Handle /model <id> — pass through with the full command text
            if command.start_with?("/model ")
              @message_handler&.call(
                chat_id: chat_id,
                user_id: user_id,
                session_key: chat_id < 0 ? chat_id : user_id,
                text: command,
                raw: nil
              )
            end
          end
        rescue => e
          # Silently handle send errors during command responses
        end

        def allowed?(chat_id, user_id, is_group)
          if is_group
            @allowed_chats.empty? || @allowed_chats.include?(chat_id)
          else
            @allowed_users.empty? || @allowed_users.include?(user_id)
          end
        end

        def group_triggered?(msg)
          text = msg[:text] || ""
          return false unless @bot_user_id

          raw = msg[:raw]
          return false unless raw.respond_to?(:reply_to_message) || raw.respond_to?(:entities)

          replied = raw.respond_to?(:reply_to_message) ? raw.reply_to_message : nil
          return true if replied && replied.respond_to?(:from) && replied.from.respond_to?(:id) &&
                         replied.from.id == @bot_user_id

          entities = raw.respond_to?(:entities) ? raw.entities : nil
          return false unless entities.respond_to?(:any?)

          entities.any? do |ent|
            next false unless ent.respond_to?(:type) && ent.type == "mention"
            next false unless ent.respond_to?(:offset) && ent.respond_to?(:length)
            mention = text[ent.offset, ent.length]
            mention && mention.downcase == "@#{@bot_user_id}".downcase
          end
        end
      end
    end
  end
end
