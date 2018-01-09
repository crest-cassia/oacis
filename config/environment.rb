# Load the Rails application.
require_relative 'application'

# user code ----------------
Dir.chdir(Rails.root) {
  begin
    APP_VERSION = `git describe --always` unless defined? APP_VERSION
  rescue
    APP_VERSION = ''
  end
}
Mime::Type.register "text/plain", :plt  # MIME type for gnuplot script file
# user code end ------------

# Initialize the Rails application.
Rails.application.initialize!
