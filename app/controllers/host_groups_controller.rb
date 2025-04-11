class HostGroupsController < ApplicationController

  def show
    unless HostGroup.where(id: params[:id]).exists?
      flash[:alert] = "HostGroup #{params[:id]} is not found"
      redirect_to hosts_path and return
    end
    @hg = HostGroup.find(params[:id])

    respond_to do |format|
      format.html
    end
  end

  def new
    @hg = HostGroup.new

    respond_to do |format|
      format.html
    end
  end

  def create
    @hg = HostGroup.new( permitted_host_group_params )

    respond_to do |format|
      if @hg.save
        format.html {
          redirect_to @hg, notice: 'HostGroup was successfully created.'
        }
      else
        format.html { render action: "new" }
      end
    end
  end

  def edit
    unless HostGroup.where(id: params[:id]).exists?
      flash[:alert] = "HostGroup #{params[:id]} is not found"
      redirect_to hosts_path and return
    end
    @hg = HostGroup.find(params[:id])

    respond_to do |format|
      format.html
    end
  end

  def update
    @hg = HostGroup.find(params[:id])

    respond_to do |format|
      if @hg.update_attributes(permitted_host_group_params)
        format.html {
          redirect_to @hg, notice: 'HostGroup was successfully updated.'
        }
      else
        format.html { render action: "edit" }
      end
    end
  end

  def destroy
    @hg = HostGroup.find(params[:id])

    respond_to do |format|
      if @hg.destroy
        format.html { redirect_to hosts_url }
      else
        flash.now[:alert] = "Cannot destroy the HostGroup."
        format.html {render action: "show" }
      end
    end
  end

  private
  def permitted_host_group_params
    params.require(:host_group).permit(:name, host_ids: [])
  end
end
