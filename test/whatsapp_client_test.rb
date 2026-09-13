# frozen_string_literal: true

require_relative "test_helper"

class WhatsAppClientTest < Minitest::Test
  class FakeTransport
    attr_reader :requests

    def initialize(status: 200, body: nil)
      @status = status
      @body = body
      @requests = []
    end

    def post(url:, headers:, body:)
      @requests << {url: url, headers: headers, body: JSON.parse(body)}
      payload = @body || {"messaging_product" => "whatsapp", "messages" => [{"id" => "wamid.1"}]}
      Ask::ChannelProviders::WhatsApp::Transport::Response.new(status: @status, body: JSON.generate(payload))
    end

    def get(url:, headers: {})
      @requests << {method: :get, url: url, headers: headers}
      body = url.start_with?("https://cdn.example") ? "JPEGBYTES" : JSON.generate({"url" => "https://cdn.example/file", "mime_type" => "image/jpeg"})
      Ask::ChannelProviders::WhatsApp::Transport::Response.new(status: 200, body: body)
    end
  end

  def setup
    @transport = FakeTransport.new
    @client = Ask::ChannelProviders::WhatsApp::Client.new(
      phone_number_id: "12345",
      access_token: "token",
      transport: @transport
    )
  end

  def test_send_text_posts_to_the_graph_api
    id = @client.send_text(to: "254712345678", text: "Karibu!")

    assert_equal "wamid.1", id
    request = @transport.requests.last
    assert_equal "https://graph.facebook.com/v23.0/12345/messages", request[:url]
    assert_equal "Bearer token", request[:headers]["Authorization"]
    assert_equal "whatsapp", request[:body]["messaging_product"]
    assert_equal "254712345678", request[:body]["to"]
    assert_equal "Karibu!", request[:body]["text"]["body"]
  end

  def test_send_text_splits_long_replies_into_whatsapp_sized_messages
    @client.send_text(to: "254712345678", text: ("word " * 1200).strip)

    assert_equal 2, @transport.requests.size
    assert(@transport.requests.all? { |request| request[:body]["text"]["body"].length <= 4096 })
  end

  def test_mark_read_posts_the_read_status
    @client.mark_read(message_id: "wamid.1")

    body = @transport.requests.last[:body]
    assert_equal "read", body["status"]
    assert_equal "wamid.1", body["message_id"]
  end

  def test_chunks_split_on_paragraph_boundaries
    chunks = @client.chunks(("a" * 3000) + "\n\n" + ("b" * 3000))

    assert_equal 2, chunks.size
    assert_equal "a" * 3000, chunks.first
    assert_equal "b" * 3000, chunks.last
  end

  def test_chunks_keep_short_text_whole
    assert_equal ["One line"], @client.chunks("One line")
  end

  def test_fetch_media_downloads_the_bytes
    media = @client.fetch_media("media.1")

    assert_equal "JPEGBYTES", media[:body]
    assert_equal "image/jpeg", media[:mime_type]
    assert_equal 2, @transport.requests.count { |request| request[:method] == :get }
  end

  def test_graph_errors_raise_api_error
    transport = FakeTransport.new(status: 400, body: {"error" => {"message" => "bad request"}})
    client = Ask::ChannelProviders::WhatsApp::Client.new(
      phone_number_id: "1", access_token: "t", transport: transport
    )

    error = assert_raises(Ask::ChannelProviders::APIError) { client.mark_read(message_id: "wamid.1") }
    assert_includes error.message, "400"
  end
end
