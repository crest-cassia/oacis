require 'spec_helper'

describe Webhook do

  describe "webhook can be triggerd" do

    before(:each) do
      @sim = FactoryBot.create(:simulator, parameter_sets_count: 2, runs_count: 0)
      Webhook.create if Webhook.count == 0
      @webhook = Webhook.first
      @webhook.webhook_url = "https://example.com/aaaa/bbbb"
      @webhook.save!
      @http_mock = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).with(anything(), anything()).and_return(@http_mock)
      allow(@http_mock).to receive(:use_ssl=).with(anything()).and_return("Anything")
      allow(@http_mock).to receive(:request).with(anything()).and_return("Success")
    end

    it "with condition: all_finished" do

      @webhook.webhook_condition = Webhook::WEBHOOK_CONDITION[0] # all_finished
      @webhook.save!
      Webhook.run #do not call http_post
      expect(Net::HTTP).not_to have_received(:new)
      @sim.parameter_sets.each do |ps|
        ps.runs.create!(status: :finished, submitted_to: Host.first)
      end
      trigger_condition = {}
      ParameterSet.runs_status_count_batch(@sim.parameter_sets).map do |key, val|
        trigger_condition[key.to_s] = val.map{|k,v| [k.to_s, v] }.to_h
      end
      # if webhook condition is satisfied webhook is triggered by once
      Webhook.run # call http_post
      expect(Net::HTTP).to have_received(:new).once
      @webhook.reload
      # webhook_condition and webhook_triggerd are updated
      expect(@webhook.webhook_condition).to eq(Webhook::WEBHOOK_CONDITION[0])
      expect(@webhook.webhook_triggered[@sim.id.to_s]).to eq(trigger_condition)

      # additionally finished runs are created
      @sim.parameter_sets.each do |ps|
        ps.runs.create!(status: :finished, submitted_to: Host.first)
      end
      Webhook.run # additinonally call http_post
      expect(Net::HTTP).to have_received(:new).twice # the count is not increased
      # if there is no change in status
      Webhook.run # do not call http_post
      expect(Net::HTTP).to have_received(:new).twice # the count is not increased
    end

    it "with condition: each_ps_finished" do

      @webhook.webhook_condition = Webhook::WEBHOOK_CONDITION[1] # each_ps_finished
      @webhook.save!
      Webhook.run #do not call http_post
      expect(Net::HTTP).not_to have_received(:new)
      @sim.parameter_sets.each do |ps|
        ps.runs.create!(status: :finished, submitted_to: Host.first)
      end
      trigger_condition = {}
      ParameterSet.runs_status_count_batch(@sim.parameter_sets).map do |key, val|
        trigger_condition[key.to_s] = val.map{|k,v| [k.to_s, v] }.to_h
      end
      # if webhook condition is satisfied webhook is triggered by once
      Webhook.run # call http_post
      expect(Net::HTTP).to have_received(:new).once
      @webhook.reload
      # webhook_condition and webhook_triggerd are updated
      expect(@webhook.webhook_condition).to eq(Webhook::WEBHOOK_CONDITION[1])
      expect(@webhook.webhook_triggered[@sim.id.to_s]).to eq(trigger_condition)

      # additionally finished runs are created
      @sim.parameter_sets.first.runs.create!(status: :finished, submitted_to: Host.first)
      Webhook.run # additinonally call http_post
      expect(Net::HTTP).to have_received(:new).twice # the count is not increased
      # if there is no change in status
      Webhook.run # do not call http_post
      expect(Net::HTTP).to have_received(:new).twice # the count is not increased
    end
  end
end