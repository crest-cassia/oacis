require 'spec_helper'
require File.join(Rails.root, 'lib/cli/oacis_cli')

describe OacisCli do

  describe "#usage" do

    it "prints usage" do
      expect(capture(:stdout) {
        OacisCli.new.invoke(:usage)
      }).not_to be_empty
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
        expect(File.exist?('host.json')).to be_truthy
        expect(JSON.load( File.read('host.json') )).to eq expected
      }
    end

    context "when dry_run option is specified" do

      it "does not create output file" do
        at_temp_dir {
          OacisCli.new.invoke(:show_host, [], {output: 'host.json', dry_run: true})
          expect(File.exist?('host.json')).to be_falsey
        }
      end
    end
  end
end
