#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

# tentatively suppress warnings until all gems supports Ruby 2.4
$VERBOSE=nil if RUBY_VERSION =~ /^2\.4/

require File.expand_path('../config/application', __FILE__)
require 'ci/reporter/rake/rspec'
AcmProto::Application.load_tasks
