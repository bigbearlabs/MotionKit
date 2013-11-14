# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project/template/osx'

require 'rubygems'
require 'bundler'
Bundler.require

# motion-require
Motion::Require.all

Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'webbuddy-motion'

  app.frameworks << 'WebKit'
  # app.embedded_frameworks << '../MyFramework.framework'

  # app.files_dependencies 'app/legacy/NSViewController_additions.rb' => 'app/pemacrubyinfra/KVOMixin.rb'
end


# Track and specify files and their mutual dependencies within the :motion Bundler group
# group :motion do
#    gem 'slot_machine'
# end

MotionBundler.setup do |app|
  app.require "cgi"

  # app.require 'logger'

  # CocoaHelper
  # app.require 'yaml'
  # app.require 'net/http'
end
