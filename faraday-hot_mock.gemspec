require_relative "lib/faraday/hot_mock/version"

Gem::Specification.new do |spec|
  spec.name        = "faraday-hot_mock"
  spec.version     = Faraday::HotMock::VERSION
  spec.authors     = [ "Sean Hogge" ]
  spec.email       = [ "sean@seanhogge.com" ]
  spec.homepage    = "https://github.com/seanhogge/faraday-hot_mock"
  spec.summary     = "Faraday middleware for simple mocking of Faraday requests per environment."
  spec.description = "Faraday middleware for simple mocking of Faraday requests per environment by means of YAML files read at runtime."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/seanhogge/faraday-hot_mock"
  spec.metadata["changelog_uri"] = "https://github.com/seanhogge/faraday-hot_mock/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.required_ruby_version = ">= 3.2"

  spec.add_dependency "rails", ">= 7"
  spec.add_dependency "faraday", ">= 2", "< 3"

  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-byebug" # optional, adds step debugging
end
