# encoding: UTF-8

$LOAD_PATH << File.expand_path("../lib", __FILE__)

require "simple_scripting/version"

Gem::Specification.new do |s|
  s.name        = "simple_scripting"
  s.version     = SimpleScripting::VERSION
  s.platform    = Gem::Platform::RUBY
  s.required_ruby_version = '>= 2.3.0'
  s.authors     = ["Saverio Miroddi"]
  s.date        = "2018-07-26"
  s.email       = ["saverio.pub2@gmail.com"]
  s.homepage    = "https://github.com/saveriomiroddi/simple_scripting"
  s.summary     = "Library for simplifying some typical scripting functionalities."
  s.description = "Simplifies options parsing and configuration loading."
  s.license     = "GPL-3.0"

  s.add_runtime_dependency     "parseconfig", "~> 1.0"

  s.add_development_dependency "rake",        "~> 12.0"
  s.add_development_dependency "rspec",       "~> 3.6"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.executables   = []
  s.require_paths = ["lib"]
end
