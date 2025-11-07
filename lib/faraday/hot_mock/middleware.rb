# frozen_string_literal: true

require "yaml"
require "pathname"
require "faraday"

module Faraday
  module HotMock
    class Middleware < Faraday::Middleware
      def initialize(app, options = {})
        super(app)
        @mock_dir = options[:mock_dir] || default_mock_dir
        @enabled_file = options[:enabled_file] || "tmp/mocking-#{Rails.env}.txt"
        @mocks = load_mocks
      end

      def call(env)
        return @app.call(env) unless mocking_enabled?

        if @mocks && (mock = find_mock(env.method, env.url))
          env[:status] = mock["status"] || 200
          env[:response_headers] = Faraday::Utils::Headers.new(
            mock["headers"] || {},
          )
          env[:body] = mock["body"] || ""

          response = Faraday::Response.new(env)
          response.on_complete { |response_env| }

          return response
        end

        @app.call(env)
      end

      private

      def load_mocks
        return [] unless Dir.exist?(@mock_dir)

        mocks = []

        yaml_files.each do |file|
          file_mocks = YAML.load_file(file)
          mocks.concat(file_mocks) if file_mocks.is_a?(Array)
        end

        mocks
      end

      def mocking_enabled?
        File.exist?(@enabled_file)
      end

      def default_mock_dir
        rails_env = defined?(Rails) ? Rails.env : ENV["RAILS_ENV"] || "development"
        "lib/faraday/mocks/#{rails_env}"
      end

      def find_mock(method, url)
        return nil unless @mocks.any?

        @mocks.find do |mock|
          url_matches = Regexp.new(mock["url_pattern"]).match?(url)
          method_matches = mock["method"].nil? || mock["method"].to_s.upcase == method.to_s.upcase

          url_matches && method_matches
        end
      end

      def yaml_files
        Dir.glob(File.join(@mock_dir, "**", "*.{yml,yaml}"))
      end
    end
  end
end
