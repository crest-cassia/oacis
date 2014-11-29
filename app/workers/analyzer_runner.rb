class AnalyzerRunner

  INPUT_JSON_FILENAME = '_input.json'
  INPUT_FILES_DIR = '_input'
  OUTPUT_JSON_FILENAME = '_output.json'

  NUM_PROCESSES = 4
  NUM_LIMIT = NUM_PROCESSES*2

  def self.perform(logger)
    Analysis.where(status: :cancelled).each do |anl|
      logger.info("Deleting cancelled analysis: #{anl.id}")
      anl.destroy(true)
    end
    anl_ids = Analysis.where(status: :created).limit(NUM_LIMIT).map(&:id)
    Mongoid::sessions.clear # before forking a process, clear Mongo session. Otherwise, invalid data may be obtained.
    Parallel.each(anl_ids, in_processes: NUM_PROCESSES) do |anl_id|
      logger.info("Analyzing #{anl_id}")
      Mongoid::Config.load!(File.join(Rails.root, 'config/mongoid.yml')) # make a new Mongo session in each process.
      anl = Analysis.find(anl_id)
      work_dir = anl.dir  # UPDATE ME: a tentative implementation
      begin
        output = run_analysis(anl, work_dir)
        include_data(anl, work_dir, output)
      rescue => ex
        logger.error("Error while analyzing #{anl.id}: #{ex.inspect}")
        anl.update_status_failed
      end
    end
  rescue => ex
    logger.error("Error in AnalyzerRunner: #{ex.inspect}")
  ensure
    # anyway, try to clear Mongoid session, then try to make a new Mongoid session
    Mongoid::sessions.clear
    Mongoid::Config.load!(File.join(Rails.root, 'config/mongoid.yml'))
  end

  private
  def self.run_analysis(arn, work_dir)
    arn.update_status_running
    output = {cpu_time: 0.0, real_time: 0.0}
    tms = Benchmark.measure {
      Dir.chdir(work_dir) {
        prepare_inputs(arn)
        put_version_text(arn)
        Bundler.with_clean_env do
          cmd = "(#{arn.analyzer.command}) 1> _stdout.txt 2> _stderr.txt"
          system(cmd)
          unless $?.to_i == 0
            raise "Rc of the analyzer is not 0, but #{$?.to_i}"
          end
        end
        output[:result] = parse_output_json
        output[:result] = {"result"=>parse_output_json} unless output[:result].is_a?(Hash)
        output[:analyzer_version] = File.open("_version.txt").read.chomp if File.exist?("_version.txt")
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
    arn.input_files.each do |input|
      FileUtils.ln_s(input, INPUT_FILES_DIR)
    end
  end

  # put _version.txt on the current directory
  def self.put_version_text(arn)
    if arn.analyzer.print_version_command.present?
      cmd = "#{arn.analyzer.print_version_command} > #{Dir.pwd}/_version.txt"
      system(cmd)
      unless $?.to_i == 0
        raise "Rc of the analyzer print version command is not 0, but #{$?.to_i}"
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
      return JSON.load(File.open(jpath))
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

