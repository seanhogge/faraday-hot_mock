require "faraday/hot_mock/version"
require "faraday/hot_mock/railtie"
require "faraday/hot_mock/adapter"
require "faraday"

module Faraday
  module HotMock
  end
end

Faraday::Adapter.register_middleware hot_mock: Faraday::HotMock::Adapter
