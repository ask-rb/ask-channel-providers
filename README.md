# ask-channel-providers

[![Gem Version](https://badge.fury.io/rb/ask-channel-providers.svg)](https://badge.fury.io/rb/ask-channel-providers)

Channel adapters for messaging platforms in the ask-rb ecosystem. It defines
a uniform adapter interface for receiving and sending messages, approvals,
and rich cards, plus a cross-platform card system. Only Telegram is
implemented today; other platforms can be added by subclassing the adapter.

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

## Key entry points

- `Ask::ChannelProviders::Adapter` - base class for channel adapters.
  Implement `start(config:, &on_message)` (the callback receives
  `{ chat_id:, user_id:, text:, session_key: }`), `stop`, `send_message`,
  `edit_message`, `request_approval`, and `send_card`.
- `Ask::ChannelProviders::Telegram::Adapter` - the Telegram implementation,
  backed by the polling-based `Telegram::Bot`. Config: `token`,
  `allowed_users`, `allowed_chats`.
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
