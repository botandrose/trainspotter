require_relative "lib/trainspotter/version"

Gem::Specification.new do |spec|
  spec.name        = "trainspotter"
  spec.version     = Trainspotter::VERSION
  spec.authors     = [ "Micah Geisel" ]
  spec.email       = [ "micah@botandrose.com" ]
  spec.homepage    = "https://github.com/botandrose/trainspotter"
  spec.summary     = "Zero-config web-based Rails log viewer with request grouping"
  spec.description = "A mountable Rails engine that provides a beautiful web interface for viewing and understanding your Rails logs. Groups requests with their SQL queries and view renders, with real-time updates."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.required_ruby_version = ">= 3.3.0"

  spec.add_dependency "rails", ">= 8.0"
  spec.add_dependency "sqlite3"
  spec.add_dependency "prism"
  spec.add_dependency "concurrent-ruby"
end
