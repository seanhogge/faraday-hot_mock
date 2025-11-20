# Faraday::HotMock

When using Faraday with Rails to develop an API integration, it can be challenging to simulate errors from the API if they don't provide a mechanism for doing so.

This adapter attempts to make that simpler by parsing YAML files at runtime. If a match exists in any YAML file in the proper location, that response is returned. If no match exists, a real call is made.

_**This adapter is meant for Faraday usage in Rails, not for Faraday that's used in other frameworks or situations.**_

## Why Use Faraday::HotMock instead of VCR?

[VCR](https://github.com/vcr/vcr) focuses on keeping HTTP requests out of tests - Faraday::HotMock focuses on simulating API responses during development.

To use [VCR](https://github.com/vcr/vcr) in development would require wrapping code in [VCR](https://github.com/vcr/vcr) blocks, which must then be undone before deployment. Simple, but tedious and error-prone.

Faraday::HotMock requires no code changes to the application - it doesn't mock anything in production, even if you try. So while the HotMock adapter is "used", it just passes requests to the default or adapter or specified fallback.

[VCR](https://github.com/vcr/vcr) works with any HTTP library, Faraday::HotMock only works with Faraday. This is a critical limitation unless you use only or primarily Faraday.

You could, ostensibly, replace VCR with Faraday::HotMock in tests. [VCR](https://github.com/vcr/vcr) is battle-tested, well-written and widely used, so it's likely a better choice for testing. But the goal is to make Faraday::HotMock just as useful in all non-production environments.

## How It Works

When a request is made, Faraday::HotMock checks for the presence of a file named `tmp/mocking-#{Rails.env}.txt`. If that file exists, HotMock is enabled.

When HotMock is enabled, it looks for YAML files in `lib/faraday/mocks/#{Rails.env}`. Each YAML file can contain one or more mock definitions.

For the YAML files in `lib/faraday/mocks/#{Rails.env}`, the name of the files don't matter, and you can nest them in subdirectories.

This means that if you have a Staging environment, or a UAT environment along with a Demo and Development environment, you can mock each separately.

You can organize your per-environment mocks as you see fit - all in one file, or split between descriptive directories and file names.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "faraday-hot_mock"
```

And then execute:
```bash
$ bundle
```

## Usage

Add this adapter to your middleware pipeline, making sure that it's last:

```ruby
@conn = Faraday.new(url: "https://dog.ceo/api/") do |faraday|
  faraday.request :json
  faraday.response :json
  faraday.adapter :hot_mock
end
```

Optionally, specify a fallback adapter (`Faraday.default_adapter` is the default) - this is what will be used if a matching mock can't be found. It's unlikely you will ever need to specify the fallback.

```ruby
@conn = Faraday.new(url: "https://dog.ceo/api/") do |faraday|
  faraday.request :json
  faraday.response :json
  faraday.adapter :hot_mock, fallback: :cool_community_adapter # only useful if the default adapter isn't already :cool_community_adapter!
end
```

Then add the switch: `tmp/mocking-#{Rails.env}.txt` (or use the [convenience method](#convenience-methods)). Just like Rails' own `tmp/caching-dev.txt` file, this will toggle HotMock on when present, and off when not present.

> ⚠️ REMEMBER: For caching, it's `tmp/caching-dev.txt`, but for mocking it's `tmp/mocking-development.txt`

Now, create the directory `lib/faraday/mocks/` and a subdirectory for each environment you want to hot mock. Within that directory, create whatever files and subdirectories you like.

> ⚠️ REMEMBER: it's `lib/faraday/mocks`, not `app/lib/faraday/mocks`

### Git Ignore?

It can be useful to share mocks with others, or to ensure you don't ever lose them.

It can also be a terrible idea if your mocks are designed for your specific needs, and can cause noise in PRs and commits.

It's up to you and your team what makes sense.

In most cases, it makes sense to not check in the mocks for any environment, so in most cases you should add to your `.gitignore`:

```
# Ignore Faraday HotMocks except in test env
lib/faraday/mocks/**
```

If you're using scenarios, however, it's probably useful to check those in since they're only activated when a scenario is directly selected.

### Scenarios

You can use directories to conditionally group mocks. For example, you might want a "success" scenario and an "failure" scenario.

To do that, simply create the `/scenarios/success` and `/scenarios/failure` subdirectories within `lib/faraday/mocks/#{Rails.env}/`, and place the appropriate mock files in each, probably with the same endpoints but with different responses.

Then call `Faraday::HotMock.scenario = :success` or `Faraday::HotMock.scenario = :failure` to switch between them.

When a scenario is active, only mocks in that scenario directory will be considered. If no matching mock is found in that scenario, then the real request will be made.

To use the mocks not in the `scenarios` directory again, simply set `Faraday::HotMock.scenario = nil`.

### Testing

In tests, you can certainly use a mocking library of choice. In many cases, that might be easier. This is because Faraday::HotMock is built for quick iteration using runtime-loaded YAML files, which isn't needed in tests.

If instead you want to use Faraday::HotMock, you can create mocked responses by hand, or use `Faraday::HotMock.mock!` to define mocks in a very similar way to other mocking libraries (similar to `stub_request` in WebMock, for example).

The most basic setup would be:

- Call `Faraday::HotMock.enable!` in your test setup
- Call `Faraday::HotMock.disable!` in your test teardown
- In a given test/spec or in a method, call `Faraday::HotMock.mock!(method: [method], url_pattern: [url], status: [status code], headers: [headers hash], body: [body])` to define a mock for that test/spec.
- Remove the mock file in teardown by referencing `Faraday::HotMock.hot_mock_file` (via `File.delete` or `FileUtils.rm`) since you probably don't want them to persist between tests

If you use scenarios, then you can do a bit less:

- Call `Faraday::HotMock.enable!` in your test setup
- Call `Faraday::HotMock.disable!` in your test teardown
- Call `Faraday::HotMock.scenario = :your_scenario_name` in a given test/spec
- Call `Faraday::HotMock.scenario = nil` in your test teardown if using scenarios

Overall, this may be a bit more work but it has the advantage that you can use the same mocking mechanism in both development and testing, which can reduce surprises when moving code between the two.

Small bonus: if you use `Faraday::HotMock` everywhere, you can remove the dependency for whichever mocking library/libraries you were using before.

### Convenience Methods

You can enable or disable mocking programmatically with these methods:

```ruby
Faraday::HotMock.enable!   # creates tmp/mocking-#{Rails.env}.txt
Faraday::HotMock.disable!  # deletes tmp/mocking-#{Rails.env}.txt
Faraday::HotMock.toggle!  # creates tmp/mocking-#{Rails.env}.txt if missing, deletes if present
```

You can check if mocking is enabled with:

```ruby
Faraday::HotMock.enabled?  # returns true/false;
Faraday::HotMock.disabled?  # returns true/false;
```

You can check if a given url and method will match against a mock with:

```ruby
Faraday::HotMock.mocked?(method: 'GET', url: 'https://vendorname.com/api/v1/endpoint')  # returns matching mock or false
```

These methods have limited use, but can be helpful in scripting scenarios, or to skip tedious file creation and deletion.

### Defining Mocks

You can simply create a YAML file in `lib/faraday/mocks/#{Rails.env}/` with one or more mock definitions by hand:

```yaml
# lib/faraday/mocks/development/any_name_you_like.yml
- url_pattern: vendorname.com.*/endpoint
  method: POST
  status: 418
  headers:
    Content-Type: application/json
  body:
    error: I'm a teapot
```

Or you can do the same in the default mock file for the current environment: `lib/faraday/mocks/#{Rails.env}/hot_mocks.yml`.

Now, any POST request made to `vendorname.com/api/v1/endpoint` will return a mock 418 response with a JSON body. A GET to the same endpoint will make the actual call.

If you edit the file to be:

```yaml
# lib/faraday/mocks/development/any_name_you_like.yml
- url_pattern: vendorname.com.*/endpoint
  method: POST
  status: 503
  headers:
    Content-Type: application/json
  body:
    error: Service Unavailable
```

then the next request made to `vendorname.com/api/v1/endpoint` will return a mock 503 response with a JSON body. No need to reload anything.

If you want to add a mock from the Rails console, you can use `Faraday::HotMock.mock!(method: [method], url_pattern: [url_pattern], status: [status], headers: [headers], body: [body])`. This will add the mock to the default mock file for the current environment.

A mock can be recorded by calling `Faraday::HotMock.record(method: [method], url: [url])`. This will make the actual call and then store the response in the default mock file for the current environment: `lib/faraday/mocks/#{Rails.env}/hot_mocks.yml`.

If a mock already exists for that method and URL, no request will be made and `false` will be returned.

Use `Faraday::HotMock.record!` (with a bang) to force recording even if a mock already exists. This will remove the old matching mock and put the new one in its place.

> ⚠️ WARNING: Recording does not remove any mocks from custom files, only from the default `hot_mocks.yml` file. If there are duplicates between custom files and the default file, there is no guarantee which one will be used.

Once recorded, you can easily edit the mock file to change status codes, headers, or body content as needed.

If you need to know where the mock file is located, you can call `Faraday::HotMock.hot_mock_file`, which will return the full path to the default mock file for the current environment.

### REGEX and You(r Mocks)

When recording a mock, you must pass a full URL. However, when defining mocks in YAML files, you can use regular expressions for more flexible matching.

Remember that once recorded, the `url_pattern` can be adjusted.

### Disabling Mocks

If you want to disable mocks, you can:

- Comment out individual entries
- Comment out entire files
- Rename the directory from "development" to "development-disabled" or anything that isn't a Rails environment name
- Delete the entry
- Delete the file(s)
- Delete the directory
- Use the [convenience methods](#convenience-methods)

## Contributing

Fork, work, PR while following the [Code of Conduct](https://github.com/seanhogge/faraday-hot_mock/CODE_OF_CONDUCT.md)

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
