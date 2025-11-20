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
          interpolate(mock, env) if mock_interpolated?(mock)

          save_response(
            env,
            mock["status"] || 200,
            mock["body"] || "",
            (mock["headers"] || {}).merge("x-hot-mocked" => "true")
          )
        else
          @fallback_adapter.new(@app, @options).call(env)
        end
      end

      private

      def mock_interpolated?(mock)
        mock.key?("interpolate") && mock["body"].is_a?(Hash)
      end

      def interpolate(mock, env)
        request_hash = JSON.parse(env.request_body) rescue {}

        interpolated_hash = mock["interpolate"].transform_values do |v|
          v = request_hash[v]
        end.compact

        mock["body"].merge!(interpolated_hash || {})
      end
    end
  end
end
