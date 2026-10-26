require_relative "lib/deacon/rails/version"

Gem::Specification.new do |spec|
  spec.name = "deacon-rails"
  spec.version = Deacon::Rails::VERSION
  spec.authors = ["Deacon"]
  spec.email = ["hello@heydeacon.com"]

  spec.summary = "Adds Deacon, an AI support chat that answers from your docs, to every page of a Rails app."
  spec.description = "A view helper, deacon_widget_tag, that puts the Deacon chat widget on every page of a Rails app from one line in the layout. Deacon is an AI support agent that answers questions from your own docs and content, and says when it doesn't know."
  spec.homepage = "https://heydeacon.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/heydeacon/deacon-rails",
    "bug_tracker_uri" => "https://github.com/heydeacon/deacon-rails/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "actionview", ">= 8.0"
  spec.add_dependency "railties", ">= 8.0"
end
