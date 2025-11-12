# Faraday::HotMock

When using Faraday to develop an API integration, it can be challenging to simulate errors from the API if they don't provide a mechanism for doing so.

This adapter attempts to make that simpler by parsing YAML files at runtime. If a match exists in any YAML file in the proper location, that response is returned. If no match exists, a real call is made.


## Usage

Create YAML files in `lib/faraday/mocks/#{Rails.env}` - the name of the files doesn't matter, and you can nest them in subdirectories.

This means that if you have a Staging environment, or a UAT environment along with a Demo and Development environment, you can mock each separately.

You can organize your per-environment mocks as you see fit - all in one file, or split between descriptive directories and file names.


## Installation

Add this line to your application's Gemfile:

```ruby
gem "faraday-hot_mock", git: "https://github.com/seanhogge/faraday-hot_mock"
```

And then execute:
```bash
$ bundle
```

Then, use this adapter in your middleware pipeline, making sure that it's last:

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
  faraday.adapter :hot_mock, fallback: :cool_community_adapter
end
```

Then add the switch: `tmp/mocking-#{Rails.env}.txt`. Just like Rails' own `tmp/caching-dev.txt` file, this will toggle HotMock on when present, and off when not present.

> NOTE: ⚠️ For caching, it's `tmp/caching-dev.txt`, but for mocking it's `tmp/mocking-development.txt`

Now, create the directory `lib/faraday/mocks/` and a subdirectory for each environment you want to hot mock. Within that directory, create whatever files and subdirectories you like.

Consider adding these directories to .gitignore unless you want mocks to be shared.

```yaml
# lib/faraday/mocks/development/vendor_name_mocks.yml
- url_pattern: vendername.com.*/endpoint
  method: POST
  status: 418
  headers:
    Content-Type: application/json
  body:
    error: I'm a teapot
```

Now, any POST request made to `vendorname.com/api/v1/endpoint` will return a mock 418 response with a JSON body. A GET to the same endpoint will make the actual call.

If you edit the file to be:

```yaml
# lib/faraday/mocks/development/vendor_name_mocks.yml
- url_pattern: vendername.com.*/endpoint
  method: POST
  status: 503
  headers:
    Content-Type: application/json
  body:
    error: Service Unavailable
```

then the next request made to `vendorname.com/api/v1/endpoint` will return a mock 503 response with a JSON body. No need to reload anything.

This lets you quickly simulate any type of response you need.

If you want to disable mocks, you can:

- Comment out individual entries
- Comment out entire files
- Rename the directory from "development" to "development-disabled" or anything that isn't a Rails environment name
- Delete the entry
- Delete the file(s)
- Delete the directory

If you'd rather keep the file(s) around, just delete `tmp/mocking-development.txt`. That will globally disable any mocked responses.


## Contributing

Fork, work, PR while following the [Code of Conduct](https://github.com/seanhogge/faraday-hot_mock/CODE_OF_CONDUCT.md)


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
