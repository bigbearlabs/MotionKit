# -*- coding: utf-8 -*-

$:.unshift("/Library/RubyMotion/lib")
# $:.unshift("/Library/RubyMotion2.28/lib")


desc "archive, zip, rsync, version, release"
task :release => [ :'plugins:all', :fix_perms, :'release:increment', :'archive:distribution', :'release:zip', :'release:commit_version' ]


build_path = 'build/MacOSX-10.8-Release'
deploy_path = "#{ENV['HOME']}/Google Drive/bigbearlabs/webbuddy-preview"
version_number = "2.0.0"
build_number = `cat build.VERSION`.strip


require 'motion/project/template/osx'

require 'rubygems'
require 'bundler'
Bundler.require

# motion-require
Motion::Require.all

# rakefile's deps
require 'fileutils'


desc "Run the test/spec suite for plain ruby (**/ruby/**.rb)"
task :'spec:r' do
  App.config_without_setup.spec_mode = false
  Rake::Task["run"].invoke
end


Motion::Project::App.setup do |app|

  # cocoapods deps
  app.pods do
    # pod 'HockeySDK'
    pod 'CocoaLumberjack'
    pod 'CocoaHTTPServer', '~> 2.3'
    pod 'RoutingHTTPServer', '~> 1.0.0'
    pod 'MASPreferences', '~> 1.1'
    pod 'WebViewJavascriptBridge', '~> 4.1.0'
    pod 'StandardPaths'
  end

  # frameworks
  app.frameworks += %w( WebKit Carbon ExceptionHandling CoreData )


  # dev-only
  # FIXME this bleeds into release builds - fix or work around.
  app.development do
    # version_number = "#{version_number}-#{build_number}"
    app.files += Dir.glob('sketch/**/*.rb') 
  end

  # vendor projects
  # app.vendor_project('vendor/PEFramework', :xcode)
  app.vendor_project('vendor/misc', :static)
  app.vendor_project('vendor/DDHotKeyCenter', :static)
  # FIXME need to copy resource.

  app.resources_dirs += [
    'etc/ext-resources',
    'etc/static'
  ]

  # Use `rake config' to see complete project settings.
  app.name = 'WebBuddy'
  app.identifier = "com.bigbearlabs.WebBuddy"
  app.icon = "icon.icns"
  app.copyright =  "Copyright (c) 2014 Big Bear Labs. All Right Reserved."
  app.version = build_number
  app.short_version = version_number

  # agent mode - no dock icon
  app.info_plist['LSUIElement'] = true

  # services
  app.info_plist['NSServices'] = [
    {
      'NSKeyEquivalent' =>  {
          'default' =>  "\""
      },
      'NSMenuItem' =>  {
          'default' =>  "WebBuddy: Search"
      },
      'NSMessage' =>  "handle_service",
      'NSPortName' =>  "#{app.name}",
      'NSRequiredContext' =>  {
          'NSServiceCategory' =>  'Browsing'
      },
      'NSSendTypes' =>  [
          "public.utf8-plain-text"
          # TODO elaborate use case for non-text and add types, funnel into marketing.
      ],
    },
  ]

  # url schemes
  app.info_plist['CFBundleURLTypes'] = [
    { 'CFBundleURLName' => 'Web site URL',
      'CFBundleURLSchemes' => ['http', 'https'] },
    { 'CFBundleURLName' => 'Local file URL',
      'CFBundleURLSchemes' => ['file'] }
  ]

  # document types
  app.info_plist['CFBundleDocumentTypes'] = [
    {
      CFBundleTypeExtensions: [
        'css',
      ],
      CFBundleTypeIconFile: 'document.icns',
      CFBundleTypeMIMETypes: [
        'text/css',
      ],
      CFBundleTypeName: 'CSS style sheet',
      CFBundleTypeRole: 'Viewer',
      NSDocumentClass: 'BrowserDocument'
    },
    {
      CFBundleTypeExtensions: [
        'pdf',
      ],
      CFBundleTypeIconFile: 'document.icns',
      CFBundleTypeMIMETypes: [
        'application/pdf',
      ],
      CFBundleTypeName: 'PDF document',
      CFBundleTypeRole: 'Viewer',
      NSDocumentClass: 'BrowserDocument'
    },
    {
      CFBundleTypeExtensions: [
        'webbookmark',
      ],
      CFBundleTypeIconFile: 'document.icns',
      CFBundleTypeName: 'Safari bookmark',
      CFBundleTypeRole: 'Viewer',
      NSDocumentClass: 'BrowserDocument'
    },
    {
      CFBundleTypeExtensions: [
        'webhistory',
      ],
      CFBundleTypeIconFile: 'document.icns',
      CFBundleTypeName: 'Safari history item',
      CFBundleTypeRole: 'Viewer',
      NSDocumentClass: 'BrowserDocument'
    },
    {
      CFBundleTypeExtensions: [
        'webloc',
      ],
      CFBundleTypeIconFile: 'document.icns',
      CFBundleTypeName: 'Web internet location',
      CFBundleTypeOSTypes: [
        'ilht',
      ], 
      CFBundleTypeRole: 'Viewer',
      NSDocumentClass: 'BrowserDocument'
    },
    {
      CFBundleTypeExtensions: [
        'html',
        'htm',
        'shtml',
        'jhtml',
      ],
      CFBundleTypeIconFile: 'document.icns',
      CFBundleTypeMIMETypes: [
        'text/html',
      ],
      CFBundleTypeName: 'HTML document',
      CFBundleTypeOSTypes: [
        'HTML',
      ],
      CFBundleTypeRole: 'Viewer',
      NSDocumentClass: 'BrowserDocument'
    },
    {
      CFBundleTypeExtensions: [
        'js',
      ],
      CFBundleTypeIconFile: 'document.icns',
      CFBundleTypeMIMETypes: [
        'application/x-javascript',
      ],
      CFBundleTypeName: 'JavaScript script',
      CFBundleTypeRole: 'Viewer',
      NSDocumentClass: 'BrowserDocument'
    },
    {
      CFBundleTypeExtensions: [
        'url',
      ],
      CFBundleTypeIconFile: 'document.icns',
      CFBundleTypeName: 'Web site location',
      CFBundleTypeOSTypes: [
        'LINK',
      ],
      CFBundleTypeRole: 'Viewer',
      LSIsAppleDefaultForType: true,
      NSDocumentClass: 'BrowserDocument'
    },
    {
      CFBundleTypeExtensions: [
        'ico',
      ],
      CFBundleTypeIconFile: 'document.icns',
      CFBundleTypeMIMETypes: [
        'image/x-icon',
      ],
      CFBundleTypeName: 'Windows icon image',
      CFBundleTypeOSTypes: [
        'ICO',
      ],
      CFBundleTypeRole: 'Viewer',
      NSDocumentClass: 'BrowserDocument'
    },
    {
      CFBundleTypeExtensions: [
        'xhtml',
        'xht',
        'xhtm',
        'xht',
      ],
      CFBundleTypeIconFile: 'document.icns',
      CFBundleTypeMIMETypes: [
        'application/xhtml+xml',
      ],
      CFBundleTypeName: 'XHTML document',
      CFBundleTypeRole: 'Viewer',
      NSDocumentClass: 'BrowserDocument'
    },
    {
      CFBundleTypeExtensions: [
        'xml',
        'xbl',
        'xsl',
        'xslt',
      ],
      CFBundleTypeIconFile: 'document.icns',
      CFBundleTypeMIMETypes: [
        'application/xml',
      'text/xml',
      ],
      CFBundleTypeName: 'XML document',
      CFBundleTypeRole: 'Viewer',
      NSDocumentClass: 'BrowserDocument'
    },
    {
      CFBundleTypeExtensions: [
        'svg',
      ],
      CFBundleTypeIconFile: 'document.icns',
      CFBundleTypeMIMETypes: [
        'image/svg+xml',
      ],
      CFBundleTypeName: 'SVG document',
      CFBundleTypeRole: 'Viewer',
      NSDocumentClass: 'BrowserDocument'
    }
  ]

  ## files

  app.info_plist['NSMainNibFile'] = 'MainMenu'
  
  app.delegate_class = "WebBuddyAppDelegate"

  # archive:distribution fails with i386 arch - just build for x86_64
  app.archs['MacOSX'] = ['x86_64']
  app.deployment_target = '10.8'

  app.codesign_certificate = '3rd Party Mac Developer Application: Sang-Heum Park (58VVS9JDMX)'

  app.entitlements['com.apple.security.app-sandbox'] = true
  app.entitlements['com.apple.security.files.downloads.read-write'] = true
  app.entitlements['com.apple.security.files.user-selected.read-write'] = true
  app.entitlements['com.apple.security.network.client'] = true
  app.entitlements['com.apple.security.network.server'] = true
  app.entitlements['com.apple.security.print'] = true

