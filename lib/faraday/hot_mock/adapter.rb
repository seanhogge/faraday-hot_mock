# frozen_string_literal: true

require "yaml"
require "pathname"
require "faraday"

module Faraday
  module HotMock
    class Adapter < Faraday::Adapter
      def initialize(app, options = {})
        super(app)
        @mock_dir = options[:mock_dir] || default_mock_dir
        @enabled_file = options[:enabled_file] || "tmp/mocking-#{Rails.env}.txt"
        fallback = options[:fallback] || Faraday.default_adapter
        @fallback_adapter = Faraday::Adapter.lookup_middleware(fallback)
        @mocks = load_mocks
      end

      def call(env)
        super
        if mocking_enabled? && @mocks && (mock = find_mock(env.method, env.url))
          save_response(env, mock["status"] || 200, mock["body"] || "", mock["headers"] || {})
        else
          @fallback_adapter.new(@app, @options).call(env)
        end
      end

      private

      def load_mocks
        return [] unless Dir.exist?(Rails.root.join @mock_dir)

        mocks = []

        yaml_files.each do |file|
          file_mocks = YAML.load_file(file)
          mocks.concat(file_mocks) if file_mocks.is_a?(Array)
        end

        mocks
      end

      def mocking_enabled?
        File.exist?(Rails.root.join @enabled_file)
      end

      def default_mock_dir
        rails_env = defined?(Rails) ? Rails.env : ENV["RAILS_ENV"] || "development"
        "lib/faraday/mocks/#{rails_env}"
      end

      def find_mock(method, url)
        return nil unless @mocks.any?

        @mocks.find do |mock|
          url_matches = Regexp.new(mock["url_pattern"]).match?(url.to_s)
          method_matches = mock["method"].nil? || mock["method"].to_s.upcase == method.to_s.upcase

          url_matches && method_matches
        end
      end

      def yaml_files
        Dir.glob(File.join(Rails.root.join(@mock_dir), "**", "*.{yml,yaml}"))
      end
    end
  end
end
