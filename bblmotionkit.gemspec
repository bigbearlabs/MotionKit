# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bblmotionkit/version'

Gem::Specification.new do |gem|
  gem.name          = "bblmotionkit"
  gem.version       = BblMotionKit::VERSION
  gem.authors       = ["Andy Park"]
  gem.email         = ["sohocoke@gmail.com"]
  gem.description   = %q{kit for BBL RubyMotion apps}
  gem.summary       = %q{kit for BBL RubyMotion apps}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'bubble-wrap'

end
