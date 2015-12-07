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

  describe "default_scope" do

    it "ignores Analysis of to_be_destroyed=true by default" do
      anl = Analysis.first
      expect {
        anl.update_attribute(:to_be_destroyed, true)
      }.to change { Analysis.count }.by(-1)
      expect( Analysis.all.to_a ).to_not include(anl)
    end
  end

  describe "validation" do

    it "is valid with proper attributes" do
      arn = @run.analyses.build(@valid_attr)
      expect(arn).to be_valid
    end

    it "is valid even if 'parameters' field is not given when default parameters are specified" do
      invalid_attr = @valid_attr
      invalid_attr.delete(:parameters)
      arn = @run.analyses.build(invalid_attr)
      expect(arn).to be_valid
    end

    it "assigns 'created' stauts by default" do
      arn = @run.analyses.create!(@valid_attr)
      expect(arn.status).to eq(:created)
    end

    it "is invalid if Analyzer is not related" do
      invalid_attr = @valid_attr
      invalid_attr.delete(:analyzer)
      arn = @run.analyses.build(invalid_attr)
      expect(arn).not_to be_valid
    end

    it "is invalid if there is no parent document" do
      arn = Analysis.new(@valid_attr)
      expect {
        arn.save!
      }.to raise_error
    end

    it "is invalid when status is not an allowed value" do
      arn = @run.analyses.create!(@valid_attr)

      arn.status = :status_XXX
      expect(arn).not_to be_valid
    end

    it "casts the parameter values according to the definition" do
      updated_attr = @valid_attr.update(parameters: {"param1"=>"32","param2"=>"3.0"})
      arn = @run.analyses.create!(updated_attr)
      type1 = @azr.parameter_definition_for("param1").type.constantize
      expect(arn.parameters["param1"]).to be_a(type1)
      type2 = @azr.parameter_definition_for("param2").type.constantize
      expect(arn.parameters["param2"]).to be_a(type2)
    end

    it "adopts default values if a parameter is not explicitly specified" do
      updated_attr = @valid_attr.update(parameters: {"param1"=>"32"})
      arn = @run.analyses.create!(updated_attr)
      default_val = arn.analyzer.parameter_definition_for("param2").default
      expect(arn.parameters["param2"]).to eq(default_val)
    end

    it "adopts default values when parameter hash is not given" do
      updated_attr = @valid_attr
      updated_attr.delete(:parameters)
      arn = @run.analyses.create(updated_attr)
      default_val1 = arn.analyzer.parameter_definition_for("param1").default
      default_val2 = arn.analyzer.parameter_definition_for("param2").default
      expect(arn.parameters["param1"]).to eq(default_val1)
      expect(arn.parameters["param2"]).to eq(default_val2)
    end
  end

  describe "relation" do

    it "can be embedded in a run" do
      @arn = @run.analyses.build(@valid_attr)
      expect(@run.analyses.last).to be_a(Analysis)
      expect(@arn.analyzable).to be_a(Run)
    end

    it "can be embedded in a parameter_set" do
      ps = @sim.parameter_sets.first
      @arn = ps.analyses.build(@valid_attr)
      expect(ps.analyses.last).to be_a(Analysis)
      expect(@arn.analyzable).to be_a(ParameterSet)
    end

    it "refers to analyzer" do
      @arn = @run.analyses.create!(@valid_attr)
      @arn.reload
      expect(@arn.analyzer).to be_a(Analyzer)
    end
  end

  describe "callback" do

    it "sets parameter_set when created" do
      anl = @run.analyses.create(@valid_attr)
      expect(anl).to respond_to(:parameter_set)
      expect(anl.parameter_set).to eq @run.parameter_set
    end
  end

  describe "#update_status_running" do

    it "updates status to 'running' and sets hostname" do
      ret = @arn.update_status_running(hostname: 'host_ABC')
      expect(ret).to be_truthy

      @arn.reload
      expect(@arn.status).to eq(:running)
      expect(@arn.hostname).to eq('host_ABC')
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
      expect(@arn.update_status_finished(@arg)).to be_truthy
    end

    it "sets status of runs" do
      @arn.update_status_finished(@arg)
      @arn.reload
      expect(@arn.cpu_time).to eq @arg[:cpu_time]
      expect(@arn.real_time).to eq @arg[:real_time]
      expect(@arn.result).to eq @arg[:result]
      expect(@arn.finished_at).to be_within(0.0001).of(@arg[:finished_at].utc)
      expect(@arn.included_at).to be_a(DateTime)
    end
  end

  describe "#update_status_failed" do

    before(:each) do
      @arn.update_status_running(hostname: 'host_ABC')
    end

    it "updates status to failed" do
      ret = @arn.update_status_failed
      expect(ret).to be_truthy
      @arn.reload
      expect(@arn.status).to eq(:failed)
    end
  end

  describe "#destroyable?" do

    before(:each) do
      sim = FactoryGirl.create(:simulator,
                               parameter_sets_count: 1, runs_count: 1,
                               analyzers_count: 1, run_analysis: true
                               )
    end

    it "always returns true" do
      expect( Analysis.first.destroyable? ).to be_truthy
    end
  end

  describe "#destroy" do

    before(:each) do
      sim = FactoryGirl.create(:simulator,
                               parameter_sets_count: 1, runs_count: 1,
                               analyzers_count: 1, run_analysis: true
                               )
      @analysis = sim.parameter_sets.first.runs.first.analyses.first
    end

    it "destroys item" do
      expect {
        @analysis.destroy
      }.to change { Analysis.count }.by(-1)
    end

    it "delete analysis directory" do
      dir = @analysis.dir
      @analysis.destroy
      expect(File.directory?(dir)).to be_falsey
    end
  end

  describe "#input" do

    describe "for :on_run type" do

      it "returns a Hash having 'simulation_parameters'" do
        expected = @run.parameter_set.v.merge( {_seed: @run.seed} )
        expect(@arn.input[:simulation_parameters]).to eq(expected)
      end

      it "returns a Hash having 'analysis_parameters'" do
        expect(@arn.input[:analysis_parameters]).to eq(@arn.parameters)
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
        expect(@arn.input[:simulation_parameters]).to eq(@ps.v)
      end

      it "returns a Hash having 'analysis_parameters'" do
        expect(@arn.input[:analysis_parameters]).to eq(@arn.parameters)
      end

      it "returns an Array having Run ids" do
        @run.status = :finished
        @run.save!
        run2 = FactoryGirl.create(:finished_run, parameter_set: @ps, result: {"zzz" => true})
        run3 = FactoryGirl.create(:run, parameter_set: @ps)
        run3.status = :failed
        run3.save
        expect(@arn.input[:run_ids].size).to eq(2)
        expect(@arn.input[:run_ids]).to match_array([@run.id.to_s, run2.id.to_s])
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
        expect(paths).to be_a(Array)
        expect(paths.size).to eq 2
        expect(paths).to match_array([@dummy_path, @dummy_dir])
      end

      it "does not include analysis directory of self" do
        paths = @arn.input_files
        expect(paths).not_to include(@arn.dir)
      end

      it "does not include directories of other Analyses by defualt" do
        another_arn = @run.analyses.create!(analyzer: @azr, parameters: {})
        paths = @arn.input_files
        expect(paths).not_to include(another_arn.dir)
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

      it "returns a array whose values are dirs of finished runs" do
        expect(@arn2.input_files).to be_a(Array)
        expect(@arn2.input_files).to eq([@run2.dir])
        expect(@arn2.input_files).not_to include(@run.dir)
      end
    end
  end

  describe "#dir" do

    it "returns directory for analysis" do
      expect(@arn.dir).to eq(ResultDirectory.analysis_path(@arn))
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
        expect(res).to include(f)
      end
      expect(res).to include(@temp_dir)
      expect(res.size).to eq(3)
    end
  end

  describe "result directory" do

    it "is created when a new item is saved" do
      expect(FileTest.directory?(@arn.dir)).to be_truthy
    end

    it "is not created when validation fails" do
      invalid_attr = @valid_attr
      invalid_attr.delete(:analyzer)
      arn = @run.analyses.build(@invalid_attr)
      expect {
        arn.save  # => false
      }.to change {Dir.entries(@run.dir).size}.by(0)
    end

    it "is deleted when an item is destroyed" do
      dir_path = @arn.dir
      @arn.destroy
      expect(FileTest.directory?(dir_path)).to be_falsey
    end
  end
end
