class AnalyzerRunner

  INPUT_JSON_FILENAME = '_input.json'
  INPUT_FILES_DIR = '_input'
  OUTPUT_JSON_FILENAME = '_output.json'

  def self.perform(logger)
    Analysis.where(status: :cancelled).each do |anl|
      logger.info("Deleting cancelled analysis: #{anl.id}")
      anl.destroy(true)
    end
    Analysis.where(status: :created).each do |anl|
      logger.info("Analyzing #{anl.id}")
      work_dir = anl.dir  # UPDATE ME: a tentative implementation
      output = run_analysis(anl, work_dir)
      include_data(anl, work_dir, output)
    end
  rescue => ex
    logger.error("Error in AnalyzerRunner: #{ex.inspect}")
  end

  private
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
        output[:result] = parse_output_json
        remove_inputs
      }
    }
    output[:cpu_time] = tms.cutime
    output[:real_time] = tms.real
    output
  end

  # prepare input files into the current directory
  def self.prepare_inputs(arn)
    File.open(INPUT_JSON_FILENAME, 'w') do |f|
      f.write(JSON.pretty_generate(arn.input))
    end

    FileUtils.mkdir_p(INPUT_FILES_DIR)
    arn.input_files.each do |dir, inputs|
      output_dir = File.join(INPUT_FILES_DIR, dir)
      FileUtils.mkdir_p(output_dir)
      inputs.each do |input|
        FileUtils.cp_r(input, output_dir)
      end
    end
  end

  # remove input files into the current directory
  def self.remove_inputs
    FileUtils.rm(INPUT_JSON_FILENAME) if File.exist?(INPUT_JSON_FILENAME)
    FileUtils.rm_rf(INPUT_FILES_DIR) if Dir.exist?(INPUT_FILES_DIR)
  end

  def self.parse_output_json
    jpath = OUTPUT_JSON_FILENAME
    if File.exist?(jpath)
      return JSON.parse(IO.read(jpath))
    else
      return nil
    end
  end

  def self.include_data(arn, work_dir, output)
    if arn.status == :cancelled
      arn.destroy(true)
    else
      # do NOT copy _input/ and _input.json
      arn.update_status_finished(output)
    end
  end
end