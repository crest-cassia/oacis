class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :authenticate

  USERS = AcmProto::Application.config.user_config["basic_authentication"]

  private
  def authenticate
    if Rails.env.test? or USERS.blank?
      true
    else
      authenticate_or_request_with_http_digest do |username|
        USERS[username]
      end
    end
  end
end
