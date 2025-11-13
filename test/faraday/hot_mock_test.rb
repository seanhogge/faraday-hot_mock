require "test_helper"
require "colorize"

class Faraday::HotMockTest < ActiveSupport::TestCase
  setup do
    @stub = stub_request(:any, /dog.ceo/).to_return(status: 200, body: "{}")
  end

  teardown do
    FileUtils.rm(Rails.root.join("tmp/mocking-test.txt")) if File.exist?(Rails.root.join("tmp/mocking-test.txt"))
  end

  test "it has a version number" do
    assert Faraday::HotMock::VERSION
  end

  test "mocks are used only when the mocking file is present" do
    assert_not File.exist?(Rails.root.join("tmp/mocking-test.txt")), "SETUP: The mocking file should not exist before the test.".black.on_yellow


    DogPhotoService.new.conn.get "breeds/image/random"
    assert_requested @stub

    FileUtils.touch(Rails.root.join("tmp/mocking-test.txt"))
    assert File.exist?(Rails.root.join("tmp/mocking-test.txt")), "SETUP: The mocking file should have been successfully created.".black.on_yellow

    mocked_request = DogPhotoService.new.conn.get "breeds/image/random"
    assert mocked_request.status == 418, "Expected a mocked request to be a teapot (return status 418)".black.on_red
  end

  test "multiple files can be loaded from the mock directory" do
    FileUtils.touch(Rails.root.join("tmp/mocking-test.txt"))
    assert File.exist?(Rails.root.join("tmp/mocking-test.txt")), "SETUP: The mocking file should have been successfully created.".black.on_yellow

    mocked_request_1 = DogPhotoService.new.conn.get "breeds/image/random"
    assert mocked_request_1.status == 418, "Expected a mocked request to be a teapot (return status 418)".black.on_red

    mocked_request_2 = DogPhotoService.new.conn.get "breeds/image/breeds/list/all"
    assert mocked_request_2.status == 418, "Expected a mocked request to be a teapot (return status 418)".black.on_red
  end

  test "mocks can be filtered by HTTP method" do
    FileUtils.touch(Rails.root.join("tmp/mocking-test.txt"))
    assert File.exist?(Rails.root.join("tmp/mocking-test.txt")), "SETUP: The mocking file should have been successfully created.".black.on_yellow

    mocked_get_request = DogPhotoService.new.conn.get "breeds/image/breeds/list/all"
    assert mocked_get_request.status == 418, "Expected a mocked request to be a teapot (return status 418)".black.on_red

    DogPhotoService.new.conn.post "breeds/image/breeds/list/all"
    assert_requested @stub
  end

  test "YAML files in subdirectories are used for mock matching" do
    FileUtils.touch(Rails.root.join("tmp/mocking-test.txt"))
    assert File.exist?(Rails.root.join("tmp/mocking-test.txt")), "SETUP: The mocking file should have been successfully created.".black.on_yellow

    mocked_get_request = DogPhotoService.new.conn.get "breed/pyrenees/images"
    assert mocked_get_request.status == 418, "Expected a mocked request to be a teapot (return status 418)".black.on_red
  end

  test "can enable and disable mocking via module methods" do
    assert_not File.exist?(Rails.root.join("tmp/mocking-test.txt")), "SETUP: The mocking file should not exist before the test.".black.on_yellow

    Faraday::HotMock.enable!
    assert     File.exist?(Rails.root.join("tmp/mocking-test.txt")), "The mocking file should exist after enabling".black.on_red
    assert     Faraday::HotMock.enabled?, "`enabled?` should be `true` after being enabled".black.on_red
    assert_not Faraday::HotMock.disabled?, "`disabled?` should be `false` after being enabled".black.on_red

    Faraday::HotMock.disable!
    assert_not File.exist?(Rails.root.join("tmp/mocking-test.txt")), "The mocking file should not exist after disabling".black.on_red
    assert_not Faraday::HotMock.enabled?, "`enabled?` should be `false` after being disabled".black.on_red
    assert     Faraday::HotMock.disabled?, "`disabled?` should be `true` after being disabled".black.on_red

    Faraday::HotMock.toggle!
    assert     File.exist?(Rails.root.join("tmp/mocking-test.txt")), "The mocking file should exist after toggling from disabled".black.on_red
    assert     Faraday::HotMock.enabled?, "`enabled?` should be true after toggling from disabled".black.on_red
    assert_not Faraday::HotMock.disabled?, "`disabled?` should be false after toggling from disabled".black.on_red

    Faraday::HotMock.toggle!
    assert_not File.exist?(Rails.root.join("tmp/mocking-test.txt")), "The mocking file should not exist after toggling from enabled".black.on_red
    assert_not Faraday::HotMock.enabled?, "`enabled?` should be false after toggling from enabled".black.on_red
    assert     Faraday::HotMock.disabled?, "`disabled?` should be true after toggling from enabled".black.on_red
  end
end
