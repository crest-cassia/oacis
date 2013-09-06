require 'spec_helper'

describe HostsController do

  # This should return the minimal set of attributes required to create a valid
  # Host. As you add validations to Host, be sure to
  # update the return value of this method accordingly.
  def valid_attributes
    {
      name: "nameABC",
      hostname: "localhost",
      user: ENV['USER']
    }
  end

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # HostsController. Be sure to keep this updated too.
  def valid_session
    {}
  end

  describe "GET index" do
    it "assigns all hosts as @hosts" do
      host = Host.create! valid_attributes
      get :index, {}, valid_session
      assigns(:hosts).should eq([host])
    end
  end

  describe "GET show" do
    it "assigns the requested host as @host" do
      host = Host.create! valid_attributes
      get :show, {id: host.to_param}, valid_session
      assigns(:host).should eq(host)
    end
  end

  describe "GET new" do
    it "assigns a new host as @host" do
      get :new, {}, valid_session
      assigns(:host).should be_a_new(Host)
    end
  end

  describe "GET edit" do
    it "assigns the requested host as @host" do
      host = Host.create! valid_attributes
      get :edit, {id: host.to_param}, valid_session
      assigns(:host).should eq(host)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "creates a new Host" do
        expect {
          post :create, {host: valid_attributes}, valid_session
        }.to change(Host, :count).by(1)
      end

      it "assigns a newly created host as @host" do
        post :create, {host: valid_attributes}, valid_session
        assigns(:host).should be_a(Host)
        assigns(:host).should be_persisted
      end

      it "redirects to the created host" do
        post :create, {host: valid_attributes}, valid_session
        response.should redirect_to(Host.last)
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved host as @host" do
        post :create, {host: {}}, valid_session
        assigns(:host).should be_a_new(Host)
      end

      it "re-renders the 'new' template" do
        post :create, {host: {}}, valid_session
        response.should render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested host" do
        host = Host.create! valid_attributes
        put :update, {id: host.to_param, host: {name: 'XYZ'}}, valid_session
        host.reload.name.should eq('XYZ')
      end

      it "assigns the requested host as @host" do
        host = Host.create! valid_attributes
        put :update, {id: host.to_param, host: valid_attributes}, valid_session
        assigns(:host).should eq(host)
      end

      it "redirects to the host" do
        host = Host.create! valid_attributes
        put :update, {id: host.to_param, host: valid_attributes}, valid_session
        response.should redirect_to(host)
      end
    end

    describe "with invalid params" do
      it "assigns the host as @host" do
        host = Host.create! valid_attributes
        put :update, {id: host.to_param, host: {name: ''}}, valid_session
        assigns(:host).should eq(host)
      end

      it "re-renders the 'edit' template" do
        host = Host.create! valid_attributes
        put :update, {id: host.to_param, host: {name: ''}}, valid_session
        response.should render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested host" do
      host = Host.create! valid_attributes
      expect {
        delete :destroy, {id: host.to_param}, valid_session
      }.to change(Host, :count).by(-1)
    end

    it "redirects to the hosts list" do
      host = Host.create! valid_attributes
      delete :destroy, {id: host.to_param}, valid_session
      response.should redirect_to(hosts_url)
    end

    context "when submittable or submitted runs exist" do

      before(:each) do
        sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
        run = sim.parameter_sets.first.runs.first
        @host = run.submitted_to
      end

      it "does not destroy the host" do
        expect {
          delete :destroy, {id: @host.to_param}, valid_session
        }.to_not change { Host.count }
      end

      it "renders 'show' template" do
        delete :destroy, {id: @host.to_param}, valid_session
        response.should render_template('show')
      end
    end
  end
end
