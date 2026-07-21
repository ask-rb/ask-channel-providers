# frozen_string_literal: true

require_relative "lib/ask/channel_providers/version"

Gem::Specification.new do |spec|
  spec.name = "ask-channel-providers"
  spec.version = Ask::ChannelProviders::VERSION
  spec.authors = ["Kaka Ruto"]
  spec.email = ["kaka@myrrlabs.com"]

  spec.summary = "Messaging channel adapters for the ask-rb ecosystem"
  spec.description = "Channel adapter interface and implementations (Telegram, Discord, Slack) for connecting AI coding agents to messaging platforms."
  spec.homepage = "https://github.com/ask-rb/ask-channel-providers"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "telegram-bot-ruby", "~> 2.0"

  spec.add_development_dependency "minitest", "~> 5.25"
  spec.add_development_dependency "mocha", "~> 3.1"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
end
