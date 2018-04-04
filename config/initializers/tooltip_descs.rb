require 'json'

File.open("config/tooltip_descs.json") do |file|
  TOOLTIP_DESCS = JSON.load(file)
end
