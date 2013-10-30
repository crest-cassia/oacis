require 'json'

class OacisModule

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
      dump_serialized_data( "_output.json" )
      break if finished?
    end
  end

  def select_next_parameter_sets
    raise "IMPLEMENT ME"
  end

  def generate_parameter_sets_and_runs( next_jobs )
    raise "IMPLEMENT ME"
  end

  def wait_runs( generated_runs )
    auto_run_analyzers = Analyzer.where(type: :on_run, auto_run: :yes)
    loop do
      finished = generated_runs.all? {|run|
        run.reload unless run.status == :finished or run.status == :failed
        if run.status == :failed
          raise "Run #{run} failed"
        elsif run.status == :finished
          all_analyzer_finished = auto_run_analyzers.all? do |azr|
            anl = run.analyses.where(analyzer: azr).first
            if anl and anl.status == :failed
              raise "Analysis #{anl} failed" if anl.status == :failed
            end
            anl and anl.status == :finished
          end
          all_analyzer_finished
        else
          false
        end
      }
      break if finished
      sleep 5
    end
  end

  def evaluate_runs
    raise "IMPLEMENT ME"
  end

  def finished?
    raise "IMPLEMENT ME"
  end

  def dump_serialized_data( output_file )
    raise "IMPLEMENT ME"
  end
end
