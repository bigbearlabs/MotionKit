# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")

require 'motion/project/template/ios'

require 'rubygems'
require 'bundler'
Bundler.require


# motion-require.
Motion::Require.all


Motion::Project::App.setup do |app|
  app.deployment_target = "6.0"

  # Use `rake config' to see complete project settings.
  app.name = 'BBLMotionKit'
  app.identifier = 'com.bigbearlabs.BBLMotionKit.adhoc'
  app.device_family = [:iphone, :ipad]

  app.pods do
    # pod 'FontReplacer'
    pod 'HockeySDK'
    pod 'CocoaLumberjack'
  end

  # motion-hockeyrink
    app.hockeyapp.api_token = "575af155f66340e1a6a2c974f889c9c4"
    app.hockeyapp.app_id = "7a4f593356d12375b19d9ed86b285d79"
    app.hockeyapp.status = "allow" 



  # app.files == Dir.glob(File.join(app.project_dir, 'lib/bblmotionkit/ui/ios/platform_integration.rb')) | app.files 
  
  # app.files = app.files | Dir.glob(File.join(app.project_dir, 'app/lib/**/*.rb')) |
  #             Dir.glob(File.join(app.project_dir, 'app/**/*.rb'))
  #             # |
  #             # Dir.glob(File.join('ProMotion', 'lib/**/*.rb'))

  # work around 'unrecognised constants' for bubblewrap 
  bw_core_dependenents = app.files.select {|f| f.match(%r{/(uikit_ext.rb|browser.rb|platform.rb)}) }
  bw_core = app.files.select {|f| f.match('app.rb') }.first
  puts "setting up #{bw_core_dependenents} to depend on #{bw_core}"
  app.files_dependencies Hash[ * bw_core_dependenents.map { |dep| [ dep, bw_core ] }.flatten ]

  # work around ib
  # require 'ib/outlets'
  # app.files_dependencies 'app/_rm_dep_hack.rb' => "#{ENV["HOME"].strip}/lib/ib.rb"


  app.development do
    app.codesign_certificate = 'iPhone Developer: Sang-Heum Park (WKRGFK8SQY)'
    app.provisioning_profile "PE testing provisioning profile"
    
    app.entitlements['get-task-allow'] = true
    app.entitlements['keychain-access-groups'] = [
      app.seed_id + '.' + app.identifier
    ]
  end

end

# Track and specify files and their mutual dependencies within the :motion 
# Bundler group
MotionBundler.setup do |app|
  app.require "cgi/core"
  app.require "cgi/cookie"
  app.require "cgi/util"
  app.require "cgi/html"
end


# unfinished; find a good way to grab the build product path.
=begin
task :copy => 'target/' do
  sh 'rsync -ru web/ target'  # trailing slash is significant; target will be created
done
=end
