class HostsController < ApplicationController
  # GET /hosts
  # GET /hosts.json
  def index
    @hosts = Host.asc(:position).all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @hosts }
    end
  end

  # GET /hosts/1
  # GET /hosts/1.json
  def show
    @host = Host.find(params[:id])
    if (@host.connected? rescue false)
      @status = @host.scheduler_status
    else
      flash.now[:alert] = "Failed to establish connection. Check host information."
      @status = @host.connection_error.inspect
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @host }
    end
  end

  # GET /hosts/new
  # GET /hosts/new.json
  def new
    @host = Host.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @host }
    end
  end

  # GET /hosts/1/edit
  def edit
    @host = Host.find(params[:id])
  end

  # POST /hosts
  # POST /hosts.json
  def create
    @host = Host.new(params[:host])

    respond_to do |format|
      if @host.save
        format.html { redirect_to @host, notice: 'Host was successfully created.' }
        format.json { render json: @host, status: :created, location: @host }
      else
        format.html { render action: "new" }
        format.json { render json: @host.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /hosts/1
  # PUT /hosts/1.json
  def update
    @host = Host.find(params[:id])

    respond_to do |format|
      if @host.update_attributes(params[:host])
        format.html { redirect_to @host, notice: 'Host was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @host.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /hosts/1
  # DELETE /hosts/1.json
  def destroy
    @host = Host.find(params[:id])

    respond_to do |format|
      if @host.destroy
        format.html { redirect_to hosts_url }
        format.json { head :no_content }
      else
        flash.now[:alert] = "Failed to destroy host. There are created or submitted runs."
        format.html {render action: "show" }
        format.json {render json: @host.errors, status: :undestroyable_entity }
      end
    end
  end

  def _sort
    params[:host].each_with_index do |host_id, index|
      Host.find(host_id).timeless.update_attribute(:position, index)
    end
    render nothing: true
  end
end
