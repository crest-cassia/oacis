require 'spec_helper'

describe ResultDirectory do

  before(:each) do
    @simulator = FactoryGirl.create(:simulator,
                                    parameter_sets_count: 1,
                                    runs_count: 1,
                                    analyzers_count: 1,
                                    run_analysis: true
                                    )
    @default_root = ResultDirectory::DefaultResultRoot
  end

  after(:each) do
  end

  it ".root returns root dir" do
    expect(ResultDirectory.root).to eq(@default_root)
  end

  it ".set_root sets the result root directory" do
    another_root = Rails.root.join('testdir')
    ResultDirectory.set_root(another_root)
    expect(ResultDirectory.root).to eq(another_root)
    ResultDirectory.set_root(ResultDirectory::DefaultResultRoot)
  end
  
  it ".simulator_path returns the path to the simulator directory" do
    expect(ResultDirectory.simulator_path(@simulator)).to eq(@default_root.join(@simulator.to_param))
  end

  it ".simulator_path also accepts id object" do
    expect(ResultDirectory.simulator_path(@simulator.to_param)).to eq(ResultDirectory.simulator_path(@simulator))
  end

  it ".parameter_set_path returns the path to the parameter directory" do
    prm = @simulator.parameter_sets.first
    expect(ResultDirectory.parameter_set_path(prm)).to eq(@default_root.join(@simulator.to_param, prm.to_param))
  end

  it ".parameter_path also accepts id object" do
    prm = @simulator.parameter_sets.first
    expect(ResultDirectory.parameter_set_path(prm.to_param)).to eq(ResultDirectory.parameter_set_path(prm))
  end

  it ".run_path returns the run directory" do
    prm = @simulator.parameter_sets.first
    run = prm.runs.first
    expect(ResultDirectory.run_path(run)).to eq(
      @default_root.join(@simulator.to_param, prm.to_param, run.to_param)
    )
  end

  it ".run_path also accepts id object" do
    prm = @simulator.parameter_sets.first
    run = prm.runs.first
    expect(ResultDirectory.run_path(run.to_param)).to eq(ResultDirectory.run_path(run))
  end

  it ".run_script_path returns the path to the run script" do
    prm = @simulator.parameter_sets.first
    run = prm.runs.first
    expect(ResultDirectory.run_script_path(run)).to eq(
      @default_root.join(@simulator.to_param, prm.to_param, run.to_param + '.sh')
    )
  end

  it ".analyzable_path returns the path to run for Run instance" do
    run = @simulator.parameter_sets.first.runs.first
    expect(ResultDirectory.analyzable_path(run)).to eq(ResultDirectory.run_path(run))
  end

  it ".analyzable_path returns the path to run for ParameterSet instance" do
    ps = @simulator.parameter_sets.first
    expect(ResultDirectory.analyzable_path(ps)).to eq(ResultDirectory.parameter_set_path(ps))
  end

  it ".analysis_path returns the output directory of an Analysis for :on_run type" do
    run = @simulator.parameter_sets.first.runs.first
    arn = run.analyses.first
    expect(ResultDirectory.analysis_path(arn)).to eq(
      ResultDirectory.run_path(run).join(arn.to_param)
    )
  end

  it ".manual_submission_path returns the directory containing shell scripts for manual submission" do
    expect(ResultDirectory.manual_submission_path).to eq @default_root.join("manual_submission")
  end

  it ".manual_submission_job_script_path returns the path to job script for manual submission" do
    run = @simulator.parameter_sets.first.runs.first
    expected = ResultDirectory.manual_submission_path.join(run.id.to_s + ".sh")
    expect(ResultDirectory.manual_submission_job_script_path(run)).to eq expected
  end

  it ".manual_submission_input_json_path returns the path to _input.json for manual submission" do
    run = @simulator.parameter_sets.first.runs.first
    expected = ResultDirectory.manual_submission_path.join(run.id.to_s + "_input.json")
    expect(ResultDirectory.manual_submission_input_json_path(run)).to eq expected
  end
end
