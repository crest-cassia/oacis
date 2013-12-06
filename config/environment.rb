# Load the rails application
require File.expand_path('../application', __FILE__)

APP_VERSION = `git describe --always` unless defined? APP_VERSION
Mime::Type.register "text/plain", :plt  # MIME type for gnuplot script file

# Initialize the rails application
AcmProto::Application.initialize!
