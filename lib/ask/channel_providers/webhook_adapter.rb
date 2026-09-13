# frozen_string_literal: true

module Ask
  module ChannelProviders
    # Base class for webhook-driven channels: the provider pushes messages
    # to your HTTP endpoint, so there is no local polling loop to start.
    #
    # The inbound edge is class-level — signature verification and parsing
    # run before any channel configuration is known, and the receiving
    # account is resolved from the parsed payload. The outbound edge is
    # instance-level, bound to one configured account.
    #
    # Subclasses implement .provider, .verify_signature, .parse, and
    # #deliver; .challenge and #mark_read have safe defaults.
    class WebhookAdapter < Adapter
      # The provider slug ("whatsapp", "telegram", ...).
      def self.provider
        raise NotImplementedError, "#{name} must implement .provider"
      end

      # Verifies the provider's signature over the raw request body.
      #
      # @param raw_body [String] the unmodified request body
      # @param signature [String] the provider's signature header value
      # @param secret [String] the app secret shared with the provider
      # @return [Boolean]
      def self.verify_signature(raw_body:, signature:, secret:)
        raise NotImplementedError, "#{name} must implement .verify_signature"
      end

      # Answers the provider's GET webhook-registration challenge.
      #
      # @param params [Hash] the request query parameters
      # @param verify_token [String] the token configured with the provider
      # @return [String, nil] the challenge to echo, or nil when invalid
      def self.challenge(params, verify_token:)
        nil
      end

      # Parses a webhook payload into messages.
      #
      # @param payload [Hash] the parsed JSON body
      # @return [Array<InboundMessage>]
      def self.parse(payload)
        raise NotImplementedError, "#{name} must implement .parse"
      end

      # Webhook channels receive through their HTTP endpoint; there is no
      # local loop. No-op keeps the uniform Adapter interface honest.
      def start(config: {}, &on_message)
        nil
      end

      def stop
        nil
      end

      # Delivers a text reply to +to+ (the provider's user/chat id).
      #
      # @return [String, nil] the provider's message id
      def deliver(to:, text:)
        raise NotImplementedError, "#{self.class} must implement #deliver"
      end

      # Marks an inbound message as read where the provider supports it.
      def mark_read(message_id:)
        nil
      end

      # The uniform Adapter interface delegates to #deliver.
      def send_message(chat_id, text)
        deliver(to: chat_id, text: text)
      end

      # Most business messaging APIs cannot edit a sent message (WhatsApp
      # cannot at all), so this stays unsupported rather than lying.
      def edit_message(chat_id, message_id, text)
        raise NotImplementedError, "#{self.class} does not support editing messages"
      end
    end
  end
end
