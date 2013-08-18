# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project/template/osx'

require 'rubygems'
require 'bundler'
Bundler.require

# HACK unsure why bundler / gem-fronting file doesn't take care of this.
require 'bubble-wrap/core'

Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'webbuddy-motion'

  app.frameworks << 'WebKit'
  # app.embedded_frameworks << '../MyFramework.framework'
end
