# frozen_string_literal: true

require "openssl"

module Ask
  module ChannelProviders
    module WhatsApp
      # The WhatsApp Cloud API adapter: verifies Meta's X-Hub-Signature-256
      # over the raw webhook body, parses payloads into InboundMessages, and
      # delivers replies for one configured phone number.
      #
      # Secrets are passed in (never read from globals) so the same adapter
      # serves many accounts in one process.
      class Adapter < WebhookAdapter
        SIGNATURE_PREFIX = "sha256="

        class << self
          def provider
            "whatsapp"
          end

          # Meta signs every webhook POST with HMAC-SHA256 of the raw body,
          # keyed by the Meta app secret: "sha256=<hex>".
          def verify_signature(raw_body:, signature:, secret:)
            return false if secret.to_s.empty? || signature.to_s.empty?

            expected = "#{SIGNATURE_PREFIX}#{OpenSSL::HMAC.hexdigest("SHA256", secret, raw_body)}"
            secure_compare(expected, signature.to_s)
          end

          # The GET challenge Meta sends when the webhook URL is registered.
          def challenge(params, verify_token:)
            return unless params["hub.mode"] == "subscribe"
            return if verify_token.to_s.empty?
            return unless secure_compare(params["hub.verify_token"].to_s, verify_token.to_s)

            params["hub.challenge"]
          end

          def parse(payload)
            Array(payload["entry"]).flat_map { |entry| Array(entry["changes"]) }.flat_map do |change|
              value = change["value"] || {}
              next [] unless value["messaging_product"] == "whatsapp"

              metadata = value["metadata"] || {}
              names = Array(value["contacts"]).to_h { |contact| [contact["wa_id"].to_s, contact] }
              Array(value["messages"]).map { |raw| build_message(raw, metadata, names) }
            end
          end

          def build_message(raw, metadata, names)
            type = raw["type"].to_s
            media = raw[type].is_a?(Hash) ? raw[type] : {}
            InboundMessage.new(
              provider: provider,
              external_uid: raw["from"].to_s,
              channel_id: metadata["phone_number_id"].to_s,
              message_id: raw["id"].to_s,
              kind: type,
              text: (raw.dig("text", "body").to_s if type == "text"),
              name: names.dig(raw["from"].to_s, "profile", "name"),
              timestamp: raw["timestamp"].to_s,
              media_id: media["id"],
              media_type: media["mime_type"]
            )
          end

          private

          # Constant-time comparison without ActiveSupport.
          def secure_compare(first, second)
            return false unless first.bytesize == second.bytesize

            left = first.unpack("C*")
            right = second.unpack("C*")
            right.each_with_index { |byte, index| left[index] ^= byte }
            left.all?(&:zero?)
          end
        end

        def initialize(phone_number_id:, access_token:, graph_version: nil, client: nil)
          @client = client || Client.new(
            phone_number_id: phone_number_id,
            access_token: access_token,
            graph_version: graph_version
          )
        end

        def deliver(to:, text:)
          @client.send_text(to: to, text: text)
        end

        def mark_read(message_id:)
          @client.mark_read(message_id: message_id)
        end
      end
    end
  end
end
