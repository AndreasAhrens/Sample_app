require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

require "safe_yaml"
require "cc/cli"
require "cc/yaml"

Dir.glob("spec/support/**/*.rb").each(&method(:load))

SafeYAML::OPTIONS[:default_mode] = :safe

ENV["FILESYSTEM_DIR"] = "."
