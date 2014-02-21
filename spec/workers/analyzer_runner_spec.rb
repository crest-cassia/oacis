require 'spec_helper'

describe AnalyzerRunner do
  
  before(:each) do
    @sim = FactoryGirl.create(:simulator,
                              parameter_sets_count: 1, runs_count: 1,
                              analyzers_count: 1, run_analysis: true, parameter_set_queries_count:1
                              )
    @prm = @sim.parameter_sets.first
    @run = @prm.runs.first
    @arn = @run.analyses.first
    @azr = @arn.analyzer
    @azr.update_attribute(:command, 'echo hello')

    @logger = Logger.new($stderr)
  end

  describe ".perform" do

    context "when the status is :cancelled" do

      before(:each) do
        @arn.update_attribute(:status, :cancelled)
        @arn.save!
      end

      it "calls Analysis#destroy when status is cancelled" do
        expect {
          AnalyzerRunner.perform(@logger)
        }.to change { Analysis.count }.by(-1)
      end

      it "does not call run_analysis nor include_data methods when cancelled" do
        AnalyzerRunner.should_not_receive(:run_analysis)
        AnalyzerRunner.should_not_receive(:include_data)
        AnalyzerRunner.perform(@logger)
      end
    end

    describe ".prepare_inputs" do

      before(:each) do
        @work_dir = '__temp__'
        FileUtils.mkdir_p(@work_dir)
      end

      after(:each) do
        FileUtils.rm_r(@work_dir) if File.directory?(@work_dir)
      end

      it "writes _input.json" do
        Dir.chdir(@work_dir) {
          AnalyzerRunner.__send__(:prepare_inputs, @arn)
          input_json = '_input.json'
          File.exist?(input_json).should be_true
          parsed = JSON.parse(IO.read(input_json))
          mapped = {}
          @arn.input.each {|key, value| mapped[key.to_s] = value}
          parsed.should eq(mapped)
        }
      end

      it "writes input directory" do
        Dir.chdir(@work_dir) {
          dummy_input = @arn.analyzable.dir.join('dummy.txt')
          FileUtils.touch(dummy_input)
          @arn.should_receive(:input_files).and_return({'abc' => [dummy_input]})
          AnalyzerRunner.__send__(:prepare_inputs, @arn)
          File.directory?('_input').should be_true
          File.exist?('_input/abc/dummy.txt').should be_true
        }
      end
    end

    describe ".remove_inputs" do

      before(:each) do
        @work_dir = '__temp__'
        FileUtils.mkdir_p(@work_dir)
      end

      after(:each) do
        FileUtils.rm_r(@work_dir) if File.directory?(@work_dir)
      end

      it "remove _input.json" do
        Dir.chdir(@work_dir) {
          AnalyzerRunner.__send__(:prepare_inputs, @arn)
          input_json = '_input.json'
          File.exist?(input_json).should be_true
          AnalyzerRunner.__send__(:remove_inputs)
          File.exist?(input_json).should_not be_true
        }
      end

      it "writes input directory" do
        Dir.chdir(@work_dir) {
          dummy_input = @arn.analyzable.dir.join('dummy.txt')
          FileUtils.touch(dummy_input)
          @arn.should_receive(:input_files).and_return({'abc' => [dummy_input]})
          AnalyzerRunner.__send__(:prepare_inputs, @arn)
          File.directory?('_input').should be_true
          File.exist?('_input/abc/dummy.txt').should be_true
          AnalyzerRunner.__send__(:remove_inputs)
          File.directory?('_input').should_not be_true
          File.exist?('_input/abc/dummy.txt').should_not be_true
        }
      end
    end

    describe ".run_analysis" do

      before(:each) do
        @work_dir = '__temp__'
        FileUtils.mkdir_p(@work_dir)
      end

      after(:each) do
        FileUtils.rm_r(@work_dir)
      end

      it "updates status to 'running'" do
        @arn.should_receive(:update_status_running)
        AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
      end

      it "prepares input files" do
        AnalyzerRunner.should_receive(:prepare_inputs)
        AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
      end

      it "executes analyzer in work dir" do
        @azr.update_attribute(:command, 'pwd')
        @azr.save
        AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        dir = File.open(File.join(@work_dir, '_stdout.txt')).read.chomp
        dir.should eq(File.expand_path(@work_dir))
      end

      it "stdout and stderr outputs are redirected to '_stdout.txt' and '_stderr.txt'" do
        AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        File.exist?( File.join(@work_dir, '_stdout.txt') ).should be_true
        File.exist?( File.join(@work_dir, '_stderr.txt') ).should be_true
      end

      it "raises an exception if return code of the analyzer is not zero" do
        @azr.update_attribute(:command, 'invalid_command')
        lambda {
          AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        }.should raise_error
      end

      it "returns status of analysis" do
        @azr.update_attribute(:command, 'sleep 1')
        @azr.save
        status = AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        status[:cpu_time].should be_within(0.1).of(0.0)
        status[:real_time].should be_within(0.1).of(1.0)
      end

      it "updates result of Analysis" do
        result = {xxx: 0.1, yyy:12345}
        output_json = File.join(@work_dir, '_output.json')
        File.open(output_json, 'w') {|io| io.puts result.to_json}
        status = AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        status[:result]["xxx"].should eq(0.1)
        status[:result]["yyy"].should eq(12345)
      end

      it "updates result of Analysis when result is a numeric value" do
        result = 0.12345
        output_json = File.join(@work_dir, '_output.json')
        File.open(output_json, 'w') {|io| io.puts result}
        status = AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        status[:result].should eq({"result"=>0.12345})
      end

      it "updates result of Analysis when result is a string value" do
        result = "0.12345"
        output_json = File.join(@work_dir, '_output.json')
        File.open(output_json, 'w') {|io| io.puts "\"#{result}\""}
        status = AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        status[:result].should eq({"result"=>"0.12345"})
      end
    end

    describe ".parse_output_json" do

      before(:each) do
        @work_dir = '__temp__'
        FileUtils.mkdir_p(@work_dir)
      end

      after(:each) do
        FileUtils.rm_r(@work_dir)
      end

      it "parse '_output.json' in the current directory" do
        result = {"xxx" => 1, "yyy" => 0.25, "zzz" => "foobar"}
        Dir.chdir(@work_dir) {
          File.open('_output.json', 'w') do |f|
            f.write(JSON.pretty_generate(result))
          end
          parsed = AnalyzerRunner.__send__(:parse_output_json)
          parsed.should == result
        }
      end

      it "returns nil when _output.json is not found" do
        Dir.chdir(@work_dir) {
          parsed = AnalyzerRunner.__send__(:parse_output_json)
          parsed.should be_nil
        }
      end
    end

    describe ".include_data" do

      before(:each) do
        @work_dir = '__temp__'
        FileUtils.mkdir_p(@work_dir)
      end

      after(:each) do
        FileUtils.rm_r(@work_dir)
      end

      it "updates status to 'finished'" do
        @arn.should_receive(:update_status_finished)
        AnalyzerRunner.__send__(:include_data, @arn, @work_dir, {})
      end

      it "destroys analysis when its status is :cancelled" do
        @arn.update_attribute(:status, :cancelled)
        @arn.save!
        expect {
          AnalyzerRunner.__send__(:include_data, @arn, @work_dir, {})
        }.to change { Analysis.count }.by(-1)
      end
    end

    describe "error case" do

      before(:each) do
        @azr.update_attribute(:command, 'INVALID_COMMAND')
        @work_dir = '__temp__'
        FileUtils.mkdir_p(@work_dir)
      end

      after(:each) do
        FileUtils.rm_r(@work_dir) if File.directory?(@work_dir)
      end

      it "sets status of Analysis to failed when the return code of the command is not zero" do
        @arn.update_attribute(:status, :created)
        expect {
          AnalyzerRunner.perform(@logger)
        }.to change { @arn.reload.status }.to(:failed)
      end
    end
  end
end
