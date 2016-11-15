require 'spec_helper'

RSpec.describe HostGroupsController do

  describe "GET show" do
    it "assigns the requested host_group as @hg" do
      hg = FactoryGirl.create(:host_group)
      get :show, {id: hg.to_param}
      expect( response ).to have_http_status(:success)
      expect( assigns(:hg) ).to eq(hg)
    end
  end

  describe "GET new" do
    it "assigns a new host_group as @hg" do
      get :new
      expect( response ).to have_http_status(:success)
      expect( assigns(:hg) ).to be_a_new(HostGroup)
    end
  end

  describe "POST create" do

    describe "with valid parameters" do
      let(:valid_attr) do
        h = FactoryGirl.create(:host)
        attributes = {name: 'HostGroupA', host_ids: [h.id] }
        {host_group: attributes}
      end

      it "creates a new HostGroup" do
        expect {
          post :create, valid_attr
        }.to change( HostGroup, :count ).by(1)
      end

      it "redirects to the created host" do
        post :create, valid_attr
        expect( response ).to redirect_to(HostGroup.asc(:created_at).last)
      end
    end
  end

  describe "GET edit" do
    it "assigns the requested host_group as @hg" do
      hg = FactoryGirl.create(:host_group)
      get :edit, {id: hg.to_param}
      expect( response ).to have_http_status(:success)
      expect( assigns(:hg) ).to eq hg
    end
  end

  describe "PUT update" do

    describe "with valid parameters" do
      before(:each) do
        @hg = FactoryGirl.create(:host_group)
      end

      it "updates the requested host" do
        put :update, {id: @hg.to_param, host_group: {name: 'NewName'}}
        expect( @hg.reload.name ).to eq 'NewName'
      end

      it "redirects to the HostGroup" do
        put :update, {id: @hg.to_param, host_group: {name: 'NewName'}}
        expect( response ).to redirect_to(@hg)
      end
    end
  end

  describe "DELETE destroy" do

    before(:each) do
      @hg = FactoryGirl.create(:host_group)
    end

    it "destroys the requested host" do
      expect {
        delete :destroy, {id: @hg.to_param}
      }.to change(HostGroup, :count).by(-1)
    end

    context "when created runs exist" do

      before(:each) do
        sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
        run = sim.parameter_sets.first.runs.first
        run.submitted_to = nil
        run.host_group = @hg
        run.save!
      end

      it "does not destroy the host_group" do
        expect {
          delete :destroy, {id: @hg.to_param}
        }.to_not change { HostGroup.count }
      end

      it "renders 'show' template" do
        delete :destroy, {id: @hg.to_param}
        expect(response).to render_template('show')
      end
    end
  end
end
