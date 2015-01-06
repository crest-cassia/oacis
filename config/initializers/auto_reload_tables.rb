if AcmProto::Application.config.user_config.has_key?("auto_reload_tables")
  AUTO_RELOAD_TABLES = AcmProto::Application.config.user_config["auto_reload_tables"]
else
  AUTO_RELOAD_TABLES = true
end
