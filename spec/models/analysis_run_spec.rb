require 'spec_helper'

describe AnalysisRun do

  before(:each) do
    @sim = FactoryGirl.create(:simulator, 
                              parameter_sets_count:1, runs_count:1,
                              analyzers_count: 1, run_analysis: true)
    @run = @sim.parameter_sets.first.runs.first
    @azr = @sim.analyzers.first
    @arn = @run.analysis_runs.first
    @valid_attr = {
        parameters: {"param1" => 1, "param2" => 2.0},
        analyzer: @azr
    }
  end

  describe "validation" do

    it "is valid with proper attributes" do
      arn = @run.analysis_runs.build(@valid_attr)
      arn.should be_valid
    end

    it "is valid even if 'parameters' field is not given when default parameters are specified" do
      invalid_attr = @valid_attr
      invalid_attr.delete(:parameters)
      arn = @run.analysis_runs.build(invalid_attr)
      arn.should be_valid
    end

    it "assigns 'created' stauts by default" do
      arn = @run.analysis_runs.create!(@valid_attr)
      arn.status.should == :created
    end

    it "is invalid if Analyzer is not related" do
      invalid_attr = @valid_attr
      invalid_attr.delete(:analyzer)
      arn = @run.analysis_runs.build(invalid_attr)
      arn.should_not be_valid
    end

    it "is invalid if there is no parent document" do
      arn = AnalysisRun.new(@valid_attr)
      lambda {
        arn.save!
      }.should raise_error
    end

    it "is invalid when status is not an allowed value" do
      arn = @run.analysis_runs.create!(@valid_attr)

      arn.status = :status_XXX
      arn.should_not be_valid
    end

    it "casts the parameter values according to the definition" do
      updated_attr = @valid_attr.update(parameters: {"param1"=>"32","param2"=>"2.0"})
      arn = @run.analysis_runs.create!(updated_attr)
      arn.parameters["param1"].should be_a(Integer)
      arn.parameters["param2"].should be_a(Float)
    end

    it "adopts default values if a parameter is not explicitly specified" do
      updated_attr = @valid_attr.update(parameters: {"param1"=>"32"})
      arn = @run.analysis_runs.create!(updated_attr)
      default_val = arn.analyzer.parameter_definitions["param2"]["default"]
      arn.parameters["param2"].should eq(default_val)
    end

    it "adopts default values when parameter hash is not given" do
      updated_attr = @valid_attr
      updated_attr.delete(:parameters)
      arn = @run.analysis_runs.create(updated_attr)
      default_val1 = arn.analyzer.parameter_definitions["param1"]["default"]
      default_val2 = arn.analyzer.parameter_definitions["param2"]["default"]
      arn.parameters["param1"].should eq(default_val1)
      arn.parameters["param2"].should eq(default_val2)
    end
  end

  describe "accessibility" do

    it "result is not an accessible field" do
      arn = @run.analysis_runs.build(@valid_attr.update(result: "abc"))
      arn.result.should be_nil
    end

    it "status is not an accessible field" do
      arn = @run.analysis_runs.build(@valid_attr.update(status: :running))
      arn.status.should_not == :running
    end
  end

  describe "relation" do

    it "can be embedded in a run" do
      @arn = @run.analysis_runs.build(@valid_attr)
      @run.analysis_runs.last.should be_a(AnalysisRun)
      @arn.analyzable.should be_a(Run)
    end

    it "can be embedded in a parameter_set" do
      ps = @sim.parameter_sets.first
      @arn = ps.analysis_runs.build(@valid_attr)
      ps.analysis_runs.last.should be_a(AnalysisRun)
      @arn.analyzable.should be_a(ParameterSet)
    end

    it "refers to analyzer" do
      @arn = @run.analysis_runs.create!(@valid_attr)
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

  describe "#update_status_including" do

    before(:each) do
      @arn.update_status_running(:hostname => 'host_ABC')
    end

    it "updates status to 'including' and 'finished_at'" do
      ret = @arn.update_status_including
      ret.should be_true

      @arn.reload
      @arn.status.should == :including
      @arn.result.should be_nil
      @arn.finished_at.should_not be_nil
      @arn.included_at.should be_nil
    end

    it "also updates cpu- and real-times" do
      ret = @arn.update_status_including(cpu_time: 1.5, real_time: 2.0)
      @arn.reload
      @arn.cpu_time.should == 1.5
      @arn.real_time.should == 2.0
    end

    it "also updates 'result'" do
      result = {xxx: "abc", yyy: 12345}
      ret = @arn.update_status_including(result: result, cpu_time: 1.5, real_time: 2.0)
      @arn.reload
      @arn.result["xxx"].should eq("abc")
      @arn.result["yyy"].should eq(12345)
    end
  end

  describe "#update_status_finished" do

    before(:each) do
      @arn.update_status_running(:hostname => 'host_ABC')
      @arn.update_status_including(result: {x:1.0}, cpu_time: 1.5, real_time: 2.0)
    end

    it "updates status to 'finished'" do
      ret = @arn.update_status_finished
      ret.should be_true
      @arn.reload
      @arn.status.should eq(:finished)
      @arn.included_at.should_not be_nil
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

      it "returns an appropriate hash" do
        pending "not yet implemented"
      end
    end

    describe "for :on_parameter_sets_group type" do

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

      it "returns an file entries in run directory" do
        paths = @arn.input_files
        paths.should be_a(Array)
        paths.include?(@run.dir.join('__dummy__')).should be_true
        paths.include?(@run.dir.join('__dummy_dir__')).should be_true
        paths.size.should eq(2)   # entries include '.' and '..'
      end

      it "does not include analysis_run directory of self" do
        paths = @arn.input_files
        paths.should_not include(@arn.dir)
      end

      it "does not include directories of other AnalysisRuns by defualt" do
        another_arn = @run.analysis_runs.create!(analyzer: @azr, parameters: {})
        paths = @arn.input_files
        paths.should_not include(another_arn.dir)
      end
    end

    describe "for :on_parameter_set type" do

      it "returns an appropriate entries" do
        pending "not yet implemented"
      end
    end

    describe "for :on_parameter_sets_group type" do

      it "returns an appropriate entries" do
        pending "not yet implemented"
      end
    end
  end

  describe "#dir" do

    it "returns directory for analysis run" do
      @arn.dir.should eq(ResultDirectory.analysis_run_path(@arn))
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
      arn = @run.analysis_runs.build(@invalid_attr)
      expect {
        arn.save  # => false
      }.to change {Dir.entries(@run.dir).size}.by(0)
    end
  end
end
