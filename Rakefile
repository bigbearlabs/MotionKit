# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project/template/osx'

require 'rubygems'
require 'bundler'
Bundler.require

# motion-require
require 'motion-require'
Motion::Require.all


Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'WebBuddy-motion'
  app.identifier = "com.bigbearlabs.WebBuddy-motion"

  app.version = "200"
  app.short_version = "1.1.9"

  app.info_plist['CFBundleURLTypes'] = [
    { 'CFBundleURLName' => 'Web site URL',
      'CFBundleURLSchemes' => ['http', 'https'] },
    { 'CFBundleURLName' => 'Local file URL',
      'CFBundleURLSchemes' => ['file'] }
  ]

  # TODO declare document types

  app.frameworks += %w( WebKit Carbon ExceptionHandling )

  app.vendor_project('vendor/NSFileManager_DirectoryLocations', :static)
  app.vendor_project('vendor/DDHotKeyCenter', :static)

  app.delegate_class = "WebBuddyAppDelegate"

  app.files_dependencies 'app/legacy/window_controllers.rb' => 'app/legacy/browser_window_controller.rb',
    'app/legacy/filtering.rb' => 'app/legacy/window_controllers.rb'
end

# Track and specify files and their mutual dependencies within the :motion Bundler group
MotionBundler.setup do |app|
  app.require "cgi"
  # app.require 'addressable/uri'
end
