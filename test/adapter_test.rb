# frozen_string_literal: true

require_relative "test_helper"

class ChannelAdapterTest < Minitest::Test
  class TestAdapter < Ask::ChannelProviders::Adapter
  end

  def setup
    @adapter = TestAdapter.new
  end

  def test_start_raises_not_implemented
    assert_raises(NotImplementedError) { @adapter.start }
  end

  def test_stop_raises_not_implemented
    assert_raises(NotImplementedError) { @adapter.stop }
  end

  def test_send_message_raises_not_implemented
    assert_raises(NotImplementedError) { @adapter.send_message(123, "hello") }
  end

  def test_edit_message_raises_not_implemented
    assert_raises(NotImplementedError) { @adapter.edit_message(123, 1, "hi") }
  end

  def test_request_approval_raises_not_implemented
    assert_raises(NotImplementedError) { @adapter.request_approval(123, tool_name: "Bash", risk_level: "medium", details: "test") }
  end

  def test_running_returns_false_by_default
    refute @adapter.running?
  end
end
