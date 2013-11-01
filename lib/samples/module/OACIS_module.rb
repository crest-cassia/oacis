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
      generated_runs = generate_runs
      wait_runs( generated_runs )
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
      runs_finished = generated_runs.all? {|run|
        run.reload unless run.status == :finished or run.status == :failed
        if run.status == :failed
          raise "Run #{run} failed"
        elsif run.status == :finished
          all_analyzer_finished( run )
        else
          false
        end
      }
      break if runs_finished
      sleep WAIT_INTERVAL
    end
  end

  def all_analyzer_finished( run )
    auto_run_analyzers = run.simulator.analyzers.where(type: :on_run, auto_run: :yes)
    auto_run_analyzers.all? do |azr|
      anl = run.analyses.where(analyzer: azr).last
      if anl and anl.status == :failed
        raise "Analysis #{anl} failed" if anl.status == :failed
      end
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
