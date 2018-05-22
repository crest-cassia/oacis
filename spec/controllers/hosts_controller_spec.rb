require 'spec_helper'

describe HostsController do

  # This should return the minimal set of attributes required to create a valid
  # Host. As you add validations to Host, be sure to
  # update the return value of this method accordingly.
  def valid_attributes
    {
      name: "localhost"
    }
  end

  describe "GET index" do
    it "assigns @hosts and @host_groups" do
      host = Host.create! valid_attributes
      hg = HostGroup.create!(name: "hg", hosts: [host])
      get :index, params: {}
      expect(assigns(:hosts)).to eq([host])
      expect(assigns(:host_groups)).to eq([hg])
    end

    it "@hosts are sorted by position" do
      hosts = FactoryBot.create_list(:host, 3)
      hosts.first.update_attribute(:position, 2)
      hosts.last.update_attribute(:position, 0)
      get :index, params: {}
      expect(assigns(:hosts).map(&:position)).to eq [0,1,2]
    end
  end

  describe "GET show" do
    it "assigns the requested host as @host" do
      host = Host.create! valid_attributes
      get :show, params: {id: host.to_param}
      expect(assigns(:host)).to eq(host)
    end
  end

  describe "GET _check_scheduler_status" do
    it "returns status of remote job-scheduler" do
      host = Host.create! valid_attributes
      expect_any_instance_of(Host).to receive(:scheduler_status).and_return("status")
      get :_check_scheduler_status, params: {id: host.to_param}
      expect(response).to be_success
      expect(response.body).to eq "status"
    end
  end

  describe "GET new" do
    it "assigns a new host as @host" do
      get :new, params: {}
      expect(assigns(:host)).to be_a_new(Host)
    end
  end

  describe "GET edit" do
    it "assigns the requested host as @host" do
      host = Host.create! valid_attributes
      get :edit, params: {id: host.to_param}
      expect(assigns(:host)).to eq(host)
    end
  end

  describe "POST create" do

    describe "with valid params" do

      it "creates a new Host" do
        expect {
          post :create, params: {host: valid_attributes}
        }.to change(Host, :count).by(1)
      end

      it "assigns a newly created host as @host" do
        post :create, params: {host: valid_attributes}
        expect(assigns(:host)).to be_a(Host)
        expect(assigns(:host)).to be_persisted
      end

      it "redirects to the created host" do
        post :create, params: {host: valid_attributes}
        expect(response).to redirect_to(Host.order_by(id: :asc).last)
      end

      context "with executable_simulators and executable_analyzers" do

        before(:each) do
          @sim = FactoryBot.create(:simulator, parameter_sets_count: 0, runs_count: 0, analyzers_count: 1)
          @valid_attributes_with_sim = valid_attributes.update(
            executable_simulator_ids: [@sim.id.to_s],
            executable_analyzer_ids: [@sim.analyzers.first.id.to_s]
          )
        end

        it "create a new Host" do
          post :create, params: {host: @valid_attributes_with_sim}
          host = assigns(:host)
          expect(host.executable_simulator_ids).to include(@sim.id)
          expect(host.executable_analyzer_ids).to include(@sim.analyzers.first.id)
        end
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved host as @host" do
        post :create, params: {host: {}}
        expect(assigns(:host)).to be_a_new(Host)
      end

      it "re-renders the 'new' template" do
        post :create, params: {host: {}}
        expect(response).to render_template("new")
      end
    end

    describe "with no permitted params" do

      it "creates a new Host but no permitted params are not saved" do
        invalid_host_params = valid_attributes.update(invalid: 1)
        expect {
          post :create, params: {host: invalid_host_params, invalid: 1}
        }.to change(Host, :count).by(1)
        host = assigns(:host)
        expect(host.try(:invalid)).not_to eq 1
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested host" do
        host = FactoryBot.create(:host)
        expect(host.reload.name).to_not eq('localhost')
        put :update, params: {id: host.to_param, host: {name: 'localhost'}}
        expect(host.reload.name).to eq('localhost')
      end

      it "assigns the requested host as @host" do
        host = Host.create! valid_attributes
        put :update, params: {id: host.to_param, host: valid_attributes}
        expect(assigns(:host)).to eq(host)
      end

      it "redirects to the host" do
        host = Host.create! valid_attributes
        put :update, params: {id: host.to_param, host: valid_attributes}
        expect(response).to redirect_to(host)
      end
    end

    describe "with invalid params" do
      it "assigns the host as @host" do
        host = Host.create! valid_attributes
        put :update, params: {id: host.to_param, host: {name: ''}}
        expect(assigns(:host)).to eq(host)
      end

      it "re-renders the 'edit' template" do
        host = Host.create! valid_attributes
        put :update, params: {id: host.to_param, host: {name: ''}}
        expect(response).to render_template("edit")
      end
    end

    describe "with no permitted params" do

      it "update the Host but no permitted params are not saved" do
        host = Host.create! valid_attributes
        invalid_host_params = valid_attributes.update(invalid: 1)
        post :update, params: {id: host.to_param, host: invalid_host_params, invalid: 1}
        h = assigns(:host)
        expect(h.try(:invalid)).not_to eq 1
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested host" do
      host = Host.create! valid_attributes
      expect {
        delete :destroy, params: {id: host.to_param}
      }.to change(Host, :count).by(-1)
    end

    it "redirects to the hosts list" do
      host = Host.create! valid_attributes
      delete :destroy, params: {id: host.to_param}
      expect(response).to redirect_to(hosts_url)
    end

    context "when submittable or submitted runs exist" do

      before(:each) do
        sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 1)
        run = sim.parameter_sets.first.runs.first
        @host = run.submitted_to
      end

      it "does not destroy the host" do
        expect {
          delete :destroy, params: {id: @host.to_param}
        }.to_not change { Host.count }
      end

      it "renders 'show' template" do
        delete :destroy, params: {id: @host.to_param}
        expect(response).to render_template('show')
      end
    end

    context "when a host_group whose unique host is itself exists" do

      it "does not destroy the host" do
        host = FactoryBot.create(:host)
        FactoryBot.create(:host_group) {|hg|
          hg.hosts = []
          hg.hosts.push host
        }

        expect {
          delete :destroy, params: {id: host.to_param}
        }.to_not change { Host.count }
      end
    end
  end

  describe "POST _sort" do

    before(:each) do
      FactoryBot.create_list(:host, 3)
    end

    it "updates position of the simulators" do
      hosts = Host.asc(:position).to_a
      expect {
        post :_sort, params: {host: hosts.reverse }
        expect(response).to be_success
      }.to change { hosts.first.reload.position }.from(0).to(2)
    end
  end
end
