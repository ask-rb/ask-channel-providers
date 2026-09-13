# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Ask
  module ChannelProviders
    module WhatsApp
      # The HTTP transport for Graph API calls. One small seam so tests (and
      # alternate HTTP stacks) can swap the implementation.
      class Transport
        OPEN_TIMEOUT = 10
        READ_TIMEOUT = 15

        Response = Struct.new(:status, :body, keyword_init: true) do
          def success?
            (200..299).cover?(status)
          end
        end

        def post(url:, headers:, body:)
          uri = URI(url)
          request = Net::HTTP::Post.new(uri)
          headers.each { |key, value| request[key] = value }
          request.body = body
          perform(uri, request)
        end

        def get(url:, headers: {})
          uri = URI(url)
          request = Net::HTTP::Get.new(uri)
          headers.each { |key, value| request[key] = value }
          perform(uri, request)
        end

        private

        def perform(uri, request)
          response = Net::HTTP.start(
            uri.host, uri.port,
            use_ssl: uri.scheme == "https",
            open_timeout: OPEN_TIMEOUT,
            read_timeout: READ_TIMEOUT
          ) { |http| http.request(request) }
          Response.new(status: response.code.to_i, body: response.body.to_s)
        end
      end
    end
  end
end
