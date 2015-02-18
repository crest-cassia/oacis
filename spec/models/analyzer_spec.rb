require 'spec_helper'

describe Analyzer do

  before(:each) do
    @sim = FactoryGirl.create(:simulator, parameter_sets_count:0, runs_count:0)
  end

  describe "validations" do

    before(:each) do
      @valid_fields = {
        name: "time_series_analyzer",
        type: :on_run,
        parameter_definitions_attributes: [
          { key: "initial_skip", type: "Integer", default: "0", description: "Number of inital step" }
        ],
        command: "ruby ~/path/to/time_series_analyzer.rb",
        print_version_command: "echo \"v0.1.0\"",
        description: "time series analysis"
      }
    end

    it "is valid with appropriate fields" do
      analyzer = @sim.analyzers.build(@valid_fields)
      analyzer.should be_a(Analyzer)
      analyzer.should be_valid
    end

    describe "'name' field" do

      it "must exist" do
        analyzer = @sim.analyzers.build(@valid_fields.update(name:""))
        analyzer.should_not be_valid
      end

      it "must be unique" do
        @sim.analyzers.create!(@valid_fields)
        analyzer = @sim.analyzers.build(@valid_fields)
        analyzer.should_not be_valid
      end

      it "must be unique within simulator" do
        @sim.analyzers.create(@valid_fields)
        another_sim = FactoryGirl.create(:simulator, parameter_sets_count:0, runs_count: 0)
        another_sim.analyzers.build(@valid_fields)
        another_sim.should be_valid
      end

      it "must be organized with letters, numbers, and underscores" do
        analyzer = @sim.analyzers.build(@valid_fields.update({name:"b l a n k"}))
        analyzer.should_not be_valid
      end
    end

    describe "'type' field" do

      it "must exist" do
        invalid_fields = @valid_fields
        invalid_fields.delete(:type)
        azr = @sim.analyzers.build(invalid_fields)
        azr.should_not be_valid
      end

      it "must be either 'on_run', 'on_parameter_set'" do
        invalid_fields = @valid_fields.update({type: "on_xxx"})
        azr = @sim.analyzers.build(invalid_fields)
        azr.should_not be_valid
      end
    end

    describe "'command' field" do

      it "must have 'command'" do
        invalid_attr = @valid_fields
        invalid_attr.delete(:command)
        azr = @sim.analyzers.build(invalid_attr)
        azr.should_not be_valid
      end
    end

    describe "'print_version_command' field" do

      it "can be blank" do
        fields = @valid_fields
        fields.delete(:print_version_command)
        @sim.analyzers.build(fields).should be_valid
      end
    end

    describe "'parameter_definitions' field" do

      it "can be a empty" do
        azr = @sim.analyzers.build(@valid_fields.update(parameter_definitions:[]))
        azr.should be_valid
      end

      it "can be nil" do
        @valid_fields.delete(:parameter_definitions)
        azr = @sim.analyzers.build(@valid_fields)
        pp azr.errors unless azr.valid?
        azr.should be_valid
      end
    end

    describe "'auto_run' field" do

      it "must be either 'yes', 'no', or 'first_run_only'" do
        invalid_fields = @valid_fields.update( auto_run: :every_run )
        azr = @sim.analyzers.build(invalid_fields)
        azr.should_not be_valid
      end
    end

    describe "'description' field" do

      it "can be blank" do
        fields = @valid_fields
        fields.delete(:description)
        @sim.analyzers.build(fields).should be_valid
      end
    end
  end

  describe "relation" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 3,
                                analyzers_count: 1, run_analysis: true)
      @azr = @sim.analyzers.first
    end

    it "has many analyses" do
      expect(@azr.analyses.size).to eq 3
    end
  end

  describe "#destroy" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1,
                                analyzers_count: 1, run_analysis: true)
      @azr = @sim.analyzers.first
    end

    it "destroys analyzer" do
      expect {
        @azr.destroy
      }.to change { @sim.analyzers.count }.by(-1)
    end

    it "destroys dependent analyses" do
      expect {
        @azr.destroy
      }.to change { Analysis.count }.by(-1)
    end
  end

  describe "#analyzer_versions" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 5,
                                analyzers_count: 1, run_analysis: true)
      @azr = @sim.analyzers.first

      analyses = Analysis.where(analyzer: @azr).asc(:id)

      analyses[0].update_attribute(:started_at, 2.days.ago)
      analyses[0].update_attribute(:analyzer_version, "v1")
      analyses[1].update_attribute(:started_at, 1.days.ago)
      analyses[1].update_attribute(:analyzer_version, "v1")
      analyses[2].update_attribute(:started_at, 3.days.ago)
      analyses[2].update_attribute(:analyzer_version, "v2")
      analyses[3].update_attribute(:started_at, 2.days.ago)
      analyses[3].update_attribute(:analyzer_version, "v2")
      analyses[4].update_attribute(:started_at, 1.days.ago)
      analyses[4].update_attribute(:analyzer_version, "v2")
      analyses[4].update_attribute(:status, :failed)
    end

    it "returns list of simulator_versions in Array" do
      @azr.analyzer_versions.should be_a(Array)
    end

    it "returns array of hash whose 'version' field is simulator_versions" do
      @azr.analyzer_versions.map {|h| h['version']}.should =~ ["v1", "v2"]
    end

    it "returns array of hash which has 'oldest_started_at' and 'latest_started_at' fields" do
      analyses = Analysis.where(analyzer: @azr).asc(&:id)
      expected = [
        { "version" => "v1",
          "oldest_started_at" => analyses[0].started_at,
          "latest_started_at" => analyses[1].started_at,
          "count" => {finished: 2} },
        { "version" => "v2",
          "oldest_started_at" => analyses[2].started_at,
          "latest_started_at" => analyses[4].started_at,
          "count" => {finished: 2, failed: 1} }
      ]
      @azr.analyzer_versions.should =~ expected
    end

    it "returns array which is sorted by 'latest_started_at' in ascending order" do
      @azr.analyzer_versions.map {|h| h['version']}.should eq ["v1", "v2"]
    end

    it "counts analyses for each status" do
      finished_count = Analysis.where(analyzer: @azr).where(status: :finished).count
      failed_count = Analysis.where(analyzer: @azr).where(status: :failed).count
      output = @azr.analyzer_versions
      output.map {|h| h['count'][:finished].to_i }.inject(:+).should eq finished_count
      output.map {|h| h['count'][:failed].to_i }.inject(:+).should eq failed_count
    end
  end
end
