require 'spec_helper'
require File.join(Rails.root, 'lib/cli/oacis_cli')

describe OacisCli do

  describe "#usage" do

    it "prints usage" do
      expect {
        OacisCli.new.invoke(:usage)
      }.to output(/usage:/).to_stdout
    end
  end

  describe "#show_host" do

    before(:each) do
      @host = FactoryBot.create(:host)
    end

    it "prints host information in json" do
      at_temp_dir {
        expected = [{
          "id" => @host.id.to_s,
          "name" => @host.name
        }]
        OacisCli.new.invoke(:show_host, [], {output: 'host.json'})
        expect(File.exist?('host.json')).to be_truthy
        expect(JSON.load( File.read('host.json') )).to eq expected
      }
    end
  end
end
