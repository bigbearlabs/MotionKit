# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project/template/osx'

require 'rubygems'
require 'bundler'
Bundler.require


Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'webbuddy-motion'

  app.frameworks << 'WebKit'
  # app.embedded_frameworks << '../MyFramework.framework'
end


# Track and specify files and their mutual dependencies within the :motion 
# Bundler group
MotionBundler.setup do |app|
  app.require "cgi"
end
