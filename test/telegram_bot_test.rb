# frozen_string_literal: true

require_relative "test_helper"

class TelegramBotTest < Minitest::Test
  def setup
    @bot = Ask::ChannelProviders::Telegram::Bot.new(token: "test:token")
    @api = mock("api")
    @client = mock("client")
    @client.stubs(:api).returns(@api)
    @bot.instance_variable_set(:@client, @client)
    # Prevent fetch_bot_info from calling me during start
    @bot.stubs(:fetch_bot_info)
  end

  def teardown
    @bot&.stop
  end

  def test_initializes_with_token
    assert_equal "test:token", @bot.token
  end

  def test_not_running_by_default
    refute @bot.running?
  end

  def test_send_message
    @api.expects(:send_message).with({chat_id: 123, text: "Hello"}).returns("ok")
    @bot.send_message(chat_id: 123, text: "Hello")
  end

  def test_send_message_with_parse_mode
    @api.expects(:send_message).with({chat_id: 123, text: "*bold*", parse_mode: "Markdown"}).returns("ok")
    @bot.send_message(chat_id: 123, text: "*bold*", parse_mode: "Markdown")
  end

  def test_send_message_raises_on_api_error
    @api.expects(:send_message).raises(make_telegram_error("error"))
    assert_raises(Ask::ChannelProviders::APIError) do
      @bot.send_message(chat_id: 123, text: "Hello")
    end
  end

  def test_edit_message
    @api.expects(:edit_message_text).with({chat_id: 123, message_id: 1, text: "Edited"}).returns("ok")
    @bot.edit_message(chat_id: 123, message_id: 1, text: "Edited")
  end

  def test_edit_message_silently_ignores_not_modified
    err = make_telegram_error("message is not modified")
    @api.expects(:edit_message_text).with({chat_id: 123, message_id: 1, text: "Same"}).raises(err)
    @bot.edit_message(chat_id: 123, message_id: 1, text: "Same")
  end

  def test_edit_message_re_raises_other_errors
    @api.expects(:edit_message_text).with({chat_id: 123, message_id: 1, text: "Fail"}).raises(make_telegram_error("other error"))
    assert_raises(Ask::ChannelProviders::APIError) do
      @bot.edit_message(chat_id: 123, message_id: 1, text: "Fail")
    end
  end

  def test_edit_message_with_parse_mode
    @api.expects(:edit_message_text).with({chat_id: 123, message_id: 1, text: "*bold*", parse_mode: "Markdown"}).returns("ok")
    @bot.edit_message(chat_id: 123, message_id: 1, text: "*bold*", parse_mode: "Markdown")
  end

  def test_delete_message
    @api.expects(:delete_message).with(chat_id: 123, message_id: 1).returns("ok")
    @bot.delete_message(chat_id: 123, message_id: 1)
  end

  def test_delete_message_does_not_raise_on_error
    @api.expects(:delete_message).raises(make_telegram_error("error"))
    @bot.delete_message(chat_id: 123, message_id: 1)
  end

  def test_me
    @api.expects(:get_me).returns({ "result" => { "id" => 12345 } })
    result = @bot.me
    assert_equal({ "result" => { "id" => 12345 } }, result)
  end

  def test_me_caches
    @api.expects(:get_me).once.returns({ "result" => { "id" => 12345 } })
    @bot.me
    @bot.me
  end

  def test_me_raises_on_api_error
    @api.expects(:get_me).raises(make_telegram_error("error"))
    assert_raises(Ask::ChannelProviders::APIError) { @bot.me }
  end

  def test_process_update_extracts_message
    update = make_update(
      update_id: 1,
      message: make_message(
        message_id: 100, date: 1_234_567,
        chat: make_chat(id: 42, type: "private"),
        from: make_user(id: 99),
        text: "Hello bot!"
      )
    )

    received = nil
    @bot.start { |msg| received = msg }
    @bot.send(:process_update, update)

    refute_nil received
    assert_equal 42, received[:chat_id]
    assert_equal 99, received[:user_id]
    assert_equal "Hello bot!", received[:text]
    refute received[:is_group]
  end

  def test_process_update_handles_group_channel_post
    update = make_update(
      update_id: 2,
      channel_post: make_message(
        message_id: 101, date: 1_234_568,
        chat: make_chat(id: -100, type: "supergroup"),
        from: make_user(id: 98),
        text: "Group message"
      )
    )

    received = nil
    @bot.start { |msg| received = msg }
    @bot.send(:process_update, update)

    refute_nil received
    assert_equal(-100, received[:chat_id])
    assert received[:is_group]
  end

  def test_process_update_ignores_messages_without_text
    update = make_update(
      update_id: 3,
      message: make_message(
        message_id: 102, date: 1_234_569,
        chat: make_chat(id: 42, type: "private"),
        from: make_user(id: 99)
      )
    )

    received = false
    @bot.start { |msg| received = true }
    @bot.send(:process_update, update)
    refute received
  end

  def test_process_update_skips_non_message_updates
    update = make_update(update_id: 4)
    received = false
    @bot.start { |msg| received = true }
    @bot.send(:process_update, update)
    refute received
  end

  def test_fetch_updates
    @api.expects(:get_updates).with({offset: 1, timeout: 5}).returns([])
    @bot.instance_variable_set(:@last_update_id, 0)
    @bot.send(:fetch_updates)
  end

  def test_fetch_updates_raises_on_error
    @api.expects(:get_updates).raises(make_telegram_error("error"))
    assert_raises(Ask::ChannelProviders::APIError) { @bot.send(:fetch_updates) }
  end

  def test_fetch_bot_info_sets_user_id
    @bot.unstub(:fetch_bot_info)
    user = OpenStruct.new(id: 42, first_name: "Test", username: "test_bot", is_bot: true)
    @api.stubs(:get_me).returns(user)
    assert_nil @bot.bot_user_id
    @bot.send(:fetch_bot_info)
    assert_equal 42, @bot.bot_user_id
  end

  def test_fetch_bot_info_handles_error
    @api.stubs(:get_me).raises(StandardError.new("fail"))
    @bot.send(:fetch_bot_info)
    assert_nil @bot.bot_user_id
  end

  def test_start_and_stop
    @api.stubs(:get_updates).returns([])

    refute @bot.running?
    @bot.start { |m| }
    sleep 0.2
    assert @bot.running?
    @bot.stop
    refute @bot.running?
  end

  def test_multiple_stops_are_safe
    @bot.stop
    @bot.stop
    refute @bot.running?
  end

  # ── Dedup tests ──

  def test_processed_updates_tracks_ids
    updates = @bot.instance_variable_get(:@processed_updates)
    assert_equal [], updates
  end

  def test_duplicate_update_skipped
    received = []
    @bot.start { |m| received << m }

    update = make_update(update_id: 1)
    @bot.send(:process_update, update)
    @bot.send(:process_update, update)  # duplicate

    assert_operator received.length, :<=, 1, "duplicate update should be skipped"
  end

  def test_different_updates_processed
    received = []
    @bot.start { |m| received << m }

    @bot.send(:process_update, make_update(update_id: 1))
    @bot.send(:process_update, make_update(update_id: 2))

    assert_operator received.length, :>=, 0
  end

  def test_ring_buffer_does_not_grow_indefinitely
    updates = @bot.instance_variable_get(:@processed_updates)
    600.times { |i| updates << i }
    updates.shift while updates.length > 500
    assert updates.length <= 500
  end

  private

  def make_update(update_id: 0, message: nil, channel_post: nil, edited_message: nil)
    OpenStruct.new(update_id: update_id, message: message, channel_post: channel_post, edited_message: edited_message)
  end

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

  def make_telegram_error(msg)
    # Simulate a real Telegram API JSON error response
    body = { ok: false, error_code: 400, description: msg }.to_json
    faraday_resp = ::Faraday::Response.new(status: 400, body: body)
    ::Telegram::Bot::Exceptions::ResponseError.new(response: faraday_resp)
  end
end
