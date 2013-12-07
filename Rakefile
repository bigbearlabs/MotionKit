# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project/template/osx'

require 'rubygems'
require 'bundler'
Bundler.require

# motion-require
require 'motion-require'
Motion::Require.all

# rakefiles deps
require 'fileutils'

Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'WebBuddy'
  app.identifier = "com.bigbearlabs.WebBuddy"
  app.icon = "icon.icns"

  app.version = "200"
  app.short_version = "1.1.9"

  app.info_plist['NSMainNibFile'] = 'MainMenu'
  
  app.info_plist['CFBundleURLTypes'] = [
    { 'CFBundleURLName' => 'Web site URL',
      'CFBundleURLSchemes' => ['http', 'https'] },
    { 'CFBundleURLName' => 'Local file URL',
      'CFBundleURLSchemes' => ['file'] }
  ]

  # TODO declare document types

  app.info_plist['LSUIElement'] = true


  app.frameworks += %w( WebKit Carbon ExceptionHandling )


  # app.vendor_project('vendor/PEFramework', :xcode)
  app.vendor_project('vendor/misc', :static)
  app.vendor_project('vendor/NSFileManager_DirectoryLocations', :static)
  app.vendor_project('vendor/DDHotKeyCenter', :static)
  # FIXME need to copy resource.

  app.delegate_class = "WebBuddyAppDelegate"

  app.files_dependencies 'app/legacy/window_controllers.rb' => 'app/legacy/browser_window_controller.rb'
    # 'app/filtering.rb' => 'app/legacy/window_controllers.rb'

  # cocoapods deps
  app.pods do
    # pod 'HockeySDK'
    pod 'CocoaLumberjack'
    pod 'CocoaHTTPServer', '~> 2.3'
    pod 'RoutingHTTPServer', '~> 1.0.0'
    pod 'MASPreferences', '~> 1.1'
  end


  # archive:distribution fails with i386 arch - just build for x86_64
  app.archs['MacOSX'] = ['x86_64']
end

# Track and specify files and their mutual dependencies within the :motion Bundler group
MotionBundler.setup do |app|
  app.require "cgi"
  # app.require 'addressable/uri'
end


desc "copy resources"
task :cprsc => [] do
  # copy over xibs from vendor dir, following symlinks
  FileUtils.cp_r Dir.glob('vendor/**{,/*/**}/*.xib'), 'resources', verbose:true
end
