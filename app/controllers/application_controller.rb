class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :authenticate

  # CHANGE THE PASSWORD BEFORE YOU USE
  USERS = {}
  # USERS = {"admin" => "pass"}

  private
  def authenticate
    if Rails.env.test? or USERS.empty?
      true
    else
      authenticate_or_request_with_http_digest do |username|
        USERS[username]
      end
    end
  end
end
