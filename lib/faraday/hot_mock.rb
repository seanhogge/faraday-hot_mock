require "faraday/hot_mock/version"
require "faraday/hot_mock/railtie"
require "faraday/hot_mock/middleware"
require "faraday"

module Faraday
  module HotMock
  end
end

Faraday::Request.register_middleware hot_mock: Faraday::HotMock::Middleware
