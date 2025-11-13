require "faraday/hot_mock/version"
require "faraday/hot_mock/railtie"
require "faraday/hot_mock/adapter"
require "faraday"

module Faraday
  module HotMock
    extend self

    def disable!
      FileUtils.rm_f(hot_mocking_file)
    end

    def disabled?
      !File.exist?(hot_mocking_file)
    end

    def enable!
      FileUtils.touch(hot_mocking_file)
    end

    def enabled?
      File.exist?(hot_mocking_file)
    end

    def toggle!
      if File.exist?(hot_mocking_file)
        disable!
      else
        enable!
      end
    end

    def delete_mock(method:, url:)
      return unless File.exist?(hot_mock_file)

      mocks = YAML.load_file(hot_mock_file) || []

      mocks.reject! { |entry| entry["url_pattern"] == url && entry["method"].to_s.upcase == method.to_s.upcase }

      File.write(hot_mock_file, mocks.to_yaml)
    end

    def mock!(method:, url:, status:, headers: {}, body: nil)
      FileUtils.touch(hot_mock_file)

      mocks = YAML.load_file(hot_mock_file) || []

      mocks.reject! { |entry| entry["url_pattern"] == url && entry["method"].to_s.upcase == method.to_s.upcase }

      mocks << {
        "method"      => method.to_s.upcase,
        "url_pattern" => url,
        "status"      => status,
        "headers"     => headers,
        "body"        => body
      }

      File.write(hot_mock_file, mocks.to_yaml)
    end

    def mocked?(method:, url:)
      mocks.find { |entry| entry["method"].to_s.upcase == method.to_s.upcase && Regexp.new(entry["url_pattern"]).match?(url.to_s) } || false
    end

    def record(method:, url:)
      return false if mocked?(method:, url:)

      faraday = Faraday.new

      response = faraday.send(method.downcase.to_sym, url)

      FileUtils.touch(hot_mock_file)

      hot_mocks = YAML.load_file(hot_mock_file) || []

      hot_mocks << {
        "method"      => method.to_s.upcase,
        "url_pattern" => url,
        "status"      => response.status,
        "headers"     => response.headers.to_h.merge("x-hotmock-recorded-at" => Time.now.utc.iso8601),
        "body"        => response.body
      }

      File.write(hot_mock_file, hot_mocks.to_yaml)
    rescue Faraday::Error => e
      puts "Error recording mock for #{method.upcase} #{url}: #{e.message}"
    end

    def record!(method:, url:)
      faraday = Faraday.new

      response = faraday.send(method.downcase.to_sym, url)

      FileUtils.touch(hot_mock_file)

      hot_mocks = YAML.load_file(hot_mock_file) || []

      hot_mocks.reject! { |entry| entry["url_pattern"] == url && entry["method"].to_s.upcase == method.to_s.upcase }

      hot_mocks << {
        "method"      => method.to_s.upcase,
        "url_pattern" => url,
        "status"      => response.status,
        "headers"     => response.headers.to_h.merge("x-hotmock-recorded-at" => Time.now.utc.iso8601),
        "body"        => response.body
      }

      File.write(hot_mock_file, hot_mocks.to_yaml)
    rescue Faraday::Error => e
      puts "Error recording mock for #{method.upcase} #{url}: #{e.message}"
    end

    def hot_mock_dir
      Rails.root.join "lib/faraday/mocks/#{Rails.env}"
    end

    def hot_mocking_file
      Rails.root.join "tmp/mocking-#{Rails.env}.txt"
    end

    def hot_mock_file
      Rails.root.join(hot_mock_dir, "hot_mocks.yml")
    end

    def mocks
      return [] unless Dir.exist?(hot_mock_dir)

      mocks = []

      all_hot_mock_files.each do |file|
        file_mocks = YAML.load_file(file)
        mocks.concat(file_mocks) if file_mocks.is_a?(Array)
      end

      mocks
    end

    def all_hot_mock_files
      Dir.glob(File.join(hot_mock_dir, "**", "*.{yml,yaml}"))
    end
  end
end

Faraday::Adapter.register_middleware hot_mock: Faraday::HotMock::Adapter
