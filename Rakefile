# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")

require 'motion/project/template/ios'

require 'rubygems'
require 'bundler'
Bundler.require


require 'motion-kit'

# motion-require.
Motion::Require.all

Motion::Project::App.setup do |app|
  app.deployment_target = "6.0"

  # Use `rake config' to see complete project settings.
  app.name = 'MotionKit'
  app.identifier = 'com.bigbearlabs.MotionKit.adhoc'
  app.device_family = [:iphone, :ipad]

  app.pods do
    pod 'HockeySDK'
    pod 'CocoaLumberjack'
  end

  # motion-hockeyrink
  app.hockeyapp.api_token = "575af155f66340e1a6a2c974f889c9c4"
  app.hockeyapp.app_id = "7a4f593356d12375b19d9ed86b285d79"
  app.hockeyapp.status = "allow" 


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
  # app.require "cgi/core"
  # app.require "cgi/cookie"
  # app.require "cgi/util"
  # app.require "cgi/html"
end




desc 'increment version and upload to hockeyapp.'
task :'deploy:h' => [:hockeyapp, :'version:increment_build' ]


desc 'release.'
task :release do
  sh %(
    rake archive:distribution mode=release version:increment_build tag
    open http://itunesconnect.apple.com
    open -a 'application loader'
  )
end



desc 'increment build'
task :'version:increment_build' do
  rakefile = 'Rakefile'

  bump = -> {
    EXPR_BUILD_NUMBER = /app\.version.*"(\d+)"/

    content = File.read(rakefile)
    content_to = content.each_line.map { |line| 
      if line =~ EXPR_BUILD_NUMBER
        version = $1
        new_version = ($1.to_i + 1).to_s
        puts "incrementing #{version} to #{new_version}"
        line.gsub version, new_version
      else
        line
      end
    }

    File.open(rakefile, "w") { |file| 
      file.puts content_to
    }

  }

  bump.call

  sh "git ci Rakefile -m 'incremented build number.'"
end

desc 'tag'
task :tag do
  sh %(
    git tag #{Time.new.utc.to_s.gsub(' ', '_').gsub(':', '_')}
  )
end

