# frozen_string_literal: true

require_relative "test_helper"

class WhatsAppAdapterTest < Minitest::Test
  ADAPTER = Ask::ChannelProviders::WhatsApp::Adapter
  SECRET = "app-secret"
  VERIFY_TOKEN = "verify-me"

  PAYLOAD = {
    "object" => "whatsapp_business_account",
    "entry" => [
      {
        "id" => "WABA1",
        "changes" => [
          {
            "value" => {
              "messaging_product" => "whatsapp",
              "metadata" => {"display_phone_number" => "254702112002", "phone_number_id" => "12345"},
              "contacts" => [{"profile" => {"name" => "Jane"}, "wa_id" => "254712345678"}],
              "messages" => [
                {
                  "from" => "254712345678",
                  "id" => "wamid.1",
                  "timestamp" => "1700000000",
                  "type" => "text",
                  "text" => {"body" => "Hi, is the Prado free?"}
                }
              ]
            }
          }
        ]
      }
    ]
  }.freeze

  class FakeClient
    attr_reader :sent, :read

    def initialize
      @sent = []
      @read = []
    end

    def send_text(to:, text:)
      @sent << {to: to, text: text}
      "wamid.sent"
    end

    def mark_read(message_id:)
      @read << message_id
    end
  end

  def setup
    @client = FakeClient.new
    @adapter = ADAPTER.new(phone_number_id: "12345", access_token: "token", client: @client)
  end

  def signature_for(body, secret = SECRET)
    "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, body)}"
  end

  def test_is_a_webhook_adapter
    assert_kind_of Ask::ChannelProviders::WebhookAdapter, @adapter
    assert_equal "whatsapp", ADAPTER.provider
  end

  def test_parse_reads_text_messages
    messages = ADAPTER.parse(PAYLOAD)

    assert_equal 1, messages.size
    message = messages.first
    assert_equal "whatsapp", message.provider
    assert_equal "254712345678", message.external_uid
    assert_equal "12345", message.channel_id
    assert_equal "wamid.1", message.message_id
    assert_equal "text", message.kind
    assert_equal "Hi, is the Prado free?", message.text
    assert_equal "Jane", message.name
    assert message.text?
  end

  def test_parse_ignores_status_only_payloads
    payload = {"entry" => [{"changes" => [{"value" => {"messaging_product" => "whatsapp", "statuses" => [{"id" => "x"}]}}]}]}
    assert_empty ADAPTER.parse(payload)
  end

  def test_parse_ignores_other_products
    payload = {"entry" => [{"changes" => [{"value" => {"messaging_product" => "instagram"}}]}]}
    assert_empty ADAPTER.parse(payload)
  end

  def test_parse_marks_unsupported_kinds
    payload = Marshal.load(Marshal.dump(PAYLOAD))
    message = payload.dig("entry", 0, "changes", 0, "value", "messages", 0)
    message["type"] = "image"
    message.delete("text")
    message["image"] = {"id" => "media.1", "mime_type" => "image/jpeg", "caption" => "Which car is this?"}

    parsed = ADAPTER.parse(payload).first
    assert_equal "image", parsed.kind
    refute parsed.text?
    assert parsed.media?
    assert_equal "media.1", parsed.media_id
    assert_equal "image/jpeg", parsed.media_type
  end

  def test_parse_reads_voice_notes_as_media
    payload = Marshal.load(Marshal.dump(PAYLOAD))
    message = payload.dig("entry", 0, "changes", 0, "value", "messages", 0)
    message["type"] = "audio"
    message.delete("text")
    message["audio"] = {"id" => "media.2", "mime_type" => "audio/ogg; codecs=opus", "voice" => true}

    parsed = ADAPTER.parse(payload).first
    assert_equal "audio", parsed.kind
    assert parsed.media?
    assert_equal "media.2", parsed.media_id
  end

  def test_verify_signature_accepts_a_valid_signature
    body = '{"a":1}'
    assert ADAPTER.verify_signature(raw_body: body, signature: signature_for(body), secret: SECRET)
  end

  def test_verify_signature_rejects_a_tampered_body
    body = '{"a":1}'
    refute ADAPTER.verify_signature(raw_body: '{"a":2}', signature: signature_for(body), secret: SECRET)
  end

  def test_verify_signature_rejects_missing_secret_or_signature
    refute ADAPTER.verify_signature(raw_body: "{}", signature: "sha256=x", secret: nil)
    refute ADAPTER.verify_signature(raw_body: "{}", signature: nil, secret: SECRET)
  end

  def test_challenge_echoes_for_a_valid_token
    challenge = ADAPTER.challenge(
      {"hub.mode" => "subscribe", "hub.verify_token" => VERIFY_TOKEN, "hub.challenge" => "abc123"},
      verify_token: VERIFY_TOKEN
    )
    assert_equal "abc123", challenge
  end

  def test_challenge_rejects_a_wrong_token
    challenge = ADAPTER.challenge(
      {"hub.mode" => "subscribe", "hub.verify_token" => "nope", "hub.challenge" => "abc123"},
      verify_token: VERIFY_TOKEN
    )
    assert_nil challenge
  end

  def test_challenge_ignores_non_subscribe_requests
    assert_nil ADAPTER.challenge({"hub.mode" => "unsubscribe"}, verify_token: VERIFY_TOKEN)
  end

  def test_deliver_delegates_to_the_client
    assert_equal "wamid.sent", @adapter.deliver(to: "254712345678", text: "Karibu!")
    assert_equal [{to: "254712345678", text: "Karibu!"}], @client.sent
  end

  def test_mark_read_delegates_to_the_client
    @adapter.mark_read(message_id: "wamid.1")
    assert_equal ["wamid.1"], @client.read
  end

  def test_send_message_delegates_to_deliver
    @adapter.send_message("254712345678", "Hello")
    assert_equal [{to: "254712345678", text: "Hello"}], @client.sent
  end

  def test_editing_messages_is_unsupported
    assert_raises(NotImplementedError) { @adapter.edit_message("1", "wamid.1", "new text") }
  end

  def test_start_and_stop_are_noops_for_webhook_channels
    assert_nil @adapter.start
    assert_nil @adapter.stop
    refute @adapter.running?
  end
end
