# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "test/"
  add_filter "version.rb"
  enable_coverage :branch
  minimum_coverage 90
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "ostruct"
require "ask-channel-providers"
require "minitest/autorun"
require "mocha/minitest"
