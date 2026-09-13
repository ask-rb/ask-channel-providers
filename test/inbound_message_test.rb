# frozen_string_literal: true

require_relative "test_helper"

class InboundMessageTest < Minitest::Test
  def build_message(**overrides)
    Ask::ChannelProviders::InboundMessage.new(**{
      provider: "whatsapp",
      external_uid: "254712345678",
      channel_id: "12345",
      message_id: "wamid.1",
      text: "Hi"
    }.merge(overrides))
  end

  def test_text_message_is_text
    assert build_message.text?
  end

  def test_blank_text_is_not_text
    refute build_message(text: "  ").text?
  end

  def test_non_text_kind_is_not_text
    message = build_message(kind: "image", text: nil)
    refute message.text?
    assert_equal "image", message.kind
  end

  def test_to_h_is_json_safe_and_round_trips
    message = build_message(name: "Jane")
    hash = message.to_h

    assert_equal "whatsapp", hash["provider"]
    assert_equal "Jane", hash["name"]
    assert hash.keys.all? { |key| key.is_a?(String) }

    round_tripped = Ask::ChannelProviders::InboundMessage.from_h(hash)
    assert_equal message.external_uid, round_tripped.external_uid
    assert_equal message.channel_id, round_tripped.channel_id
    assert_equal message.message_id, round_tripped.message_id
    assert_equal message.kind, round_tripped.kind
    assert_equal message.text, round_tripped.text
    assert_equal message.name, round_tripped.name
  end

  def test_from_h_ignores_unknown_keys
    message = Ask::ChannelProviders::InboundMessage.from_h({"provider" => "whatsapp", "junk" => 1})
    assert_equal "whatsapp", message.provider
  end
end
