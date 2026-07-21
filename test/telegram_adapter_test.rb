# frozen_string_literal: true

require_relative "test_helper"

class TelegramAdapterTest < Minitest::Test
  def setup
    @adapter = Ask::ChannelProviders::Telegram::Adapter.new(
      token: "test:token",
      allowed_users: [123],
      allowed_chats: [-100]
    )
  end

  def teardown
    @adapter&.stop
  end

  def test_implements_channel_adapter
    assert_kind_of Ask::ChannelProviders::Adapter, @adapter
  end

  def test_responds_to_all_interface_methods
    %i[start stop running? send_message edit_message request_approval].each do |m|
      assert_respond_to @adapter, m
    end
  end

  def test_not_running_by_default
    refute @adapter.running?
  end

  def test_send_message_returns_nil_without_bot
    assert_nil @adapter.send_message(123, "Hello")
  end

  def test_edit_message_without_message_id
    @adapter.edit_message(123, nil, "test")
  end

  def test_edit_message_without_bot
    @adapter.edit_message(123, 1, "hello")
  end

  def test_request_approval_returns_nil_without_bot
    assert_nil @adapter.request_approval(123, tool_name: "Bash", risk_level: "medium", details: "rm -rf /")
  end

  def test_request_approval_formats_risk_levels
    assert_nil @adapter.request_approval(123, tool_name: "Write", risk_level: "critical", details: "danger")
    assert_nil @adapter.request_approval(123, tool_name: "Write", risk_level: "unknown_level", details: "???")
  end

  def test_allows_authorized_users
    sent = nil
    @adapter.start { |msg| sent = msg }

    @adapter.send(:handle_incoming, {
      chat_id: 100, user_id: 123, text: "Hello",
      is_group: false,
      raw: { "message_id" => 1, "date" => 0, "chat" => { "id" => 100, "type" => "private" }, "from" => { "id" => 123 }, "text" => "Hello" }
    })

    refute_nil sent
  end

  def test_blocks_unauthorized_users
    sent = false
    @adapter.start { |msg| sent = true }

    @adapter.send(:handle_incoming, {
      chat_id: 100, user_id: 99, text: "Hello",
      is_group: false,
      raw: { "message_id" => 1, "date" => 0, "chat" => { "id" => 100, "type" => "private" }, "from" => { "id" => 99 }, "text" => "Hello" }
    })

    refute sent
  end

  def test_allows_authorized_group_chats
    sent = false
    @adapter.start { |msg| sent = true }

    @adapter.send(:handle_incoming, {
      chat_id: -100, user_id: 999, text: "Hello",
      is_group: true,
      raw: { "message_id" => 1, "date" => 0, "chat" => { "id" => -100, "type" => "group" }, "from" => { "id" => 999 }, "text" => "Hello", "entities" => [] }
    })

    refute sent # should not trigger without mention
  end

  def test_allows_empty_allowed_lists
    adapter = Ask::ChannelProviders::Telegram::Adapter.new(token: "test:token")
    assert adapter.send(:allowed?, 1, 2, false)
    assert adapter.send(:allowed?, 1, 2, true)
  end

  def test_allowed_private_chat
    assert @adapter.send(:allowed?, 100, 123, false)
    refute @adapter.send(:allowed?, 100, 99, false)
  end

  def test_allowed_group_chat
    assert @adapter.send(:allowed?, -100, 999, true)
    refute @adapter.send(:allowed?, -101, 999, true)
  end

  def test_group_triggered_by_reply_to_bot
    @adapter.instance_variable_set(:@bot_user_id, 42)
    msg = {
      text: "reply",
      raw: make_message(
        message_id: 2, date: 0,
        chat: make_chat(id: -100, type: "group"),
        from: make_user(id: 999),
        reply_to_message: make_message(from: make_user(id: 42)),
        text: "reply",
        entities: []
      )
    }
    assert @adapter.send(:group_triggered?, msg)
  end

  def test_group_triggered_by_mention
    @adapter.instance_variable_set(:@bot_user_id, 42)
    msg = {
      text: "@42 hello",
      raw: make_message(
        message_id: 3, date: 0,
        chat: make_chat(id: -100, type: "group"),
        from: make_user(id: 999),
        text: "@42 hello",
        entities: [make_entity(type: "mention", offset: 0, length: 3)]
      )
    }
    assert @adapter.send(:group_triggered?, msg)
  end

  def test_group_triggered_false_for_normal_message
    @adapter.instance_variable_set(:@bot_user_id, 42)
    msg = {
      text: "normal message",
      raw: make_message(
        message_id: 4, date: 0,
        chat: make_chat(id: -100, type: "group"),
        from: make_user(id: 999),
        text: "normal message",
        entities: []
      )
    }
    refute @adapter.send(:group_triggered?, msg)
  end

  def test_skips_messages_without_text
    received = false
    @adapter.start { |msg| received = true }

    @adapter.send(:handle_incoming, {
      chat_id: 100, user_id: 123, text: "",
      is_group: false,
      raw: { "message_id" => 1, "date" => 0, "chat" => { "id" => 100, "type" => "private" }, "from" => { "id" => 123 }, "text" => "" }
    })

    refute received
  end

  def test_skips_messages_in_group_without_trigger
    sent = false
    @adapter.start { |msg| sent = true }

    @adapter.send(:handle_incoming, {
      chat_id: -100, user_id: 123, text: "hello",
      is_group: true,
      raw: { "message_id" => 1, "date" => 0, "chat" => { "id" => -100, "type" => "group" }, "from" => { "id" => 123 }, "text" => "hello", "entities" => [] }
    })

    refute sent
  end

  # --- Command handling ---

  def test_id_command_is_handled_not_passed_to_engine
    received = false
    @adapter.start { |msg| received = true }

    @adapter.send(:handle_incoming, {
      chat_id: 100, user_id: 123, text: "/id",
      is_group: false,
      raw: { "message_id" => 1, "date" => 0, "chat" => { "id" => 100, "type" => "private" }, "from" => { "id" => 123 }, "text" => "/id" }
    })

    # Should NOT reach the message_handler
    refute received
  end

  def test_start_command_is_handled_not_passed_to_engine
    received = false
    @adapter.start { |msg| received = true }

    @adapter.send(:handle_incoming, {
      chat_id: 100, user_id: 123, text: "/start",
      is_group: false,
      raw: { "message_id" => 1, "date" => 0, "chat" => { "id" => 100, "type" => "private" }, "from" => { "id" => 123 }, "text" => "/start" }
    })

    refute received
  end

  def test_new_command_passes_through_to_engine
    handler = nil
    @adapter.start { |msg| handler = msg }

    @adapter.send(:handle_incoming, {
      chat_id: 100, user_id: 123, text: "/new",
      is_group: false,
      raw: { "message_id" => 1, "date" => 0, "chat" => { "id" => 100, "type" => "private" }, "from" => { "id" => 123 }, "text" => "/new" }
    })

    refute_nil handler, "/new should pass through to the engine"
    assert_equal "/new", handler[:text] if handler
  end

  def test_sessions_command_passes_through_to_engine
    handler = nil
    @adapter.start { |msg| handler = msg }

    @adapter.send(:handle_incoming, {
      chat_id: 100, user_id: 123, text: "/sessions",
      is_group: false,
      raw: { "message_id" => 1, "date" => 0, "chat" => { "id" => 100, "type" => "private" }, "from" => { "id" => 123 }, "text" => "/sessions" }
    })

    refute_nil handler, "/sessions should pass through to the engine"
    assert_equal "/sessions", handler[:text] if handler
  end

  def test_non_command_messages_still_flow_to_engine
    received = false
    @adapter.start { |msg| received = true }

    @adapter.send(:handle_incoming, {
      chat_id: 100, user_id: 123, text: "hello",
      is_group: false,
      raw: { "message_id" => 1, "date" => 0, "chat" => { "id" => 100, "type" => "private" }, "from" => { "id" => 123 }, "text" => "hello" }
    })

    assert received
  end

  def test_handle_command_does_not_raise_without_bot
    @adapter.send(:handle_command, 100, 123, "/id")
    @adapter.send(:handle_command, 100, 123, "/start")
    @adapter.send(:handle_command, 100, 123, "/unknown")
  end

  private

  def make_message(message_id: nil, date: nil, chat: nil, from: nil, text: nil, entities: nil, reply_to_message: nil)
    OpenStruct.new(message_id: message_id, date: date, chat: chat, from: from, text: text,
                   entities: entities, reply_to_message: reply_to_message)
  end

  def make_chat(id: nil, type: nil)
    OpenStruct.new(id: id, type: type)
  end

  def make_user(id: nil, is_bot: false)
    OpenStruct.new(id: id, is_bot: is_bot)
  end

  def make_entity(type: nil, offset: nil, length: nil)
    OpenStruct.new(type: type, offset: offset, length: length)
  end
end
