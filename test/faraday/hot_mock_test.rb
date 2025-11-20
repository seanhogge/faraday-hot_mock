require "test_helper"
require "colorize"

class Faraday::HotMockTest < ActiveSupport::TestCase
  setup do
    @stub = stub_request(:any, /dog.ceo/).to_return(status: 200, body: '{"attempted_real_request": "true"}')
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
    FileUtils.rm_rf(Faraday::HotMock.scenario_dir)
    Faraday::HotMock.scenario = nil
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
    assert_includes mocked_request.headers.keys, Faraday::HotMock::HEADERS[:mocked], "Expected the success scenario to include the 'x-hot-mocked' header".black.on_red
    assert_equal "true", mocked_request.headers[Faraday::HotMock::HEADERS[:mocked]], "Expected the 'x-hot-mocked' header to be 'true'".black.on_red
  end

  test "multiple files can be loaded from the mock directory" do
    FileUtils.touch(Rails.root.join("tmp/mocking-test.txt"))
    assert File.exist?(Rails.root.join("tmp/mocking-test.txt")), "SETUP: The mocking file should have been successfully created.".black.on_yellow

    mocked_request_1 = DogPhotoService.new.conn.get "breeds/image/random"
    assert mocked_request_1.status == 418, "Expected a mocked request to be a teapot (return status 418)".black.on_red
    assert_includes mocked_request_1.headers.keys, Faraday::HotMock::HEADERS[:mocked], "Expected the success scenario to include the 'x-hot-mocked' header".black.on_red
    assert_equal "true", mocked_request_1.headers[Faraday::HotMock::HEADERS[:mocked]], "Expected the 'x-hot-mocked' header to be 'true'".black.on_red

    mocked_request_2 = DogPhotoService.new.conn.get "breeds/image/breeds/list/all"
    assert mocked_request_2.status == 418, "Expected a mocked request to be a teapot (return status 418)".black.on_red
    assert_includes mocked_request_2.headers.keys, Faraday::HotMock::HEADERS[:mocked], "Expected the success scenario to include the 'x-hot-mocked' header".black.on_red
    assert_equal "true", mocked_request_2.headers[Faraday::HotMock::HEADERS[:mocked]], "Expected the 'x-hot-mocked' header to be 'true'".black.on_red
  end

  test "mocks can be filtered by HTTP method" do
    FileUtils.touch(Rails.root.join("tmp/mocking-test.txt"))
    assert File.exist?(Rails.root.join("tmp/mocking-test.txt")), "SETUP: The mocking file should have been successfully created.".black.on_yellow

    mocked_request = DogPhotoService.new.conn.get "breeds/image/breeds/list/all"
    assert mocked_request.status == 418, "Expected a mocked request to be a teapot (return status 418)".black.on_red
    assert_includes mocked_request.headers.keys, Faraday::HotMock::HEADERS[:mocked], "Expected the success scenario to include the 'x-hot-mocked' header".black.on_red
    assert_equal "true", mocked_request.headers[Faraday::HotMock::HEADERS[:mocked]], "Expected the 'x-hot-mocked' header to be 'true'".black.on_red

    DogPhotoService.new.conn.post "breeds/image/breeds/list/all"
    assert_requested @stub
  end

  test "YAML files in subdirectories are used for mock matching" do
    Faraday::HotMock.enable!

    mocked_request = DogPhotoService.new.conn.get "breed/boxer/images"
    assert mocked_request.status == 418, "Expected a mocked request to be a teapot (return status 418)".black.on_red
    assert_includes mocked_request.headers.keys, Faraday::HotMock::HEADERS[:mocked], "Expected the success scenario to include the 'x-hot-mocked' header".black.on_red
    assert_equal "true", mocked_request.headers[Faraday::HotMock::HEADERS[:mocked]], "Expected the 'x-hot-mocked' header to be 'true'".black.on_red
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

    mocked_request = faraday.get do |req|
      req.url "https://dog.ceo/api/v1/hot_mock"
    end

    assert_equal 200, mocked_request.status

    assert_equal(
      '{"attempted_real_request": "true"}',
      mocked_request.body
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

    mocked_request = faraday.get do |req|
      req.url "https://dog.ceo/api/v1/hot_mock"
    end

    assert_equal 418, mocked_request.status
    assert_equal "application/json", mocked_request.headers["Content-Type"]
    assert_equal(
      { message: "I'm a hot_mocked teapot", status: "418" },
      mocked_request.body
    )
    assert_includes mocked_request.headers.keys, Faraday::HotMock::HEADERS[:mocked], "Expected the success scenario to include the 'x-hot-mocked' header".black.on_red
    assert_equal "true", mocked_request.headers[Faraday::HotMock::HEADERS[:mocked]], "Expected the 'x-hot-mocked' header to be 'true'".black.on_red
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

    Faraday::HotMock.delete(method: :get, url: url)
    Faraday::HotMock.record(method: :get, url: url)
    assert_requested @recorded_stub

    assert Faraday::HotMock.mocked?(method: :get, url: url), "The GET mock for '#{url}' should exist after recording".black.on_red

    faraday = Faraday.new do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.adapter :hot_mock
    end

    mocked_request = faraday.get(url)

    assert_equal 200, mocked_request.status
    assert_equal "application/json", mocked_request.headers["Content-Type"]
    assert mocked_request.headers[Faraday::HotMock::HEADERS[:recorded]], "The response headers should contain '#{Faraday::HotMock::HEADERS[:recorded]}'".black.on_red
    assert mocked_request.body.key?("message"), "The response body should contain a 'message' key".black.on_red
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

    mocked_request = faraday.get(url)

    assert_equal 418, mocked_request.status, "The status code should remain 418 after attempting to record an existing mock".black.on_red
    assert_not mocked_request.headers.key?(Faraday::HotMock::HEADERS[:recorded]), "The response headers should not contain 'x-hot-mock-recorded-at' after attempting to record an existing mock".black.on_red
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

    mocked_request = faraday.get(url)

    assert_equal 200, mocked_request.status, "The status code should be updated to 200 after forcefully recording the mock".black.on_red
    assert mocked_request.headers.key?(Faraday::HotMock::HEADERS[:recorded]), "The response headers should contain 'x-hot-mock-recorded-at' after forcefully recording the mock".black.on_red
  end

  test "a scenario constrains matches to only those in the scenario" do
    Faraday::HotMock.enable!

    FileUtils.mkdir_p(Faraday::HotMock.hot_mock_dir.join("scenarios/success"))
    FileUtils.mkdir_p(Faraday::HotMock.hot_mock_dir.join("scenarios/failure"))
    success_file = Faraday::HotMock.hot_mock_dir.join("scenarios/success/success_mocks.yml")
    failure_file = Faraday::HotMock.hot_mock_dir.join("scenarios/failure/failure_mocks.yml")

    success_mocks = [
      {
        "method"      => "GET",
        "url_pattern" => "breeds/image/random",
        "status"      => 201,
        "body"        => nil
      }
    ]

    failure_mocks = [
      {
        "method"      => "GET",
        "url_pattern" => "breeds/image/random",
        "status"      => 429,
        "body"        => nil
      }
    ]

    File.write(success_file, success_mocks.to_yaml)
    File.write(failure_file, failure_mocks.to_yaml)

    faraday = Faraday.new do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.adapter :hot_mock
    end

    Faraday::HotMock.scenario = :success

    success_request = faraday.get("breeds/image/random")

    assert_equal 201, success_request.status, "Expected the success scenario to return status 201".black.on_red
    assert_includes success_request.headers.keys, Faraday::HotMock::HEADERS[:mocked], "Expected the success scenario to include the 'x-hot-mocked' header".black.on_red
    assert_equal "true", success_request.headers[Faraday::HotMock::HEADERS[:mocked]], "Expected the 'x-hot-mocked' header to be 'true'".black.on_red

    Faraday::HotMock.scenario = :failure

    failure_request = faraday.get("breeds/image/random")

    assert_equal 429, failure_request.status, "Expected the failure scenario to return status 429".black.on_red
    assert_includes success_request.headers.keys, Faraday::HotMock::HEADERS[:mocked], "Expected the success scenario to include the 'x-hot-mocked' header".black.on_red
    assert_equal "true", success_request.headers[Faraday::HotMock::HEADERS[:mocked]], "Expected the 'x-hot-mocked' header to be 'true'".black.on_red
  end

  test "when no scenario is set, no mocks in scenarios directory are matched" do
    Faraday::HotMock.enable!

    FileUtils.mkdir_p(Faraday::HotMock.hot_mock_dir.join("scenarios/success"))
    scenario_file = Faraday::HotMock.hot_mock_dir.join("scenarios/success/success_mocks.yml")

    scenario_mocks = [
      {
        "method"      => "GET",
        "url_pattern" => "breeds/image/random",
        "status"      => 204,
        "body"        => nil
      }
    ]

    File.write(scenario_file, scenario_mocks.to_yaml)

    faraday = Faraday.new do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.adapter :hot_mock
    end

    mocked_request = faraday.get("https://dog.ceo/api/breeds/image/random")

    assert_equal 418, mocked_request.status, "Expected the request to use the root mock request returning status 418".black.on_red
    assert_includes mocked_request.headers.keys, Faraday::HotMock::HEADERS[:mocked], "Expected the response to include the 'x-hot-mocked' header".black.on_red
    assert_equal "true", mocked_request.headers[Faraday::HotMock::HEADERS[:mocked]], "Expected the 'x-hot-mocked' header to be 'true'".black.on_red
  end

  test "vcr mode records a mock into a scenario and returns it if not already mocked, and changes current scenario" do
    new_scenario_name = :juniper

    Faraday::HotMock.enable!
    Faraday::HotMock.vcr = new_scenario_name

    unmocked_request = DogPhotoService.new.conn.get "breed/pyrenees/images/random"

    assert File.exist?(Faraday::HotMock.scenario_dir.join(new_scenario_name.to_s, Faraday::HotMock::FILE_NAME))

    assert_includes(
      unmocked_request.headers.keys,
      Faraday::HotMock::HEADERS[:recorded],
      "Expected the response to include the 'x-hot-mock-recorded-at' header".black.on_red,
    )

    assert_includes(
      unmocked_request.headers.keys,
      Faraday::HotMock::HEADERS[:mocked],
      "Expected the response to include the 'x-hot-mocked' header".black.on_red,
    )

    assert_equal(
      new_scenario_name,
      Faraday::HotMock.scenario, "Expected the current scenario to remain unchanged".black.on_red
    )
  end

  test "vcr mode as boolean records a mock into default file" do
    Faraday::HotMock.enable!
    Faraday::HotMock.vcr = true

    unmocked_request = DogPhotoService.new.conn.get "breed/pyrenees/images/random"

    assert_not Dir.exist?(Faraday::HotMock.scenario_dir)

    assert_includes(
      unmocked_request.headers.keys,
      Faraday::HotMock::HEADERS[:recorded],
      "Expected the response to include the '#{Faraday::HotMock::HEADERS[:recorded]}' header".black.on_red,
    )

    assert_includes(
      unmocked_request.headers.keys,
      Faraday::HotMock::HEADERS[:mocked],
      "Expected the response to include the '#{Faraday::HotMock::HEADERS[:mocked]}' header".black.on_red,
    )
  end
end
