# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'motion-kit/version'

Gem::Specification.new do |gem|
  gem.name          = "motion-kit"
  gem.version       = MotionKit::VERSION
  gem.authors       = ["Andy Park"]
  gem.email         = ["andy@bigbearlabs.com"]
  gem.description   = %q{Rapid application development toolkit}
  gem.summary       = %q{motion-kit is a set of idiomatic API for app development abstracted above specitic target platforms such as iOS, Mac, Android or web. App suites must have presence in all of them, so we provide an abstraction for expressing unique functionality of your app. Adapters plug in to realise compatibility.[]}
  gem.homepage      = "http://github.com/bigbearlabs/MotionKit"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'motion-require'
  gem.add_dependency 'motion-bundler'
  gem.add_dependency 'ib'
  gem.add_dependency 'motion-logger'
  gem.add_dependency 'bubble-wrap'
  gem.add_dependency 'ProMotion'
  gem.add_dependency 'cocoapods-core'
  gem.add_dependency 'motion-cocoapods'
  gem.add_development_dependency 'rake'

end
