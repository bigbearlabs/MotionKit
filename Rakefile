# -*- coding: utf-8 -*-

build_path = 'build/MacOSX-10.8-Release'
deploy_path = "#{ENV['HOME']}/Google Drive/bigbearlabs/webbuddy-preview"
version_number = "1.2.0"
build_number = `cat build.VERSION`.strip
# version_number = "#{version_number}-#{build_number}"  # DEV


$:.unshift("/Library/RubyMotion/lib")
require 'motion/project/template/osx'

require 'rubygems'
require 'bundler'
Bundler.require

# motion-require
require 'motion-require'
Motion::Require.all

# rakefile's deps
require 'fileutils'

Motion::Project::App.setup do |app|

  # cocoapods deps
  app.pods do
    # pod 'HockeySDK'
    pod 'CocoaLumberjack'
    pod 'CocoaHTTPServer', '~> 2.3'
    pod 'RoutingHTTPServer', '~> 1.0.0'
    pod 'MASPreferences', '~> 1.1'
    pod 'WebViewJavascriptBridge', '~> 4.1.0'
  end

  # frameworks
  app.frameworks += %w( WebKit Carbon ExceptionHandling )


  # dev-only
  app.development do
    version_number = "1.1.9-#{build_number}"
    app.files += Dir.glob('sketch/**/*.rb') 
  end


  # vendor projects
  # app.vendor_project('vendor/PEFramework', :xcode)
  app.vendor_project('vendor/misc', :static)
  app.vendor_project('vendor/NSFileManager-DirectoryLocations', :static)
  app.vendor_project('vendor/DDHotKeyCenter', :static)
  # FIXME need to copy resource.


  # Use `rake config' to see complete project settings.
  app.name = 'WebBuddy'
  app.identifier = "com.bigbearlabs.WebBuddy"
  app.icon = "icon.icns"
  app.copyright =  "Copyright (c) 2013 Big Bear Labs. All Right Reserved."
  app.version = build_number
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

  app.info_plist['NSServices'] = [
    {
      'NSKeyEquivalent' =>  {
          'default' =>  ">"
      },
      'NSMenuItem' =>  {
          'default' =>  "Send to WebBuddy"
      },
      'NSMessage' =>  "handle_service",
      'NSPortName' =>  "${PRODUCT_NAME}",
      'NSRequiredContext' =>  {
          'NSServiceCategory' =>  'Browsing'
      },
      'NSSendTypes' =>  [
          "public.utf8-plain-text"
          # TODO elaborate use case for non-text and add types, funnel into marketing.
      ],
    },
  ]


  ## files

  app.delegate_class = "WebBuddyAppDelegate"

  app.files_dependencies 'app/legacy/window_controllers.rb' => 'app/legacy/browser_window_controller.rb'
    # 'app/legacy/WebBuddyAppDelegate.rb' => 'app/filtering.rb',
    # 'app/filtering.rb' => 'app/plugin.rb',
    # 'app/aa_plugin.rb' => "#{`pwd`.strip}/bblmotionkit/lib/bblmotionkit/core/delegating.rb"

  # archive:distribution fails with i386 arch - just build for x86_64
  app.archs['MacOSX'] = ['x86_64']
  app.deployment_target = '10.8'

  app.codesign_certificate = '3rd Party Mac Developer Application: Sang-Heum Park (58VVS9JDMX)'

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
    sh 'cd ../webbuddy-modules; rake'
  end

  desc "copy resources"
  task :cprsc => [] do
    FileUtils.mkdir_p 'resources/plugin'
    FileUtils.cp_r Dir.glob('../webbuddy-modules/dist/.'), 'resources/plugin', verbose:true
  end
end


namespace :release do
  desc "zip up the .app and rsync to #{deploy_path}"
  task :zip do
    sh %Q(
      cd #{build_path}
      rm *.zip
      zip -r webbuddy-#{version_number}.zip WebBuddy.app
      rsync -avvv *.zip "#{deploy_path}/"
    )
  end

  desc "increment build number"
  task :increment do
    v = Versionomy.parse build_number
    new_version = v.bump(:major).to_s
    build_number = new_version
    `echo #{build_number} > build.VERSION`
    puts "build_number incremented to #{build_number}"
  end

  desc "commit all version files"
  task :commit_version do
    sh %( git commit '*.VERSION' -m "version to #{version_number} / #{build_number}"; git push )
  end

  # TODO revert version

  desc "archive, zip, rsync, version, release"
  task :all => [ :increment, :'archive:distribution', :zip, :commit_version ]
end
