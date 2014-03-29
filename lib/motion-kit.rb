# unless defined?(Motion::Project::Config)
#   raise "This file must be required within a RubyMotion project Rakefile."
# end

if defined? Motion
  Motion::Project::App.setup do |app|

    # explicitly require external deps so bundler clients can relax.
    require 'ib'
    require 'ib/outlets'
    require 'bubble-wrap'
    require 'bubble-wrap/core'

    # BubbleWrap.require 'lib/ib/**/*.rb'

    # Dir.glob(File.join(File.dirname(__FILE__), 'lib/ib/**/*.rb')).each do |file|
    #   app.files.unshift file
    # end

    other_platforms = 
      case Motion::Project::App.template == :osx
      when true
        [ 'ios' ]
      else
        [ 'osx' ]
      end

    Dir.glob(File.join(File.dirname(__FILE__), 'motion-kit/**/*.rb')).each do |file|
      # app.files.unshift(file)
      # add to app.files only if no path segment is named as another platform.
      app.files.unshift(file) if (file.split('/') & other_platforms).empty?
    end

    # TODO exclude 

    # TODO frameworks, vendor projects
  end
end
