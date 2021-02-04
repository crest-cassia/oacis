require 'spec_helper'

describe OacisSettingsController do
  describe "GET edit" do
    it "assigns the requested host as @oacis_setting" do
      oacis_setting = FactoryBot.create(:oacis_setting)
      get :edit
      expect(assigns(:oacis_setting)).to eq(oacis_setting)
    end
  end

  describe "PUT update" do
    it "updates the oacis_setting" do
      oacis_setting = FactoryBot.create(:oacis_setting)
      expect(oacis_setting.reload.notification_level).to_not eq(1)
      expect(oacis_setting.reload.webhook_url).to_not eq('http://example.com/webhook2')
      put :update, params: { oacis_setting: { notification_level: 1, webhook_url: 'http://example.com/webhook2' } }
      expect(oacis_setting.reload.notification_level).to eq(1)
      expect(oacis_setting.reload.webhook_url).to eq('http://example.com/webhook2')
    end
  end
end
