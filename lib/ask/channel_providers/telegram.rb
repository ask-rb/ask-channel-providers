# frozen_string_literal: true

require_relative "telegram/bot"
require_relative "telegram/adapter"

module Ask
  module ChannelProviders
    # Telegram channel provider for the ask-coder ecosystem.
    #
    # Provides a polling-based Telegram bot client and a ChannelAdapter
    # implementation that plugs into Ask::Coder.
    module Telegram
    end
  end
end
