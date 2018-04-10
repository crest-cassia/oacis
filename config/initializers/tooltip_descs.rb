require 'json'

File.open(Rails.root.join("config/tooltip_descs.json")) do |file|
  TOOLTIP_DESCS = JSON.load(file)
end
