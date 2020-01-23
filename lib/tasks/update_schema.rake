namespace :db do

  desc "Update schema"
  task :update_schema => :environment do
    $stderr.puts "updating schema..."

    q = Analysis.where(parameter_set: nil)
    progressbar = ProgressBar.create(total: q.count, format: "%t %B %p%% (%c/%C)")
    q.each do |anl|
      analyzable = anl.analyzable
      if analyzable.is_a?(Run)
        anl.update_attribute(:parameter_set_id, analyzable.parameter_set.id)
      elsif analyzable.is_a?(ParameterSet)
        anl.update_attribute(:parameter_set_id, analyzable.id)
      end
      progressbar.increment
    end

    q = Run.where(priority: nil)
    progressbar = ProgressBar.create(total: q.count, format: "%t %B %p%% (%c/%C)")
    q.each do |run|
      run.timeless.update_attribute(:priority, 1)
      progressbar.increment
    end

    q = Host.where(status: nil)
    progressbar = ProgressBar.create(total: q.count, format: "%t %B %p%% (%c/%C)")
    q.each do |host|
      host.timeless.update_attribute(:status, :enabled)
      progressbar.increment
    end

    q = Run.where(status: :cancelled)
    progressbar = ProgressBar.create(total: q.count, format: "%t %B %p%% (%c/%C)")
    q.each do |run|
      run.destroy
      progressbar.increment
    end
    q = Analysis.where(status: :cancelled)
    progressbar = ProgressBar.create(total: q.count, format: "%t %B %p%% (%c/%C)")
    q.each do |anl|
      anl.destroy
      progressbar.increment
    end

    client = Mongoid::Clients.default
    if client.collections.find {|col| col.name== "worker_logs" }
      raise "collection is not capped" unless client["worker_logs"].capped?
    else
      client.command(create: "worker_logs", capped: true, size: 1048576)
      $stderr.puts "capped collection worker_logs was created"
    end

    q = Simulator.where(to_be_destroyed: nil)
    progressbar = ProgressBar.create(total: q.count, format: "%t %B %p%% (%c/%C)")
    q.each do |sim|
      sim.update_attribute(:to_be_destroyed, false)
      progressbar.increment
    end

    q = Analyzer.where(to_be_destroyed: nil)
    progressbar = ProgressBar.create(total: q.count, format: "%t %B %p%% (%c/%C)")
    q.each do |azr|
      azr.update_attribute(:to_be_destroyed, false)
      progressbar.increment
    end

    # to fix issue #460
    q = Simulator.where(:h.exists => true)
    progressbar = ProgressBar.create(total: q.count, format: "%t %B %p%% (%c/%C)")
    q.each do |sim|
      sim.unset(:h)
      progressbar.increment
    end

    q = Analyzer.where(:h.exists => true)
    progressbar = ProgressBar.create(total: q.count, format: "%t %B %p%% (%c/%C)")
    q.each do |azr|
      azr.unset(:h)
      progressbar.increment
    end

    # replace boolean parameters with integers
    def bool_to_int(x)
      if x==true;1;elsif x==false;0;else; x;end
    end
    def update_parameter_definition(sim_azr)
      sim_azr.parameter_definitions.each do |pdef|
        if pdef.type == 'Boolean'
          pdef.update_attribute(:type, 'Integer')
          pdef.update_attribute(:default, bool_to_int(pdef.default))
        end
      end
    end
    sims_with_boolean_param = Simulator.all.each.select do |sim|
      sim.parameter_definitions.each.find {|pdef| pdef.type == 'Boolean'}
    end
    sims_with_boolean_param.each do |sim|
      progressbar = ProgressBar.create(total: sim.parameter_sets.count, format: "%t %B %p%% (%c/%C)")
      sim.parameter_sets.each do |ps|
        mapped = ps.v.map {|k,v| [k,bool_to_int(v)]}
        ps.update_attribute(:v, Hash[mapped])
        progressbar.increment
      end
      update_parameter_definition(sim)
    end
    azrs_with_boolean_param = Analyzer.all.each.select do |azr|
      azr.parameter_definitions.each.find {|pdef| pdef.type == 'Boolean'}
    end
    azrs_with_boolean_param.each do |azr|
      progressbar = ProgressBar.create(total: azr.analyses.count, format: "%t %B %p%% (%c/%C)")
      azr.analyses.each do |anl|
        mapped = anl.parameters.map {|k,v| [k,bool_to_int(v)]}
        anl.update_attribute(:parameters, Hash[mapped])
        progressbar.increment
      end
      update_parameter_definition(azr)
    end

  # webhook is created when there is no webhook in MongoDB
  Webhook.create() if Webhook.count == 0
  end
end
