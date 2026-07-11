# Pre-Rails-5 behaviors this app still relies on, kept explicit across
# config.load_defaults upgrades.
Rails.application.config.action_controller.per_form_csrf_tokens = false
Rails.application.config.action_controller.forgery_protection_origin_check = false
ActiveSupport.to_time_preserves_timezone = false
