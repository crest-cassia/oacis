class OacisCli < Thor

  desc 'analyses_template', "print analyses parameters"
  method_option :analyzer_id,
    type:     :string,
    aliases:  '-a',
    desc:     'analyzer ID',
    required: true
  method_option :output,
    type:     :string,
    aliases:  '-o',
    desc:     'output json file (anz_parameters.json)',
    required: true
  def analyses_template
    anz = Analyzer.find(options[:analyzer_id])
    mapped = anz.parameter_definitions.map {|pdef| [pdef["key"], pdef["default"]] }
    anz_parameters = Hash[mapped]

    return if options[:dry_run]
    File.open(options[:output], 'w') do |io|
      # for visibility, manually print the json object as follows
      io.puts "[", "  #{anz_parameters.to_json}", "]"
      io.flush
    end
  end

  desc 'create_analyses', "create analyses"
  method_option :analyzer_id,
    type:     :string,
    aliases:  '-a',
    desc:     'analyzer ID',
    required: true
  method_option :input,
    type:     :string,
    aliases:  '-i',
    desc:     'input file',
    required: false
  option :first_run_only,
    desc:     'create analyses only on first runs',
    required: false
  method_option :target,
    type:     :string,
    aliases:  '-t',
    desc:     'create analyses on targets(parmeter_set_ids.json or run_ids.json)',
    required: false
  method_option :output,
    type:     :string,
    aliases:  '-o',
    desc:     'output file (analysis_ids.json)',
    required: true
  def create_analyses
    raise "can not use both first_run_only option and target option" if options[:first_run_only].present? and options[:target].present?
    anz = Analyzer.find(options[:analyzer_id])
    input = options[:input] ? JSON.load(File.read(options[:input])) : [ anz.parameter_definitions.inject({}) {|h, pd| h.merge!({pd["key"]=>pd["default"]})} ]

    analyses = []
    sim = Simulator.find(anz.simulator_id)
    if anz.type == :on_run
      runs = sim.runs
      runs = runs.order_by("updated_at desc").limit(1) if options[:first_run_only]
      runs = runs.in(id: get_runs(options[:target]).map(&:id) ) if options[:target]
      runs = runs.where(status: :finished)
      input.each do |parameters|
        runs.each do |run|
          anl = run.analyses.where(analyzer: anz, parameters: parameters).first
          anl = run.analyses.build(analyzer: anz, parameters: parameters) if anl.blank?
          analyses << anl
        end
      end
    elsif anz.type == :on_parameter_set
      parameter_sets = sim.parameter_sets
      parameter_sets = parameter_sets.in(id: get_parameter_sets(options[:target]).map(&:id) ) if options[:target]
      parameter_sets = parameter_sets.select {|ps| ps.runs_status_count[:finished] == ps.runs.count}
      input.each do |parameters|
        parameter_sets.each do |ps|
          anl = ps.analyses.where(analyzer: anz, parameters: parameters).first
          anl = ps.analyses.build(analyzer: anz, parameters: parameters) if anl.blank?
          analyses << anl
        end
      end
    end
    created_analyses = analyses.select {|anl| anl.status == nil}

    progressbar = ProgressBar.create(total: created_analyses.size, format: "%t %B %p%% (%c/%C)")
    if options[:verbose]
      progressbar.log "Number of analyses : #{created_analyses.count}"
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
    return if analyses.empty?
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
    aliases:  '-a',
    desc:     'target analyses',
    required: true
  def analysis_status
    analyses = get_analyses(options[:analysis_ids])
    counts = {total: analyses.count}
    # :submitted does not exist in status of analysis
    [:created,:running,:failed,:finished].each do |status|
      counts[status] = analyses.where(status: status).count
    end
    $stdout.puts JSON.pretty_generate(counts)
  end

  desc 'destroy_analyses', "destroy analyses"
  method_option :analyzer_id,
    type:     :string,
    aliases:  '-a',
    desc:     'analyzer ID',
    required: true
  method_option :query,
    type:     :hash,
    aliases:  '-q',
    desc:     'query of analysis specified as Hash (e.g. --query=status:failed)',
    required: true
  def destroy_analyses
    anz = Analyzer.find(options[:analyzer_id])
    analyses = find_analyses(anz, options[:query])

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
  method_option :analyzer_id,
    type:     :string,
    aliases:  '-a',
    desc:     'analyzer ID',
    required: true
  method_option :query,
    type:     :hash,
    aliases:  '-q',
    desc:     'query of analysis specified as Hash (e.g. --query=status:failed)',
    required: true
  def replace_analyses
    anz = Analyzer.find(options[:analyzer_id])
    analyses = find_analyses(anz, options[:query])

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
    analyses = analyses.where(status: query["status"].to_sym)
    raise "No analysis is found with status:#{query["status"]}" if analyses.count == 0
    analyses
  end
end
