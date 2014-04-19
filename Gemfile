source 'https://rubygems.org'

# bblmotionkit is a library project with its own git origin.
gem 'bblmotionkit', :path => './bblmotionkit'

# unfortunately, the dependencies of the lib project don't get properly 'exported' for rubymotion to use. so they need to be re-listed here for the compilation to work.

gem 'motion-bundler'
gem 'motion-require'
gem 'ib'
gem 'motion-cocoapods'
gem 'cocoapods-core'
gem 'versionomy'

gem 'motion-logger'
gem 'bubble-wrap'
gem 'motion-yaml'
gem "motion_data_wrapper"

gem 'motion-benchmark'
# gem 'motion-cocoapods',  "~> 1.3.0.rc1"
# gem 'cocoapods-core'
# gem "ProMotion", "~> 0.5.0"
# gem 'sugarcube'
# gem 'motion-pixate'
# gem 'motion-xray'
# gem 'motion-hockeyrink'


gem "slim"

group :motion do
  # gem 'idn'
  # gem 'addressable'
  # gem 'rack'

  gem "aasm"
end

group :development do
  gem 'guard'
  gem 'guard-shell'
  gem 'compass'  # work around grunt:compass freaking out on webbuddy-modules.
end

