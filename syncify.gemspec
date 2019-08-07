lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "syncify/version"

Gem::Specification.new do |spec|
  spec.name          = "syncify"
  spec.version       = Syncify::VERSION
  spec.authors       = ["Doug Hughes"]
  spec.email         = ["doug@doughughes.net"]

  spec.summary       = %q{Copies data between Rails environments}
  spec.description   = %q{You can use this gem to copy records and their specified associations from production (or other) environments to your local environment.}
  spec.homepage      = "http://github.com/dhughes/syncify"
  spec.license       = "MIT"

  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "http://github.com/dhughes/syncify"
  spec.metadata["changelog_uri"] = "http://github.com/dhughes/syncify"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "activerecord"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "factory_bot_rails"

  spec.add_runtime_dependency "active_interaction", "~> 3.0"
end
