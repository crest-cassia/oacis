class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :authenticate

  # CHANGE THE PASSWORD BEFORE YOU USE
  USERS = {}
  # USERS = {"admin" => "pass"}

  private
  def authenticate
    unless USERS.empty?
      authenticate_or_request_with_http_digest do |username|
        USERS[username]
      end
    else
      true
    end
  end
end
