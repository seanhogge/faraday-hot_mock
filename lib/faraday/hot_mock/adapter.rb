# frozen_string_literal: true

require "yaml"
require "pathname"
require "faraday"

module Faraday
  module HotMock
    class Adapter < Faraday::Adapter
      def initialize(app, options = {})
        super(app)
        @enabled_file = options[:enabled_file] || "tmp/mocking-#{Rails.env}.txt"
        fallback = options[:fallback] || Faraday.default_adapter
        @fallback_adapter = Faraday::Adapter.lookup_middleware(fallback)
        @mocks = Faraday::HotMock.mocks
      end

      def call(env)
        super

        if Rails.env.production?
          return @fallback_adapter.new(@app, @options).call(env)
        end

        if Faraday::HotMock.enabled? && (mock = Faraday::HotMock.mocked?(method: env.method, url: env.url))
          save_response(env, mock["status"] || 200, mock["body"] || "", mock["headers"] || {})
        else
          @fallback_adapter.new(@app, @options).call(env)
        end
      end
    end
  end
end
