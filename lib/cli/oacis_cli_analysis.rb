class OacisCli < Thor

  desc 'analyses_template', "print analyses parameters"
  method_option :simulator,
    type:     :string,
    aliases:  '-s',
    desc:     'simulator ID or path to simulator_id.json',
    required: true
  method_option :output,
    type:     :string,
    aliases:  '-o',
    desc:     'output json file (run_ids.json)',
    required: true
  def analyses_template
    sim = get_simulator(options[:simulator])
    analyzer_list = sim.analyzers.map {|anz| {"analyzer_id"=>anz.id.to_s}}

    return if options[:dry_run]
    File.open(options[:output], 'w') do |io|
      io.puts JSON.pretty_generate(analyzer_list)
    end
  end

  desc 'create_analyses', "create analyses"
  method_option :parameter_sets,
    type:     :string,
    aliases:  '-p',
    desc:     'path to parameter_set_ids.json',
    required: false
  method_option :runs,
    type:     :string,
    aliases:  '-r',
    desc:     'path to run_ids.json',
    required: false
  method_option :analyzers,
    type:     :string,
    aliases:  '-a',
    desc:     'path to analyzer_ids.json',
    required: true
  method_option :number_of_analyses,
    type:     :numeric,
    aliases:  '-n',
    desc:     'analyses are created up to this number',
    default:  1
  method_option :output,
    type:     :string,
    aliases:  '-o',
    desc:     'output file (analysis_ids.json)',
    required: true
  def create_analyses
    raise "number_of_analyses must be a Integer(>0)" if options[:number_of_analyses] <= 0
    analyses = []
    created_analyses = []
    get_analyzers(options[:analyzers]).each do |anz|
      if anz.type == :on_run
        sim = Simulator.find(anz.simulator_id)
        runs = sim.runs.where(status: :finished)
        runs = runs.in(id: get_runs(options[:runs]).map(&:id) ) if options[:runs]
        runs.each do |run|
          analyses += run.analyses.limit(options[:number_of_analyses])
          (options[:number_of_analyses].to_i - run.analyses.count).times do |i|
            anl = run.analyses.build
            anl.analyzer_id = anz.id
            analyses << anl
            created_analyses << anl
          end
        end
      elsif anz.type == :on_parameter_set
        sim = Simulator.find(anz.simulator_id)
        parameter_sets = sim.parameter_sets
        parameter_sets = parameter_sets.in(id: get_parameter_sets(options[:parameter_sets]).map(&:id) ) if options[:parameter_sets]
        parameter_sets = parameter_sets.select {|ps| ps.runs_status_count[:finished] == ps.runs.count}
        parameter_sets.each do |ps|
          analyses += ps.analyses.limit(options[:number_of_analyses])
          (options[:number_of_analyses].to_i - ps.analyses.count).times do |i|
            anl = ps.analyses.build
            anl.analyzer_id = anz.id
            analyses << anl
            created_analyses << anl
          end
        end
      end
    end

    progressbar = ProgressBar.create(total: created_analyses.size, format: "%t %B %p%% (%c/%C)")
    if options[:verbose]
      progressbar.log "Number of parameter_sets : #{created_analyses.count}"
    end

    created_analyses.each_with_index.map do |anl, idx|
      if anl.valid?
        anl.save! unless options[:dry_run]
      else
        if anl.analyzable_type == "Run"
          progressbar.log "Failed to create an Analysis with Analyzer #{anl.analyzer_id} on Run #{anl.analyzable_id}"
        elsif anl.analyzable_type == "ParameterSet"
          progressbar.log "Failed to create an Analysis with Analyzer #{anl.analyzer_id} on ParameterSet #{anl.analyzable_id}"
        end
        progressbar.log anl.errors.full_messages
        raise "failed to create an Analysis"
      end
      progressbar.increment
    end

  ensure
    write_analysis_ids_to_file(options[:output], analyses) unless options[:dry_run]
  end

  private
  def write_analysis_ids_to_file(path, analyses)
    return unless analyses.present?
    File.open(path, 'w') {|io|
      ids = analyses.map {|anl| "  #{{'analysis_id' => anl.id.to_s}.to_json}"}
      io.puts "[", ids.join(",\n"), "]"
      io.flush
    }
  end

  public
  desc 'analysis_status', "print analysis status"
  method_option :analysis_ids,
    type:     :string,
    aliases:  '-r',
    desc:     'target analyses',
    required: true
  def analysis_status
    analyses = get_analyses(options[:analysis_ids])
    counts = {total: analyses.count}
    [:created,:submitted,:running,:failed,:finished].each do |status|
      counts[status] = analyses.count {|anl| anl.status == status}
    end
    $stdout.puts JSON.pretty_generate(counts)
  end

  desc 'destroy_analyses', "destroy analyses"
  method_option :analyzers,
    type:     :string,
    aliases:  '-a',
    desc:     'path to analyzer_ids.json',
    required: true
  method_option :query,
    type:     :hash,
    aliases:  '-q',
    desc:     'query of analysis specified as Hash (e.g. --query=status:failed simulator_version=0.0.1)',
    required: true
  def destroy_analyses
    analyses = []
    get_analyzers(options[:analyzers]).each do |anz|
      analyses += find_analyses(anz, options[:query]).to_a
    end

    if analyses.count == 0
      say("No analyses are found.")
      return
    end

    if options[:verbose]
      say("Found analyses: #{analyses.map(&:id).to_json}")
    end

    if yes?("Destroy #{analyses.count} analyses?")
      progressbar = ProgressBar.create(total: analyses.count, format: "%t %B %p%% (%c/%C)")
      analyses.each do |anl|
        anl.destroy
        progressbar.increment
      end
    end
  end

  desc 'replace_analyses', "replace analyses"
  method_option :analyzers,
    type:     :string,
    aliases:  '-a',
    desc:     'path to analyzer_ids.json',
    required: true
  method_option :query,
    type:     :hash,
    aliases:  '-q',
    desc:     'query of analysis specified as Hash (e.g. --query=status:failed simulator_version=0.0.1)',
    required: true
  def replace_analyses
    analyses = []
    get_analyzers(options[:analyzers]).each do |anz|
      analyses += find_analyses(anz, options[:query]).to_a
    end

    if analyses.count == 0
      say("No analyses are found.")
      return
    end

    if options[:verbose]
      say("Found analyses: #{analyses.map(&:id).to_json}")
    end

    if yes?("Replace #{analyses.count} analyses with new ones?")
      progressbar = ProgressBar.create(total: analyses.count, format: "%t %B %p%% (%c/%C)")
      analyses.each do |anl|
        if anl.analyzable_type == "Run"
          new_analysis = Run.find(anl.analyzable_id).analyses.build
          new_analysis.parameters = anl.parameters
          new_analysis.analyzer_id = anl.analyzer_id
        elsif anl.analyzable_type == "ParameterSet"
          new_analysis = ParameterSet.find(anl.analyzable_id).analyses.build
          new_analysis.parameters = anl.parameters
          new_analysis.analyzer_id = anl.analyzer_id
        end
        if new_analysis.save
          anl.destroy
        else
          progressbar.log "Failed to create Analysis #{new_analysis.errors.full_messages}"
        end
        progressbar.increment
      end
    end
  end

  private
  def find_analyses(analyzer, query)
    unless query["status"]
      say("query must have 'status' key", :red)
      raise "invalid query"
    end
    analyses = Analysis.where(analyzer_id: analyzer.id.to_s)
    if stat = query["status"]
      analyses = analyses.where(status: stat.to_sym)
    end
    raise "No analysis is found with status:#{stat}" if analyses.count == 0
    analyses
  end
end
