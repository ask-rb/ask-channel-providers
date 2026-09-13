# ask-channel-providers

[![Gem Version](https://badge.fury.io/rb/ask-channel-providers.svg)](https://badge.fury.io/rb/ask-channel-providers)

Channel adapters for messaging platforms in the ask-rb ecosystem. It defines
a uniform adapter interface for receiving and sending messages, approvals,
and rich cards, plus a cross-platform card system. Telegram (polling) and
WhatsApp Cloud API (webhooks) are implemented; other platforms can be added
by subclassing the adapter.

## Installation

```ruby
gem "ask-channel-providers"
```

## Quick Start

```ruby
require "ask-channel-providers"

adapter = Ask::ChannelProviders::Telegram::Adapter.new(
  token: "your_telegram_bot_token",
  allowed_users: [],
  allowed_chats: []
)

adapter.start do |msg|
  # msg is { chat_id:, user_id:, text:, session_key: }
  adapter.send_message(msg[:chat_id], "Echo: #{msg[:text]}")
end
```

## WhatsApp (webhooks)

WhatsApp is webhook-driven: the provider POSTs to your endpoint, so
verification and parsing are class-level and stateless, while delivery is
bound to one phone number. Secrets are passed in — the gem never reads
global config — so one process can serve many accounts.

```ruby
adapter_class = Ask::ChannelProviders::WhatsApp::Adapter

# GET /webhooks/whatsapp — registration challenge
challenge = adapter_class.challenge(params, verify_token: ENV["WHATSAPP_VERIFY_TOKEN"])

# POST /webhooks/whatsapp — verify, then parse
ok = adapter_class.verify_signature(
  raw_body: request.body.read,
  signature: request.headers["X-Hub-Signature-256"],
  secret: ENV["WHATSAPP_APP_SECRET"]
)
messages = adapter_class.parse(JSON.parse(raw_body)) # => [InboundMessage]

# Reply for one configured number
adapter = adapter_class.new(phone_number_id: "123", access_token: "EAAG...")
adapter.deliver(to: "254712345678", text: "Karibu! How can we help?")
adapter.mark_read(message_id: "wamid....")
```

## Key entry points

- `Ask::ChannelProviders::Adapter` - base class for channel adapters.
  Implement `start(config:, &on_message)` (the callback receives
  `{ chat_id:, user_id:, text:, session_key: }`), `stop`, `send_message`,
  `edit_message`, `request_approval`, and `send_card`.
- `Ask::ChannelProviders::WebhookAdapter` - base class for webhook-driven
  channels: implement `.provider`, `.verify_signature`, `.parse`, and
  `#deliver`; `.challenge` and `#mark_read` have safe defaults.
- `Ask::ChannelProviders::InboundMessage` - the normalized inbound message
  (`provider`, `external_uid`, `channel_id`, `message_id`, `kind`, `text`,
  `name`, `timestamp`).
- `Ask::ChannelProviders::Telegram::Adapter` - the Telegram implementation,
  backed by the polling-based `Telegram::Bot`. Config: `token`,
  `allowed_users`, `allowed_chats`.
- `Ask::ChannelProviders::WhatsApp::Adapter` / `::Client` - the WhatsApp
  Cloud API implementation (Meta Graph API, direct): webhook verification
  and parsing, chunked text sends, read receipts.
- `Ask::ChannelProviders::Card` - a structured UI element each adapter
  renders to its native format. Build cards with `section`, `text`,
  `button(label, callback:, url:)`, `table(header:, rows:)`, and `divider`.
- `Ask::ChannelProviders::Error`, `ConfigurationError`, and `APIError` -
  errors raised by channel adapters.

## Full documentation

The full ask-rb documentation lives at https://ask-rb.github.io/ask-docs.
[Reference: Gem Index](https://ask-rb.github.io/ask-docs/reference/gems)
covers ask-channel-providers in depth. API reference:
https://ask-rb.github.io/ask-docs/reference/api.

## Development

```
bundle install
bundle exec rake test
```

## License

MIT
