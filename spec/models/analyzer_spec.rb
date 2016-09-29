require 'spec_helper'

describe Analyzer do

  before(:each) do
    @sim = FactoryGirl.create(:simulator, parameter_sets_count:0, runs_count:0)
  end

  describe "default_scope" do

    it "ignores Analyzer of to_be_destroyed=true by default" do
      azr = Analyzer.first
      expect {
        azr.update_attribute(:to_be_destroyed, true)
      }.to change { Analyzer.count }.by(-1)
      expect( Analyzer.all.to_a ).to_not include(azr)
    end
  end

  describe "validations" do

    before(:each) do
      @valid_fields = {
        name: "time_series_analyzer",
        type: :on_run,
        parameter_definitions_attributes: [
          { key: "initial_skip", type: "Integer", default: "0", description: "Number of inital step" }
        ],
        support_input_json: true,
        support_mpi: false,
        support_omp: false,
        command: "ruby ~/path/to/time_series_analyzer.rb",
        print_version_command: "echo \"v0.1.0\"",
        description: "time series analysis"
      }
    end

    it "is valid with appropriate fields" do
      analyzer = @sim.analyzers.build(@valid_fields)
      expect(analyzer).to be_a(Analyzer)
      expect(analyzer).to be_valid
    end

    describe "'name' field" do

      it "must exist" do
        analyzer = @sim.analyzers.build(@valid_fields.update(name:""))
        expect(analyzer).not_to be_valid
      end

      it "must be unique" do
        @sim.analyzers.create!(@valid_fields)
        analyzer = @sim.analyzers.build(@valid_fields)
        expect(analyzer).not_to be_valid
      end

      it "must be unique within simulator" do
        @sim.analyzers.create(@valid_fields)
        another_sim = FactoryGirl.create(:simulator, parameter_sets_count:0, runs_count: 0)
        another_sim.analyzers.build(@valid_fields)
        expect(another_sim).to be_valid
      end

      it "must be organized with letters, numbers, and underscores" do
        analyzer = @sim.analyzers.build(@valid_fields.update({name:"b l a n k"}))
        expect(analyzer).not_to be_valid
      end

      it "is valid when name is identical to an analyzer being destroyed" do
        azr = @sim.analyzers.create!(@valid_fields)
        azr.update_attribute(:to_be_destroyed, true)
        expect( @sim.analyzers.build(@valid_fields) ).to be_valid
      end

      it "can take identical name for simulators being destroyed" do
        attr = @valid_fields.update(to_be_destroyed: true)
        azr = @sim.analyzers.create!(attr)
        expect( @sim.analyzers.build(attr) ).to be_valid
      end
    end

    describe "'type' field" do

      it "must exist" do
        invalid_fields = @valid_fields
        invalid_fields.delete(:type)
        azr = @sim.analyzers.build(invalid_fields)
        expect(azr).not_to be_valid
      end

      it "must be either 'on_run', 'on_parameter_set'" do
        invalid_fields = @valid_fields.update({type: "on_xxx"})
        azr = @sim.analyzers.build(invalid_fields)
        expect(azr).not_to be_valid
      end
    end

    describe "'command' field" do

      it "must have 'command'" do
        invalid_attr = @valid_fields
        invalid_attr.delete(:command)
        azr = @sim.analyzers.build(invalid_attr)
        expect(azr).not_to be_valid
      end
    end

    describe "'print_version_command' field" do

      it "can be blank" do
        fields = @valid_fields
        fields.delete(:print_version_command)
        expect(@sim.analyzers.build(fields)).to be_valid
      end
    end

    describe "'parameter_definitions' field" do

      it "can be a empty" do
        azr = @sim.analyzers.build(@valid_fields.update(parameter_definitions:[]))
        expect(azr).to be_valid
      end

      it "can be nil" do
        @valid_fields.delete(:parameter_definitions)
        azr = @sim.analyzers.build(@valid_fields)
        pp azr.errors unless azr.valid?
        expect(azr).to be_valid
      end
    end

    describe "'auto_run' field" do

      it "must be either 'yes', 'no', or 'first_run_only'" do
        invalid_fields = @valid_fields.update( auto_run: :every_run )
        azr = @sim.analyzers.build(invalid_fields)
        expect(azr).not_to be_valid
      end
    end

    describe "'description' field" do

      it "can be blank" do
        fields = @valid_fields
        fields.delete(:description)
        expect(@sim.analyzers.build(fields)).to be_valid
      end
    end

    describe "'auto_run_submitted_to' field" do

      it "is valid when auto_run_submitted_to is included in executable_on" do
        another_host = FactoryGirl.create(:host)
        valid_fields = @valid_fields.update(
          executable_on: [another_host],
          auto_run_submitted_to: another_host
          )
        azr = @sim.analyzers.build(valid_fields)
        expect(azr).to be_valid
      end

      it "is not valid if auto_run_submitted_to is not included in executable_on" do
        another_host = FactoryGirl.create(:host)
        invalid_fields = @valid_fields.update(auto_run_submitted_to: another_host.id)
        azr = @sim.analyzers.build(invalid_fields)
        expect(azr).not_to be_valid
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

  describe "#discard" do

    before(:each) do
      sim = FactoryGirl.create(:simulator, analyzers_count: 1)
      @azr = sim.analyzers.first
    end

    it "updates 'to_be_destroyed' to true" do
      expect {
        @azr.discard
      }.to change { @azr.to_be_destroyed }.from(false).to(true)
    end

    it "should receive 'set_lower_submittable_to_be_destroyed'" do
      expect(@azr).to receive(:set_lower_submittable_to_be_destroyed)
      @azr.discard
    end
  end

  describe "#set_lower_submittable_to_be_destroyed" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 1,
                                runs_count: 1,
                                analyzers_count: 1, run_analysis: true,
                                analyzers_on_parameter_set_count: 1,
                                run_analysis_on_parameter_set: true
                                )
    end

    it "sets to_be_destroyed of lower Analysis" do
      @sim.analyzers.each do |azr|
        expect {
          azr.set_lower_submittable_to_be_destroyed
        }.to change { azr.reload.analyses.empty? }.from(false).to(true)
      end
    end
  end

  describe "#destroyable?" do
    before(:each) do
      sim = FactoryGirl.create(:simulator,
                               parameter_sets_count: 1,
                               runs_count: 1,
                               analyzers_count: 1,
                               run_analysis: true
                               )
      @azr = sim.analyzers.first
    end

    it "returns false when it has Run or Analysis" do
      expect(@azr.destroyable?).to be_falsey
    end

    it "returns true when all the Run or Analysis is destroyed" do
      @azr.set_lower_submittable_to_be_destroyed
      expect( @azr.destroyable? ).to be_falsey
      @azr.analyses.unscoped.destroy
      expect( @azr.destroyable? ).to be_truthy
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

    it "does not destroy dependent analyses" do
      expect {
        @azr.destroy
      }.to_not change { Analysis.count }
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

    it "returns list of analyzer_versions in Array" do
      expect(@azr.analyzer_versions).to be_a(Array)
    end

    it "returns array of hash whose 'version' field is analyzer_versions" do
      expect(@azr.analyzer_versions.map {|h| h['version']}).to match_array(["v1", "v2"])
    end

    it "returns array of hash which has 'oldest_started_at' and 'latest_started_at' fields" do
      analyses = Analysis.where(analyzer: @azr).asc(:id)
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
      expect(@azr.analyzer_versions).to match_array(expected)
    end

    it "returns array which is sorted by 'latest_started_at' in ascending order" do
      expect(@azr.analyzer_versions.map {|h| h['version']}).to eq ["v1", "v2"]
    end

    it "counts analyses for each status" do
      finished_count = Analysis.where(analyzer: @azr).where(status: :finished).count
      failed_count = Analysis.where(analyzer: @azr).where(status: :failed).count
      output = @azr.analyzer_versions
      expect(output.map {|h| h['count'][:finished].to_i }.inject(:+)).to eq finished_count
      expect(output.map {|h| h['count'][:failed].to_i }.inject(:+)).to eq failed_count
    end
  end

  describe "get_default_host_parameter" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 1,
                                runs_count: 1,
                                analyzers_count: 1
                               )
      @host = FactoryGirl.create(:host_with_parameters)
      @azr = @sim.analyzers.first
      @azr.executable_on.destroy
      @azr.executable_on << @host
    end

    context "when there is no analysis" do

      it "return default_host_parameter associated with a host" do
        key_value = @host.host_parameter_definitions.map {|pd| [pd.key, pd.default]}
        expect(@azr.get_default_host_parameter(@host)).to eq Hash[*key_value.flatten]
      end

      it "return default_host_parameter for manual submission" do
        expect(@sim.get_default_host_parameter(nil)).to eq Hash.new
      end
    end

    context "when new run is created" do

      it "return the host parameters of the last created run" do
        host_parameters = @sim.get_default_host_parameter(@host)
        # => {"param1"=>nil, "param2"=>"XXX"}
        host_parameters["param2"] = "YYY"
        run = @sim.parameter_sets.first.runs.first
        anl = run.analyses.build( analyzer: @azr, host_parameters: host_parameters, submitted_to: @host)
        expect {
          anl.save
        }.to change {
          @azr.reload.get_default_host_parameter(@host)["param2"]
        }.from("XXX").to("YYY")
      end

      it "return {} as default_host_parameter for manual submission" do
        run = @sim.parameter_sets.first.runs.first
        anl = run.analyses.build( analyzer: @azr, submitted_to: nil )
        expect(@azr.get_default_host_parameter(nil)).to eq Hash.new
      end
    end
  end
end
