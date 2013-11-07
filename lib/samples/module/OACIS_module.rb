require 'json'

class OacisModule

  WAIT_INTERVAL = 5

  def initialize(input_data)
    raise "IMPLEMENT ME"
  end

  def run
    @num_iterations = 0
    loop do
      $stdout.puts "Iteration: #{@num_iterations}"
      wait_runs( generate_runs )
      evaluate_runs
      @num_iterations += 1
      dump_serialized_data
      break if finished?
    end
  end

  def generate_runs
    raise "IMPLEMENT ME"
  end

  def wait_runs( generated_runs )
    loop do
      runs_finished = generated_runs.all? do |run|
        run.reload unless run.status == :finished or run.status == :failed
        raise "Run #{run} failed" if run.status == :failed
        run.status == :finished and all_analyzer_finished( run )
      end
      break if runs_finished
      sleep WAIT_INTERVAL
    end
  end

  def all_analyzer_finished( run )
    auto_run_analyzers = run.simulator.analyzers.where(type: :on_run, auto_run: :yes)
    auto_run_analyzers.all? do |azr|
      anl = run.analyses.where(analyzer: azr).last
      raise "Analysis #{anl} failed" if anl and anl.status == :failed
      anl and anl.status == :finished
    end
  end

  def evaluate_runs
    raise "IMPLEMENT ME"
  end

  def finished?
    raise "IMPLEMENT ME"
  end

  def dump_serialized_data
    raise "IMPLEMENT ME"
  end
end
