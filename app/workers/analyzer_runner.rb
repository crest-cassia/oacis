class AnalyzerRunner

  @queue = :analyzer_queue
  INPUT_JSON_FILENAME = '_input.json'
  INPUT_FILES_DIR = '_input'
  OUTPUT_JSON_FILENAME = '_output.json'

  def self.perform(type, analyzable_id, arn_id)
    arn = fetch_analysis_run_instance(type, analyzable_id, arn_id)
    work_dir = arn.dir  # UPDATE ME: a tentative implementation
    run_analysis(arn, work_dir)
    include_data(arn, work_dir)
  end

  private
  def self.fetch_analysis_run_instance(type, analyzable_id, arn_id)
    case type
    when :on_run
      analyzable = Run.find(analyzable_id)
    when :on_parameter_set
      analyzable = ParameterSet.find(analyzable_id)
    when :on_parameter_sets_group
      raise "not implemented yet..."  # IMPLEMENT ME
    else
      raise "not supported type: #{type}"
    end
    return analyzable.analysis_runs.find(arn_id)
  end

  def self.run_analysis(arn, work_dir)
    arn.update_status_running
    output = {cpu_time: 0.0, real_time: 0.0}
    tms = Benchmark.measure {
      Dir.chdir(work_dir) {
        prepare_inputs(arn)
        cmd = "#{arn.analyzer.command} 1> _stdout.txt 2> _stderr.txt"
        system(cmd)
        unless $?.to_i == 0
          raise "Rc of the simulator is not 0, but #{$?.to_i}"
        end
      }
    }
    output[:result] = parse_output_json
    output[:cpu_time] = tms.cutime
    output[:real_time] = tms.real
    arn.update_status_including(output)
  end

  # prepare input files into the current directory
  def self.prepare_inputs(arn)
    File.open(INPUT_JSON_FILENAME, 'w') do |f|
      f.write(JSON.pretty_generate(arn.input))
    end

    FileUtils.mkdir_p(INPUT_FILES_DIR)
    arn.input_files.each do |input_file|
      FileUtils.cp(input_file, INPUT_FILES_DIR)
    end
  end

  def self.parse_output_json
    jpath = OUTPUT_JSON_FILENAME
    if File.exist?(jpath)
      return JSON.parse(IO.read(jpath))
    else
      return nil
    end
  end

  def self.include_data(arn, work_dir)
    arn.update_status_finished
  end
end