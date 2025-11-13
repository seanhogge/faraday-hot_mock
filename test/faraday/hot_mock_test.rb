require "test_helper"
require "colorize"

class Faraday::HotMockTest < ActiveSupport::TestCase
  setup do
    @stub = stub_request(:any, /dog.ceo/).to_return(status: 200, body: "{}")
    @recorded_stub = stub_request(
      :any,
      "https://dog.ceo/record_mock",
    ).to_return(
      status: 200,
      headers: { "Content-Type" => "application/json" },
      body: "{\"message\":\"Mock recorded\"}",
    )
  end

  teardown do
    FileUtils.rm(Rails.root.join("tmp/mocking-test.txt")) if File.exist?(Rails.root.join("tmp/mocking-test.txt"))
    FileUtils.rm(Rails.root.join("lib/faraday/mocks/test/hot_mocks.yml")) if File.exist?(Rails.root.join("lib/faraday/mocks/test/hot_mocks.yml"))
    WebMock.enable!
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

  test "can add mocks via the `mock!` method" do
    faraday = Faraday.new do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.adapter :hot_mock
    end

    mocked_response = faraday.get do |req|
      req.url "https://dog.ceo/api/v1/hot_mock"
    end

    assert_equal 200, mocked_response.status
    assert_equal(
      "{}",
      mocked_response.body
    )

    Faraday::HotMock.mock!(
      method:  :get,
      url:     "dog.ceo/api/v1/hot_mock",
      status:  418,
      headers: {
        "Content-Type" => "application/json"
      },
      body:    {
        message: "I'm a hot_mocked teapot",
        status: "418"
      }
    )

    Faraday::HotMock.enable!

    faraday = Faraday.new do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.adapter :hot_mock
    end

    mocked_response = faraday.get do |req|
      req.url "https://dog.ceo/api/v1/hot_mock"
    end

    assert_equal 418, mocked_response.status
    assert_equal "application/json", mocked_response.headers["Content-Type"]
    assert_equal(
      { message: "I'm a hot_mocked teapot", status: "418" },
      mocked_response.body
    )
  end

  test "can check for existing mocks via the `mocked?` method" do
    assert_not Faraday::HotMock.mocked?(method: :get, url: "dog.ceo/api/v1/hot_mock_check"), "SETUP: The GET mock for 'dog.ceo/api/v1/hot_mock_check' should not exist".black.on_yellow

    Faraday::HotMock.mock!(
      method:  :get,
      url:     "dog.ceo/api/v1/hot_mock_check",
      status:  200,
      headers: {},
      body:    {}
    )

    assert Faraday::HotMock.mocked?(method: :get, url: "dog.ceo/api/v1/hot_mock_check"), "The GET mock for 'dog.ceo/api/v1/hot_mock_check' should exist".black.on_red
    assert_not Faraday::HotMock.mocked?(method: :post, url: "dog.ceo/api/v1/hot_mock_check"), "The POST mock for 'dog.ceo/api/v1/hot_mock_check' should not exist".black.on_red
    assert_not Faraday::HotMock.mocked?(method: :get, url: "dog.ceo/api/v1/non_existent_mock"), "The GET mock for 'dog.ceo/api/v1/non_existent_mock' should not exist".black.on_red
  end

  test "can record mocks via the `record` method" do
    Faraday::HotMock.enable!

    url = "https://dog.ceo/record_mock"

    Faraday::HotMock.record(method: :get, url: url)
    assert_requested @recorded_stub

    assert Faraday::HotMock.mocked?(method: :get, url: url), "The GET mock for '#{url}' should exist after recording".black.on_red

    faraday = Faraday.new do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.adapter :hot_mock
    end

    mocked_response = faraday.get(url)

    assert_equal 200, mocked_response.status
    assert_equal "application/json", mocked_response.headers["Content-Type"]
    assert mocked_response.headers["X-HotMock-Recorded-At"], "The response headers should contain 'X-HotMock-Recorded-At'".black.on_red
    assert mocked_response.body.key?("message"), "The response body should contain a 'message' key".black.on_red
  end

  test "record does not duplicate existing mocks" do
    Faraday::HotMock.enable!

    url = "https://dog.ceo/record_mock"

    Faraday::HotMock.mock!(method: :get, url: url, status: 418, headers: {}, body: {})

    Faraday::HotMock.record(method: :get, url: url)

    faraday = Faraday.new do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.adapter :hot_mock
    end

    mocked_response = faraday.get(url)

    assert_equal 418, mocked_response.status, "The status code should remain 418 after attempting to record an existing mock".black.on_red
    assert_not mocked_response.headers.key?("X-HotMock-Recorded-At"), "The response headers should not contain 'X-HotMock-Recorded-At' after attempting to record an existing mock".black.on_red
  end

  test "can forcefully record mocks via the `record!` method" do
    Faraday::HotMock.enable!

    url = "https://dog.ceo/record_mock"

    Faraday::HotMock.mock!(method: :get, url: url, status: 418, headers: {}, body: {})

    Faraday::HotMock.record!(method: :get, url: url)

    faraday = Faraday.new do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.adapter :hot_mock
    end

    mocked_response = faraday.get(url)

    assert_equal 200, mocked_response.status, "The status code should be updated to 200 after forcefully recording the mock".black.on_red
    assert mocked_response.headers.key?("X-HotMock-Recorded-At"), "The response headers should contain 'X-HotMock-Recorded-At' after forcefully recording the mock".black.on_red
  end
end
