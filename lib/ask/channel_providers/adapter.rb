# frozen_string_literal: true

module Ask
  module ChannelProviders
    # Abstract base class for channel adapters.
    #
    # A channel adapter wraps a messaging platform (e.g., Telegram, Discord, Slack)
    # and provides a uniform interface for the coder engine to communicate through it.
    #
    # Subclasses must implement all methods that raise NotImplementedError.
    class Adapter
      # Start the channel and begin receiving messages.
      #
      # The channel should call the provided block whenever a user message arrives.
      # The block receives { chat_id:, user_id:, text:, session_key: }.
      #
      # @param config [Hash] channel-specific configuration
      # @param on_message [Proc] callback for incoming messages
      def start(config: {}, &on_message)
        raise NotImplementedError, "#{self.class} must implement #start"
      end

      # Stop the channel gracefully.
      def stop
        raise NotImplementedError, "#{self.class} must implement #stop"
      end

      # Send a text message to a chat.
      #
      # @param chat_id [Integer, String] the chat/thread identifier
      # @param text [String] the message text
      # @return [void]
      def send_message(chat_id, text)
        raise NotImplementedError, "#{self.class} must implement #send_message"
      end

      # Edit a previously sent message (for streaming updates).
      #
      # @param chat_id [Integer, String] the chat/thread identifier
      # @param message_id [Integer] the message ID to edit
      # @param text [String] the new text
      # @return [void]
      def edit_message(chat_id, message_id, text)
        raise NotImplementedError, "#{self.class} must implement #edit_message"
      end

      # Send an approval request with accept/decline buttons.
      #
      # @param chat_id [Integer, String] the chat/thread identifier
      # @param tool_name [String] the name of the tool requesting permission
      # @param risk_level [String] the risk level string
      # @param details [String] human-readable details about the request
      # @return [void]
      def request_approval(chat_id, tool_name:, risk_level:, details:)
        raise NotImplementedError, "#{self.class} must implement #request_approval"
      end

      # Send a rich card (cross-platform UI).
      #
      # Each adapter renders the Card to its native format.
      # Default implementation falls back to markdown text.
      #
      # @param chat_id [Integer, String] the chat identifier
      # @param card [Card] the card to render
      def send_card(chat_id, card)
        text = render_card_to_text(card)
        send_message(chat_id, text) if text
      end

      # Render a card to plain text fallback.
      # Override in platform adapters for rich rendering.
      def render_card_to_text(card)
        lines = []
        card.sections.each do |section|
          lines << "**#{section.title}**" unless section.title.empty?
          section.components.each do |comp|
            case comp
            when Card::TextBlock
              lines << comp.content
            when Card::Table
              lines << "| #{comp.header.join(' | ')} |"
              lines << "| #{comp.header.map { '-' * _1.length }.join(' | ')} |"
              comp.rows.each { |row| lines << "| #{row.join(' | ')} |" }
            when Card::Divider
              lines << "---"
            end
          end
          lines << ""
        end
        lines.join("\n").strip
      end

      # Register a callback handler for interactive button presses.
      # Called with { chat_id:, user_id:, data:, callback_query_id: }
      def set_callback_handler(handler)
        @callback_handler = handler
      end

      # Whether the channel connection is active.
      #
      # @return [Boolean]
      def running?
        false
      end
    end
  end
end
