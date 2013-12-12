# -*- coding: utf-8 -*-

build_path = 'build/MacOSX-10.8-Release'
deploy_path = "#{ENV['HOME']}/Google Drive/bigbearlabs/webbuddy-preview"
build_number = 208
# version_number = "1.1.9-#{build_number}"  # DEV
version_number = "1.1.9"


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
  app.copyright =  "Copyright (c) 2013 Big Bear Labs. All Right Reserved."
  app.version = build_number.to_s
  app.short_version = version_number

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
  app.vendor_project('vendor/NSFileManager-DirectoryLocations', :static)
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
  app.deployment_target = '10.8'

  app.codesign_certificate = '3rd Party Mac Developer Application: Sang-Heum Park (58VVS9JDMX)'

  # app.release do
  #   app.entitlements['com.apple.security.app-sandbox'] = true
  #   app.entitlements['com.apple.security.files.downloads.read-write'] = true
  #   app.entitlements['com.apple.security.network.client'] = true
  #   app.entitlements['com.apple.security.print'] = true

  # end
  app.entitlements['com.apple.security.app-sandbox'] = true
  app.entitlements['com.apple.security.files.downloads.read-write'] = true
  app.entitlements['com.apple.security.network.client'] = true
  app.entitlements['com.apple.security.print'] = true

end

# Track and specify files and their mutual dependencies within the :motion Bundler group
MotionBundler.setup do |app|
  app.require "cgi"
  # app.require 'addressable/uri'
end

namespace :vendor do
  desc "copy resources"
  task :cprsc => [] do
    # copy over xibs from vendor dir, following symlinks
    FileUtils.cp_r Dir.glob('vendor/**{,/*/**}/*.xib'), 'resources', verbose:true
  end
end

namespace :modules do
  desc "build"
  task :build => [] do
    sh 'cd ../webbuddy-modules; ./build.sh'
  end

  desc "copy resources"
  task :cprsc => [] do
    FileUtils.cp_r Dir.glob('../webbuddy-modules/dist/.'), 'resources/plugin', verbose:true
  end
end

namespace :release do
  task :zip do
    sh %Q(
      cd #{build_path}
      rm *.zip
      zip -r webbuddy-#{version_number}.zip WebBuddy.app
      rsync -avvv *.zip "#{deploy_path}/"
    )
  end

  task :version do
    # increment number
  end

  task :commit_version do
    # commit & push version number

  end

  task :all => [:clean, :'archive:distribution', :'version', :release, :commit_version]
end