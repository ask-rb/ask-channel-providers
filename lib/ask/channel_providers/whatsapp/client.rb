# frozen_string_literal: true

module Ask
  module ChannelProviders
    module WhatsApp
      # Sends text messages and read receipts through the Meta Graph API for
      # one WhatsApp phone number. Long replies become several WhatsApp
      # messages, split on paragraph/line boundaries so nothing is cut
      # mid-word.
      class Client
        DEFAULT_GRAPH_VERSION = "v23.0"
        BASE_URL = "https://graph.facebook.com"
        MAX_TEXT_LENGTH = 4096

        class << self
          # The shared transport; swap in tests or for another HTTP stack.
          attr_writer :transport

          def transport
            @transport ||= Transport.new
          end
        end

        def initialize(phone_number_id:, access_token:, graph_version: nil, transport: nil)
          @phone_number_id = phone_number_id
          @access_token = access_token
          @graph_version = graph_version.to_s.empty? ? DEFAULT_GRAPH_VERSION : graph_version
          @transport = transport || self.class.transport
        end

        # Sends +text+ (splitting if needed).
        #
        # @return [String, nil] the last message id the provider returned
        def send_text(to:, text:)
          chunks(text).map do |chunk|
            response = post("messages", {
              messaging_product: "whatsapp",
              to: to,
              type: "text",
              text: {body: chunk, preview_url: false}
            })
            response.dig("messages", 0, "id")
          end.compact.last
        end

        def mark_read(message_id:)
          post("messages", {
            messaging_product: "whatsapp",
            status: "read",
            message_id: message_id
          })
        end

        # Splits a reply into WhatsApp-sized messages at the last paragraph,
        # line, or word boundary before the limit.
        def chunks(text)
          remaining = text.to_s.strip
          parts = []
          while remaining.length > MAX_TEXT_LENGTH
            boundary = remaining.rindex(/\n\n/, MAX_TEXT_LENGTH) ||
              remaining.rindex("\n", MAX_TEXT_LENGTH) ||
              remaining.rindex(" ", MAX_TEXT_LENGTH) ||
              MAX_TEXT_LENGTH
            parts << remaining[0...boundary].strip
            remaining = remaining[boundary..].to_s.strip
          end
          parts << remaining unless remaining.empty?
          parts
        end

        private

        def post(path, body)
          response = @transport.post(
            url: "#{BASE_URL}/#{@graph_version}/#{@phone_number_id}/#{path}",
            headers: {
              "Authorization" => "Bearer #{@access_token}",
              "Content-Type" => "application/json"
            },
            body: JSON.generate(body)
          )
          unless response.success?
            raise APIError, "graph api returned #{response.status}: #{response.body}"
          end

          JSON.parse(response.body)
        rescue JSON::ParserError, SocketError, Timeout::Error, SystemCallError => e
          raise APIError, e.message
        end
      end
    end
  end
end
