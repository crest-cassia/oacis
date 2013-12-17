require 'spec_helper'
require File.join(Rails.root, 'lib/cli/oacis_cli')

describe OacisCli do

  describe "#host_parameter_template" do

    before(:each) do
      @host = FactoryGirl.create(:host_with_parameters)
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 0, support_mpi: true, support_omp: true)
      @sim.executable_on.push @host
      @sim.save!
    end


    it "outputs a template of host_parameters" do
      at_temp_dir {
        options = { host_id: @host.id.to_s, output: 'host_parameters.json'}
        OacisCli.new.invoke(:host_parameter_template, [], options)
        File.exist?('host_parameters.json').should be_true
        expect {
          JSON.load(File.read('host_parameters.json'))
        }.not_to raise_error
      }
    end

    it "outputs a template having default host_parameters" do
      at_temp_dir {
        options = { host_id: @host.id.to_s, output: 'host_parameters.json'}
        OacisCli.new.invoke(:host_parameter_template, [], options)

        expected = {
          "host_id" => @host.id.to_s,
          "host_parameters" => {"param1" => nil, "param2" => "XXX"},
          "mpi_procs" => 1,
          "omp_threads" => 1
        }
        JSON.load(File.read('host_parameters.json')).should eq expected
      }
    end

    context "when host id is invalid" do

      it "raises an exception" do
        at_temp_dir {
          options = { host_id: "DO_NOT_EXIST", output: 'host_parameters.json'}
          expect {
            OacisCli.new.invoke(:host_parameter_template, [], options)
          }.to raise_error
        }
      end
    end
  end
end
