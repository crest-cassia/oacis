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

    q = Run.where(status: :finished, "result": {"$ne": nil})
    progressbar = ProgressBar.create(total: q.count, format: "%t %B %p%% (%c/%C)")
    q.each do |run|
      result = run[:result]
      run.timeless.update_attribute(:result, nil)
      run.create_job_result(submittable_parameter: run.submittable_parameter, result: result)
      progressbar.increment
    end
    q = Analysis.where(status: :finished, "result": {"$ne": nil})
    progressbar = ProgressBar.create(total: q.count, format: "%t %B %p%% (%c/%C)")
    q.each do |anl|
      result = anl[:result]
      anl.timeless.update_attribute(:result, nil)
      anl.create_job_result(submittable_parameter: anl.submittable_parameter, result: result)
      anl.timeless.save!
      progressbar.increment
    end

    session = Mongoid::Sessions.default
    if session.collections.find {|col| col.name== "worker_logs" }
      raise "collection is not capped" unless session["worker_logs"].capped?
    else
      session.command(create: "worker_logs", capped: true, size: 1048576)
      $stderr.puts "capped collection worker_logs was created"
    end
  end
end
