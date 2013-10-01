class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :authenticate

  # CHANGE THE PASSWORD
  USERS = {"admin" => "pass"}

  private
  def authenticate
    authenticate_or_request_with_http_digest do |username|
      USERS[username]
    end
  end
end
