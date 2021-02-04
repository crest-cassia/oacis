module JobNotificationUtil
  class << self
    include NotificationEventsHelper
    include ApplicationHelper
    include Rails.application.routes.url_helpers
    include ActionView::Helpers::UrlHelper

    def notify_job_finished(job)
      case OacisSetting.instance.notification_level
      when 1
        notify_all_jobs_in_simulator_finished(job)
      when 2
        notify_all_jobs_in_param_set_finished(job)
        notify_all_jobs_in_simulator_finished(job)
      when 3
        notify_single_job_finished(job)
        notify_all_jobs_in_param_set_finished(job)
        notify_all_jobs_in_simulator_finished(job)
      end
    end

    private

    def notify_all_jobs_in_simulator_finished(job)
      return if job.simulator.send(job.class.name.underscore.pluralize).unfinished.exists?

      NotificationEvent.create!(message: generate_all_jobs_in_simulator_finished_message(job))
    end

    def notify_all_jobs_in_param_set_finished(job)
      return if job.parameter_set.send(job.class.name.underscore.pluralize).unfinished.exists?

      NotificationEvent.create!(message: generate_all_jobs_in_param_set_finished_message(job))
    end

    def notify_single_job_finished(job)
      NotificationEvent.create!(message: generate_single_job_finished_message(job))
    end
  end
end
