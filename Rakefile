# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project/template/osx'

require 'rubygems'
require 'bundler'
Bundler.require

# motion-require
# require 'motion-require'
# Motion::Require.all


Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'webbuddy-motion'

  app.frameworks << 'WebKit'
  app.frameworks << 'Carbon'
  app.frameworks << 'CoreServices'
  app.frameworks << 'LaunchServices'
  app.frameworks << 'ExceptionHandling'

  app.vendor_project('vendor/NSFileManager_DirectoryLocations', :static)
  app.vendor_project('vendor/DDHotKeyCenter', :static)

  app.delegate_class = "WebBuddyAppDelegate"

  # app.files_dependencies 'app/legacy/window_controllers.rb' => 'app/legacy/browser_window_controller.rb'
end


# Track and specify files and their mutual dependencies within the :motion Bundler group
# group :motion do
#    gem 'slot_machine'
# end

MotionBundler.setup do |app|
  app.require "cgi"
end
