class UsersController < ApplicationController
  before_filter :authenticate_user!

  def index
    @users = User.paginate(:page => params[:page], :per_page => 10)
  end

  def show
    @user = User.find(params[:id])
  end

end
