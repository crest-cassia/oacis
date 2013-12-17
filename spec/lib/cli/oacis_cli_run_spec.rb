require 'spec_helper'
require File.join(Rails.root, 'lib/cli/oacis_cli')

describe OacisCli do

  describe "#job_parameter_template" do

    before(:each) do
      @host = FactoryGirl.create(:host_with_parameters)
    end

    it "outputs a template of job_parameters" do
      at_temp_dir {
        options = { host_id: @host.id.to_s, output: 'job_parameters.json'}
        OacisCli.new.invoke(:job_parameter_template, [], options)
        File.exist?('job_parameters.json').should be_true
        expect {
          JSON.load(File.read('job_parameters.json'))
        }.not_to raise_error
      }
    end

    it "outputs a template having default job_parameters" do
      at_temp_dir {
        options = { host_id: @host.id.to_s, output: 'job_parameters.json'}
        OacisCli.new.invoke(:job_parameter_template, [], options)

        expected = {
          "host_id" => @host.id.to_s,
          "job_parameters" => {"param1" => nil, "param2" => "XXX"},
          "mpi_procs" => 1,
          "omp_threads" => 1
        }
        JSON.load(File.read('job_parameters.json')).should eq expected
      }
    end

    context "when host id is invalid" do

      it "raises an exception" do
        at_temp_dir {
          options = { host_id: "DO_NOT_EXIST", output: 'job_parameters.json'}
          expect {
            OacisCli.new.invoke(:job_parameter_template, [], options)
          }.to raise_error
        }
      end
    end
  end
end
