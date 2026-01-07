source "https://rubygems.org"

gem "fastlane", "~> 2.219"
gem "cocoapods", "~> 1.14"  # Optional, only if using CocoaPods

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
