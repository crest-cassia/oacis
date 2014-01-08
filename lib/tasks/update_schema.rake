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
  end
end