end


# Track and specify files and their mutual dependencies within the :motion Bundler group
MotionBundler.setup do |app|
  # app.require "cgi"
  # app.require 'addressable/uri'

  app.require 'ostruct'  # required for aasm
end


desc "loop build"
task :loop do
  sh %(
    while [ 0 ]; do
      rake
    done
  )
end


namespace :vendor do
  desc "copy resources"
  task :cprsc => [] do
    # copy over xibs from vendor dir, following symlinks
    FileUtils.cp_r Dir.glob('vendor/**{,/*/**}/*.xib'), 'resources', verbose:true
  end
end



namespace :plugins do
  desc "all plugins tasks"
  task :all => [ :build, :hotdeploy ]

  desc "build and remove stubs"
  task :build => [] do
    sh '
      cd ../webbuddy-plugins
      rake release
    '

    system 'rm -r ../webbuddy-plugins/build/data'
  end

  desc "deploy plugins to app support"
  task :hotdeploy do
    sh %(
      rsync -avv --delete ../webbuddy-plugins/build/* ~/"Library/Application Support/WebBuddy/docroot/plugins/"  
    )
  end
end


namespace :release do
  desc "zip up the .app and rsync to #{deploy_path}"
  task :zip do
    system %Q(
      cd #{build_path}
      rm *.tgz
    )
    sh %Q(
      cd #{build_path}
      tar -czvf webbuddy-#{version_number}-#{build_number}.tgz WebBuddy.app
    )
    sh %Q(
      rsync -avvv #{build_path}/*.tgz "#{deploy_path}/"
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
    sh %(
      git commit '*.VERSION' -m "version to #{version_number} / #{build_number}"; git push 
      git tag "#{Time.new.utc.to_s.gsub(' ', '_').gsub(':', '_')}"
      echo "add version at: https://rink.hockeyapp.net/manage/apps/41321/app_versions"
    )
  end

  # TODO revert version when necessary


  desc 'increment version and upload to hockeyapp.'
  task :'h' => [:all, :hockeyapp ]

  desc 'release loop'
  task :loop do
    sh %(
      while [ 0 ]; do
        git pull
        (cd ../webbuddy-plugins; git pull)
        rake release:all
    
        echo "### sleeping..."
        sleep 36000
      done
    )
  end

  desc 'clean all'
  task :'clean:all' do
    sh %(
      (cd ../webbudy-plugins; rake clean)
      rake clean
    )
  end

end

desc "fix perms"
task :fix_perms do
  sh %Q(
    chmod -RL a+r etc/static/
  )
end



desc 'clean-env'
task :'clean:env' do
  sh %(
    rm -rf ~/Library/Preferences/com.bigbearlabs.WebBuddy.plist  # prefs
    defaults delete com.bigbearlabs.WebBuddy  # 10.9 prefs
    rm -rf ~/Library/"Application Support"/*WebBuddy*  # non-sandboxed prefs
    rm -rf ~/Library/Containers/com.bigbearlabs.WebBuddy  # sandboxed prefs
  )
end


desc 'src'
task :src do
  sh %(open -a SourceTree .)
end
