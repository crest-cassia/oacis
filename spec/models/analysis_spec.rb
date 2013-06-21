require 'spec_helper'

describe Analysis do

  before(:each) do
    @sim = FactoryGirl.create(:simulator, 
                              parameter_sets_count:1, runs_count:1,
                              analyzers_count: 1, run_analysis: true
                              )
    @run = @sim.parameter_sets.first.runs.first
    @azr = @sim.analyzers.first
    @arn = @run.analyses.first
    @valid_attr = {
        parameters: {"param1" => 1, "param2" => 2.0},
        analyzer: @azr
    }
  end

  describe "validation" do

    it "is valid with proper attributes" do
      arn = @run.analyses.build(@valid_attr)
      arn.should be_valid
    end

    it "is valid even if 'parameters' field is not given when default parameters are specified" do
      invalid_attr = @valid_attr
      invalid_attr.delete(:parameters)
      arn = @run.analyses.build(invalid_attr)
      arn.should be_valid
    end

    it "assigns 'created' stauts by default" do
      arn = @run.analyses.create!(@valid_attr)
      arn.status.should == :created
    end

    it "is invalid if Analyzer is not related" do
      invalid_attr = @valid_attr
      invalid_attr.delete(:analyzer)
      arn = @run.analyses.build(invalid_attr)
      arn.should_not be_valid
    end

    it "is invalid if there is no parent document" do
      arn = Analysis.new(@valid_attr)
      lambda {
        arn.save!
      }.should raise_error
    end

    it "is invalid when status is not an allowed value" do
      arn = @run.analyses.create!(@valid_attr)

      arn.status = :status_XXX
      arn.should_not be_valid
    end

    it "casts the parameter values according to the definition" do
      updated_attr = @valid_attr.update(parameters: {"param1"=>"32","param2"=>"abc"})
      arn = @run.analyses.create!(updated_attr)
      arn.parameters["param1"].should be_a(Float)
      arn.parameters["param2"].should be_a(String)
    end

    it "adopts default values if a parameter is not explicitly specified" do
      updated_attr = @valid_attr.update(parameters: {"param1"=>"32"})
      arn = @run.analyses.create!(updated_attr)
      default_val = arn.analyzer.parameter_definitions["param2"]["default"]
      arn.parameters["param2"].should eq(default_val)
    end

    it "adopts default values when parameter hash is not given" do
      updated_attr = @valid_attr
      updated_attr.delete(:parameters)
      arn = @run.analyses.create(updated_attr)
      default_val1 = arn.analyzer.parameter_definitions["param1"]["default"]
      default_val2 = arn.analyzer.parameter_definitions["param2"]["default"]
      arn.parameters["param1"].should eq(default_val1)
      arn.parameters["param2"].should eq(default_val2)
    end
  end

  describe "accessibility" do

    it "result is not an accessible field" do
      arn = @run.analyses.build(@valid_attr.update(result: "abc"))
      arn.result.should be_nil
    end

    it "status is not an accessible field" do
      arn = @run.analyses.build(@valid_attr.update(status: :running))
      arn.status.should_not == :running
    end
  end

  describe "relation" do

    it "can be embedded in a run" do
      @arn = @run.analyses.build(@valid_attr)
      @run.analyses.last.should be_a(Analysis)
      @arn.analyzable.should be_a(Run)
    end

    it "can be embedded in a parameter_set" do
      ps = @sim.parameter_sets.first
      @arn = ps.analyses.build(@valid_attr)
      ps.analyses.last.should be_a(Analysis)
      @arn.analyzable.should be_a(ParameterSet)
    end

    it "refers to analyzer" do
      @arn = @run.analyses.create!(@valid_attr)
      @arn.reload
      @arn.analyzer.should be_a(Analyzer)
    end
  end

  describe "#update_status_running" do

    it "updates status to 'running' and sets hostname" do
      ret = @arn.update_status_running(hostname: 'host_ABC')
      ret.should be_true

      @arn.reload
      @arn.status.should == :running
      @arn.hostname.should == 'host_ABC'
    end
  end

  describe "#update_status_finished" do

    before(:each) do
      @arn.update_status_running(:hostname => 'host_ABC')
      @arg = { result: {"x" => 1.0}, cpu_time: 1.5, real_time: 2.0, finished_at: DateTime.now }
    end

    it "updates status to 'finished'" do
      expect {
        ret = @arn.update_status_finished(@arg)
      }.to change { @arn.reload.status }.from(:running).to(:finished)
    end

    it "returns true" do
      @arn.update_status_finished(@arg).should be_true
    end

    it "sets status of runs" do
      @arn.update_status_finished(@arg)
      @arn.reload
      @arn.cpu_time.should eq @arg[:cpu_time]
      @arn.real_time.should eq @arg[:real_time]
      @arn.result.should eq @arg[:result]
      @arn.finished_at.should be_within(0.0001).of(@arg[:finished_at].utc)
      @arn.included_at.should be_a(DateTime)
    end
  end

  describe "#update_status_failed" do

    before(:each) do
      @arn.update_status_running(hostname: 'host_ABC')
    end

    it "updates status to failed" do
      ret = @arn.update_status_failed
      ret.should be_true
      @arn.reload
      @arn.status.should eq(:failed)
    end
  end

  describe "#input" do

    describe "for :on_run type" do

      it "returns a Hash having 'simulation_parameters'" do
        @arn.input[:simulation_parameters].should eq(@run.parameter_set.v)
      end

      it "returns a Hash having 'analysis_parameters'" do
        @arn.input[:analysis_parameters].should eq(@arn.parameters)
      end

      it "returns a Hash having result of Run" do
        @run.result = {"xxx" => 1234, "yyy" => 0.5}
        @run.save!
        @arn.input[:result].should eq(@run.result)
      end
    end

    describe "for :on_parameter_set type" do

      before(:each) do
        @azr = FactoryGirl.create(:analyzer,
                                  simulator: @sim, type: :on_parameter_set, run_analysis: true)
        @ps = @sim.parameter_sets.first
        @arn = @ps.analyses.first
      end

      it "returns a Hash having 'simulation_parameters'" do
        @arn.input[:simulation_parameters].should eq(@ps.v)
      end

      it "returns a Hash having 'analysis_parameters'" do
        @arn.input[:analysis_parameters].should eq(@arn.parameters)
      end

      it "returns a Hash having result of Runs" do
        @run.result = {"xxx" => 1234, "yyy" => 0.5}
        @run.save!
        run2 = FactoryGirl.create(:finished_run, parameter_set: @ps, result: {"zzz" => true})
        @arn.input[:result].size.should eq(2)
        @arn.input[:result].should have_key(@run.to_param)
        @arn.input[:result].should have_key(run2.to_param)
        @arn.input[:result][@run.to_param].should eq(@run.result)
        @arn.input[:result][run2.to_param].should eq(run2.result)
      end
    end

    describe "for :on_parameter_set_group type" do

      it "returns an appropriate hash" do
        pending "not yet implemented"
      end
    end
  end

  describe "#input_files" do

    describe "for :on_run type" do

      before(:each) do
        @dummy_path = @run.dir.join('__dummy__')
        FileUtils.touch( @dummy_path )
        @dummy_dir = @run.dir.join('__dummy_dir__')
        FileUtils.mkdir_p(@dummy_dir)
      end

      after(:each) do
        FileUtils.rm( @dummy_path ) if File.exist?(@dummy_path)
        FileUtils.rm_r(@dummy_dir) if File.directory?(@dummy_dir)
      end

      it "returns a file entries in run directory" do
        paths = @arn.input_files
        paths.should be_a(Hash)
        paths.should have(1).items
        (paths['.'] - [@dummy_path, @dummy_dir]).should be_empty
      end

      it "does not include analysis directory of self" do
        paths = @arn.input_files
        paths.values.flatten.should_not include(@arn.dir)
      end

      it "does not include directories of other Analyses by defualt" do
        another_arn = @run.analyses.create!(analyzer: @azr, parameters: {})
        paths = @arn.input_files
        paths.values.flatten.should_not include(another_arn.dir)
      end
    end

    describe "for :on_parameter_set type" do

      before(:each) do
        @azr = FactoryGirl.create(:analyzer,
                                  simulator: @sim, type: :on_parameter_set, run_analysis: true)
        @ps = @sim.parameter_sets.first
        @arn2 = @ps.analyses.first

        @run2 = FactoryGirl.create(:finished_run, parameter_set: @ps)

        @dummy_files = [@run2.dir.join('__dummy__')]
        @dummy_dirs = [@run2.dir.join('__dummy_dir__')]
        @dummy_files.each {|path| FileUtils.touch(path) }
        @dummy_dirs.each {|dir| FileUtils.mkdir_p(dir) }
      end

      after(:each) do
        @dummy_files.each {|file| FileUtils.rm(file) if File.exist?(file) }
        @dummy_dirs.each {|dir| FileUtils.rm_r(dir) if File.directory?(dir) }
      end

      it "returns a hash whose keys are ids of finished runs" do
        @arn2.input_files.keys.should eq( [@run2.to_param] )
        @arn2.input_files.keys.should_not include(@run.to_param)
      end

      it "returns a hash whose values are output paths of runs" do
        paths = @arn2.input_files[@run2.to_param]
        paths.should eq(@run2.result_paths)
      end
    end

    describe "for :on_parameter_set_group type" do

      it "returns an appropriate entries" do
        pending "not yet implemented"
      end
    end
  end

  describe "#dir" do

    it "returns directory for analysis run" do
      @arn.dir.should eq(ResultDirectory.analysis_path(@arn))
    end
  end

  describe "#result_paths" do

    before(:each) do
      @temp_files = [@arn.dir.join('result1.txt'), @arn.dir.join('result2.txt')]
      @temp_files.each {|f| FileUtils.touch(f) }
      @temp_dir = @arn.dir.join('result_dir')
      FileUtils.mkdir_p(@temp_dir)
    end

    after(:each) do
      @temp_files.each {|f| FileUtils.rm(f) if File.exist?(f) }
      FileUtils.rm_r(@temp_dir)
    end

    it "returns list of result files" do
      res = @arn.result_paths
      @temp_files.each do |f|
        res.should include(f)
      end
      res.should include(@temp_dir)
      res.size.should eq(3)
    end
  end

  describe "result directory" do

    it "is created when a new item is saved" do
      FileTest.directory?(@arn.dir).should be_true
    end

    it "is not created when validation fails" do
      invalid_attr = @valid_attr
      invalid_attr.delete(:analyzer)
      arn = @run.analyses.build(@invalid_attr)
      expect {
        arn.save  # => false
      }.to change {Dir.entries(@run.dir).size}.by(0)
    end
  end
end
