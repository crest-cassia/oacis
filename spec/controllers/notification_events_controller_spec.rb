require 'spec_helper'

describe NotificationEventsController do
  describe "GET 'index'" do

    it "returns http success" do
      get 'index', params: {}
      expect(response).to be_successful
    end

    it "assigns all notification_events as @notification_events" do
      notification_event = FactoryBot.create(:notification_event)
      get :index, params: {}
      expect(response).to be_successful
      expect(assigns(:notification_events)).to eq([notification_event])
    end
  end
end
