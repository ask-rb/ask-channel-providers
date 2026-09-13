# frozen_string_literal: true

module Ask
  module ChannelProviders
    # One inbound message, normalized across webhook channels. Adapters
    # parse their provider's payload into these; everything downstream
    # (routing, persistence, agents) works with this shape only.
    #
    # +channel_id+ identifies the receiving account on the provider (the
    # WhatsApp phone number id, the Telegram bot id, ...); +external_uid+
    # identifies the sender on the provider. +media_id+ and +media_type+
    # carry the provider's handle for an attachment (image, voice note,
    # document) so the consumer can download it.
    class InboundMessage
      ATTRIBUTES = %i[provider external_uid channel_id message_id kind text name timestamp media_id media_type].freeze

      attr_reader(*ATTRIBUTES)

      def initialize(provider:, external_uid:, channel_id:, message_id:, kind: "text", text: nil, name: nil, timestamp: nil, media_id: nil, media_type: nil)
        @provider = provider
        @external_uid = external_uid
        @channel_id = channel_id
        @message_id = message_id
        @kind = kind
        @text = text
        @name = name
        @timestamp = timestamp
        @media_id = media_id
        @media_type = media_type
      end

      def media?
        !media_id.to_s.strip.empty?
      end

      def text?
        kind.to_s == "text" && !text.to_s.strip.empty?
      end

      # JSON-safe for background-job serialization.
      def to_h
        ATTRIBUTES.to_h { |attribute| [attribute.to_s, public_send(attribute)] }
      end

      def self.from_h(hash)
        attributes = hash.to_h.transform_keys(&:to_sym)
        new(**ATTRIBUTES.to_h { |attribute| [attribute, attributes[attribute]] })
      end
    end
  end
end
