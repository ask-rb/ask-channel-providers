# frozen_string_literal: true

require_relative "channel_providers/version"
require_relative "channel_providers/card"
require_relative "channel_providers/adapter"
require_relative "channel_providers/inbound_message"
require_relative "channel_providers/webhook_adapter"
require_relative "channel_providers/telegram"
require_relative "channel_providers/whatsapp"

module Ask
  module ChannelProviders
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class APIError < Error; end
  end
end
