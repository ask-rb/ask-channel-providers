# frozen_string_literal: true

require_relative "whatsapp/transport"
require_relative "whatsapp/client"
require_relative "whatsapp/adapter"

module Ask
  module ChannelProviders
    # WhatsApp Cloud API support (Meta's Graph API, direct — no BSP).
    module WhatsApp
    end
  end
end
