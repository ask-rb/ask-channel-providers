# Changelog

All notable changes to ask-channel-providers are documented here,
following the keep-a-changelog format.

## [Unreleased]

## [0.2.0] - 2026-09-13

### Added

- `Ask::ChannelProviders::WebhookAdapter` — base class for webhook-driven
  channels where the provider pushes to your HTTP endpoint: class-level
  `.provider`, `.verify_signature`, `.challenge`, `.parse`, and
  instance-level `#deliver`/`#mark_read`.
- `Ask::ChannelProviders::InboundMessage` — one normalized inbound message
  shape across providers, with JSON-safe `#to_h`/`.from_h` for background
  job serialization.
- `Ask::ChannelProviders::WhatsApp` — WhatsApp Cloud API (Meta Graph API,
  direct): X-Hub-Signature-256 verification, webhook challenge, payload
  parsing, and a client that sends chunked text messages and read receipts.

## [0.1.0] - 2026-09-04

### Added

- Channel adapter interface and messaging channel implementations
  (Telegram, Discord, Slack) for connecting AI coding agents to
  messaging platforms.
- Standard ask-gem infrastructure: LICENSE, CI workflow (Ruby 3.2–3.4
  matrix), and release docs.
