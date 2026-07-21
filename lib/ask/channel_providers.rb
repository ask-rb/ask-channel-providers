# frozen_string_literal: true

require_relative "channel_providers/version"
require_relative "channel_providers/card"
require_relative "channel_providers/adapter"
require_relative "channel_providers/telegram"

module Ask
  module ChannelProviders
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class APIError < Error; end
  end
end
