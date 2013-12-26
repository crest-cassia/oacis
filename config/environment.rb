# Load the rails application
require File.expand_path('../application', __FILE__)

Dir.chdir(Rails.root) {
  begin
    APP_VERSION = `git describe --always` unless defined? APP_VERSION
  rescue
    APP_VERSION = ''
  end
}
Mime::Type.register "text/plain", :plt  # MIME type for gnuplot script file

# Initialize the rails application
AcmProto::Application.initialize!
