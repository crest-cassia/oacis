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
    @azr.update_attribute(:print_version_command, 'echo "v0.1.0"')

    @logger = Logger.new($stderr)
  end

  describe ".perform" do

    context "when the status is :cancelled" do

      before(:each) do
        @arn.update_attribute(:status, :cancelled)
      end

      it "calls Analysis#destroy when status is cancelled" do
        expect {
          AnalyzerRunner.perform(@logger)
        }.to change { Analysis.count }.by(-1)
      end

      it "does not call run_analysis nor include_data methods when cancelled" do
        expect(AnalyzerRunner).not_to receive(:run_analysis)
        expect(AnalyzerRunner).not_to receive(:include_data)
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
          expect(File.exist?(input_json)).to be_truthy
          parsed = JSON.parse(IO.read(input_json))
          mapped = {}
          @arn.input.each {|key, value| mapped[key.to_s] = value}
          expect(parsed).to eq(mapped)
        }
      end

      it "writes input directory" do
        Dir.chdir(@work_dir) {
          dummy_input = @arn.analyzable.dir.join('dummy.txt')
          FileUtils.touch(dummy_input)
          expect(@arn).to receive(:input_files).and_return(['dummy.txt'])
          AnalyzerRunner.__send__(:prepare_inputs, @arn)
          expect(File.directory?('_input')).to be_truthy
          expect(File.symlink?("_input/dummy.txt")).to be_truthy
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
          expect(File.exist?(input_json)).to be_truthy
          AnalyzerRunner.__send__(:remove_inputs)
          expect(File.exist?(input_json)).not_to be_truthy
        }
      end

      it "writes input directory" do
        Dir.chdir(@work_dir) {
          dummy_input = @arn.analyzable.dir.join('dummy.txt')
          FileUtils.touch(dummy_input)
          expect(@arn).to receive(:input_files).and_return([@arn.analyzable.dir])
          AnalyzerRunner.__send__(:prepare_inputs, @arn)
          expect(File.directory?('_input')).to be_truthy
          expect(File.exist?("_input/#{@arn.analyzable.to_param}/dummy.txt")).to be_truthy
          AnalyzerRunner.__send__(:remove_inputs)
          expect(File.directory?('_input')).not_to be_truthy
          expect(File.exist?("_input/#{@arn.analyzable.to_param}/dummy.txt")).not_to be_truthy
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
        expect(@arn).to receive(:update_status_running)
        AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
      end

      it "prepares input files" do
        expect(AnalyzerRunner).to receive(:prepare_inputs)
        AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
      end

      it "executes analyzer in work dir" do
        @azr.update_attribute(:command, 'pwd')
        @azr.save
        AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        dir = File.open(File.join(@work_dir, '_stdout.txt')).read.chomp
        expect(dir).to eq(File.expand_path(@work_dir))
      end

      it "executes with 'Bundler.with_clean_env' and remove RUBYLIB, GEM_HOME variables" do
        @azr.update_attribute(:command, 'export > env.txt')
        AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        env = File.open( File.join(@work_dir, 'env.txt')).read.chomp
        expect(env).not_to match /^export BUNDLE_BIN_PATH=/
        expect(env).not_to match /^export BUNDLE_GEMFILE=/
        expect(env).not_to match /^export RUBYLIB=/
        expect($1).not_to match /bundler/ if env =~ /^export RUBYOPT=(.*)$/
        expect(env).not_to match /^export GEM_HOME=/
      end

      it "stdout and stderr outputs are redirected to '_stdout.txt' and '_stderr.txt'" do
        AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        expect(File.exist?( File.join(@work_dir, '_stdout.txt') )).to be_truthy
        expect(File.exist?( File.join(@work_dir, '_stderr.txt') )).to be_truthy
      end

      it "analyzer_command may include redirection of stdout or stderr" do
        @azr.update_attribute(:command, 'pwd > pwd.txt')
        AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        dir = File.open(File.join(@work_dir, 'pwd.txt')).read.chomp
        expect(dir).to eq(File.expand_path(@work_dir))
      end

      it "raises an exception if return code of the analyzer is not zero" do
        @azr.update_attribute(:command, 'invalid_command')
        expect {
          AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        }.to raise_error
      end

      it "returns status of analysis" do
        @azr.update_attribute(:command, 'sleep 1')
        @azr.save
        status = AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        expect(status[:cpu_time]).to be_within(0.1).of(0.0)
        expect(status[:real_time]).to be_within(0.1).of(1.0)
      end

      it "updates result of Analysis" do
        result = {xxx: 0.1, yyy:12345}
        output_json = File.join(@work_dir, '_output.json')
        File.open(output_json, 'w') {|io| io.puts result.to_json}
        status = AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        expect(status[:result]["xxx"]).to eq(0.1)
        expect(status[:result]["yyy"]).to eq(12345)
      end

      it "updates result of Analysis when result is a Float" do
        result = 0.12345
        output_json = File.join(@work_dir, '_output.json')
        File.open(output_json, 'w') {|io| io.puts result}
        status = AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        expect(status[:result]).to eq({"result"=>result})
      end

      it "updates result of Analysis when result is a Boolean" do
        result = false
        output_json = File.join(@work_dir, '_output.json')
        File.open(output_json, 'w') {|io| io.puts result.to_s}
        status = AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        expect(status[:result]).to eq({"result"=>result})
      end

      it "updates result of Analysis when result is a String" do
        result = "0.12345"
        output_json = File.join(@work_dir, '_output.json')
        File.open(output_json, 'w') {|io| io.puts "\"#{result}\""}
        status = AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        expect(status[:result]).to eq({"result"=>result})
      end
 
      it "updates result of Analysis when result is a Array" do
        result = [1,2,3]
        output_json = File.join(@work_dir, '_output.json')
        File.open(output_json, 'w') {|io| io.puts result.to_json}
        status = AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        expect(status[:result]).to eq({"result"=>result})
      end

      it "write '_version.txt'" do
        status = AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        version_text = '_version.txt'
        expect(File.exist?( File.join(@work_dir, version_text) )).to be_truthy
        version = File.open(File.join(@work_dir, version_text) ).read.chomp
        expect(version).to eq("v0.1.0")
      end

      it "update analyzer_version if print_version_command exists" do
        status= AnalyzerRunner.__send__(:run_analysis, @arn, @work_dir)
        expect(status[:analyzer_version]).to eq("v0.1.0")
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
          expect(parsed).to eq(result)
        }
      end

      it "returns nil when _output.json is not found" do
        Dir.chdir(@work_dir) {
          parsed = AnalyzerRunner.__send__(:parse_output_json)
          expect(parsed).to be_nil
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
        expect(@arn).to receive(:update_status_finished)
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
