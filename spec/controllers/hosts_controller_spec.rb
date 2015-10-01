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
      expect(assigns(:hosts)).to eq([host])
    end

    it "@hosts are sorted by position" do
      hosts = FactoryGirl.create_list(:host, 3)
      hosts.first.update_attribute(:position, 2)
      hosts.last.update_attribute(:position, 0)
      get :index, {}, valid_session
      expect(assigns(:hosts).map(&:position)).to eq [0,1,2]
    end
  end

  describe "GET show" do
    it "assigns the requested host as @host" do
      host = Host.create! valid_attributes
      get :show, {id: host.to_param}, valid_session
      expect(assigns(:host)).to eq(host)
    end
  end

  describe "GET new" do
    it "assigns a new host as @host" do
      get :new, {}, valid_session
      expect(assigns(:host)).to be_a_new(Host)
    end
  end

  describe "GET edit" do
    it "assigns the requested host as @host" do
      host = Host.create! valid_attributes
      get :edit, {id: host.to_param}, valid_session
      expect(assigns(:host)).to eq(host)
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
        expect(assigns(:host)).to be_a(Host)
        expect(assigns(:host)).to be_persisted
      end

      it "redirects to the created host" do
        post :create, {host: valid_attributes}, valid_session
        expect(response).to redirect_to(Host.last)
      end

      context "with executable_simulators and executable_analyzers" do

        before(:each) do
          @sim = FactoryGirl.create(:simulator, parameter_sets_count: 0, runs_count: 0, analyzers_count: 1)
          @valid_attributes_with_sim = valid_attributes.update(
            executable_simulator_ids: [@sim.id.to_s],
            executable_analyzer_ids: [@sim.analyzers.first.id.to_s]
          )
        end

        it "create a new Host" do
          post :create, {host: @valid_attributes_with_sim}, valid_session
          host = assigns(:host)
          expect(host.executable_simulator_ids).to include(@sim.id)
          expect(host.executable_analyzer_ids).to include(@sim.analyzers.first.id)
        end
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved host as @host" do
        post :create, {host: {}}, valid_session
        expect(assigns(:host)).to be_a_new(Host)
      end

      it "re-renders the 'new' template" do
        post :create, {host: {}}, valid_session
        expect(response).to render_template("new")
      end
    end

    describe "with no permitted params" do

      it "creates a new Host but no permitted params are not saved" do
        invalid_host_params = valid_attributes.update(invalid: 1)
        expect {
          post :create, {host: invalid_host_params, invalid: 1}, valid_session
        }.to change(Host, :count).by(1)
        host = assigns(:host)
        expect(host.try(:invalid)).not_to eq 1
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested host" do
        host = Host.create! valid_attributes
        put :update, {id: host.to_param, host: {name: 'XYZ'}}, valid_session
        expect(host.reload.name).to eq('XYZ')
      end

      it "assigns the requested host as @host" do
        host = Host.create! valid_attributes
        put :update, {id: host.to_param, host: valid_attributes}, valid_session
        expect(assigns(:host)).to eq(host)
      end

      it "redirects to the host" do
        host = Host.create! valid_attributes
        put :update, {id: host.to_param, host: valid_attributes}, valid_session
        expect(response).to redirect_to(host)
      end
    end

    describe "with invalid params" do
      it "assigns the host as @host" do
        host = Host.create! valid_attributes
        put :update, {id: host.to_param, host: {name: ''}}, valid_session
        expect(assigns(:host)).to eq(host)
      end

      it "re-renders the 'edit' template" do
        host = Host.create! valid_attributes
        put :update, {id: host.to_param, host: {name: ''}}, valid_session
        expect(response).to render_template("edit")
      end
    end

    describe "with no permitted params" do

      it "update the Host but no permitted params are not saved" do
        host = Host.create! valid_attributes
        invalid_host_params = valid_attributes.update(invalid: 1)
        post :update, {id: host.to_param, host: invalid_host_params, invalid: 1}, valid_session
        h = assigns(:host)
        expect(h.try(:invalid)).not_to eq 1
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
      expect(response).to redirect_to(hosts_url)
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
        expect(response).to render_template('show')
      end
    end
  end

  describe "POST _sort" do

    before(:each) do
      FactoryGirl.create_list(:host, 3)
    end

    it "updates position of the simulators" do
      hosts = Host.asc(:position).to_a
      expect {
        post :_sort, {host: hosts.reverse }
        expect(response).to be_success
      }.to change { hosts.first.reload.position }.from(0).to(2)
    end
  end
end
