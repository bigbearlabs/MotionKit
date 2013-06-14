# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'rubygems'
require 'motion/project'
require 'motion-cocoapods'
require 'bundler'
Bundler.require
require 'motion-hockeyrink'
require 'bubble-wrap'
# require 'motion-pixate'
require 'ib'
require 'motion-live'


Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'BBLMotionKit'
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
