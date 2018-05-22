require 'rubygems'

module SpecHelper
  def at_temp_dir
    Dir.mktmpdir {|dir|
      Dir.chdir(dir) {
        yield
      }
    }
  end

  def capture_stdout_stderr
    previous_stdout, $stdout = $stdout, StringIO.new
    previous_stderr, $stderr = $stderr, StringIO.new
    yield
    [$stdout.string,$stderr.string]
  ensure
    $stdout = previous_stdout
    $stderr = previous_stderr
  end
end

ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

# redirect stdout and stderr
ProgressBar::Output.class_eval {  # suppress output of progress bar
  unless defined? org_init
    alias :org_init :initialize
    def initialize( options )
      opts = {output: File.open('/dev/null','w') }.merge(options)
      org_init(opts)
    end
  end
}

RSpec.configure do |config|
  config.infer_spec_type_from_file_location! # this line is added when updating rspec3
  config.include SpecHelper
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  # config.use_transactional_fixtures = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation

    root_dir = ResultDirectory.root
    FileUtils.rm_r(root_dir) if FileTest.directory?(root_dir)
    system('bundle exec rake db:mongoid:create_indexes RAILS_ENV=test')
  end
  config.after(:suite) do
    system('bundle exec rake db:mongoid:remove_indexes RAILS_ENV=test')
  end

  config.before(:each) do
    DatabaseCleaner.start
  end
  config.after(:each) do
    DatabaseCleaner.clean
  end

  config.after(:all) do
    root_dir = ResultDirectory.root
    FileUtils.rm_r(root_dir) if FileTest.directory?(root_dir)
  end
end
