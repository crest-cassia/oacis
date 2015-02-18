require 'spec_helper'
require File.join(Rails.root, 'lib/cli/oacis_cli')

describe OacisCli do

  describe "#usage" do

    it "prints usage" do
      capture(:stdout) {
        OacisCli.new.invoke(:usage)
      }.should_not be_empty
    end
  end

  describe "#show_host" do

    before(:each) do
      @host = FactoryGirl.create(:host)
    end

    it "prints host information in json" do
      at_temp_dir {
        expected = [{
          "id" => @host.id.to_s,
          "name" => @host.name,
          "hostname" => @host.hostname,
          "user" => @host.user
        }]
        OacisCli.new.invoke(:show_host, [], {output: 'host.json'})
        File.exist?('host.json').should be_truthy
        JSON.load( File.read('host.json') ).should eq expected
      }
    end

    context "when dry_run option is specified" do

      it "does not create output file" do
        at_temp_dir {
          OacisCli.new.invoke(:show_host, [], {output: 'host.json', dry_run: true})
          File.exist?('host.json').should be_falsey
        }
      end
    end
  end
end
