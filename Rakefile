# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'rubygems'
require 'motion/project/template/ios'
require 'motion-cocoapods'
require 'bundler'
Bundler.require
require 'motion-hockeyrink'
require 'bubble-wrap'
# require 'motion-pixate'
require 'ib'
require 'motion-live'


Motion::Project::App.setup do |app|
  app.pods do
    # pod 'FontReplacer'
    pod 'HockeySDK'
  end    

  # motion-hockeyrink
  app.hockeyapp do


    app.hockeyapp.api_token = "575af155f66340e1a6a2c974f889c9c4"
    app.hockeyapp.app_id = "7a4f593356d12375b19d9ed86b285d79"
    app.hockeyapp.status = "allow" 
  end


  # Use `rake config' to see complete project settings.
  app.name = 'BBLMotionKit'
  app.identifier = 'com.bigbearlabs.BBLMotionKit.adhoc'
  app.device_family = [:iphone, :ipad]

  app.files = app.files | Dir.glob(File.join(app.project_dir, 'app/lib/**/*.rb')) |
              Dir.glob(File.join(app.project_dir, 'app/**/*.rb'))

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
