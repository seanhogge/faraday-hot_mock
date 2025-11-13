require "faraday/hot_mock/version"
require "faraday/hot_mock/railtie"
require "faraday/hot_mock/adapter"
require "faraday"

module Faraday
  module HotMock
    module_function

    def disable!
      FileUtils.rm_f(Rails.root.join("tmp/mocking-#{Rails.env}.txt"))
    end

    def disabled?
      !File.exist?(Rails.root.join("tmp/mocking-#{Rails.env}.txt"))
    end

    def enable!
      FileUtils.touch(Rails.root.join("tmp/mocking-#{Rails.env}.txt"))
    end

    def enabled?
      File.exist?(Rails.root.join("tmp/mocking-#{Rails.env}.txt"))
    end

    def toggle!
      if File.exist?(Rails.root.join("tmp/mocking-#{Rails.env}.txt"))
        disable!
      else
        enable!
      end
    end
  end
end

Faraday::Adapter.register_middleware hot_mock: Faraday::HotMock::Adapter
