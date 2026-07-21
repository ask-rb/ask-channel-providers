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

      # Whether the channel connection is active.
      #
      # @return [Boolean]
      def running?
        false
      end
    end
  end
end
