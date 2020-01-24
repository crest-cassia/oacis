require 'spec_helper'

describe WebhookSender do

  describe ".perform" do

    before(:each) do
      @sim = FactoryBot.create(:simulator, parameter_sets_count: 2, runs_count: 0)
      Webhook.create() if Webhook.count == 0
      @webhook = Webhook.first
      @webhook_mock = instance_double(Webhook)
      allow(Net::HTTP).to receive(:new).with(anything(), anything()).and_return(@http_mock)
      allow(@http_mock).to receive(:use_ssl=).with(anything()).and_return("Anything")
      allow(@http_mock).to receive(:request).with(anything()).and_return("Success")
      @logger = Logger.new( File.open('/dev/null','w') )
    end

    it "do nothing if there is no 'enabled' webhook" do
      @webhook.update_attribute(:status, :disabled)
      @sim.parameter_sets.each do |ps|
        ps.runs.create!(status: :finished, submitted_to: Host.first)
      end
      WebhookSender.perform(@logger)
      expect(Net::HTTP).not_to have_received(:new)
    end
  end
end
