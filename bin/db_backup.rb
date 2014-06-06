#!/usr/bin/env ruby
db_name = "oacis_development"
puts "Enter a name of Simulator"
sim_name = STDIN.gets.chomp

cmd =  "mongo #{db_name} --eval \"db.simulators.find( { name: \\\"#{sim_name}\\\"}).map( function(u) { return u._id; } )\""
sim_id = `#{cmd} | tail -1`.chomp
if sim_id == ""
  puts "No such simulator is found"
  exit
end
puts "simulator_id is " +sim_id

cmd = "mongodump --db #{db_name} -o dump_#{sim_name} --collection simulators -q \"{_id: #{sim_id.gsub('"','\\"')}}\""
puts cmd
system(cmd)
cmd = "mongodump --db #{db_name} -o dump_#{sim_name} --collection parameter_sets -q \"{simulator_id: #{sim_id.gsub('"','\\"')}}\""
puts cmd
system(cmd)
cmd = "mongodump --db #{db_name} -o dump_#{sim_name} --collection runs -q \"{simulator_id: #{sim_id.gsub('"','\\"')}}\""
puts cmd
system(cmd)


cmd = "mongo #{db_name} --eval \"db.analyzers.find( { simulator_id: #{sim_id.gsub('"','\\"')}} ).map( function(u) { return u._id; } )\""
puts cmd
analyzer_ids = `#{cmd} | tail -1`.chomp
puts "analyzer_ids are " + analyzer_ids

cmd = "mongodump --db #{db_name} -o dump_#{sim_name} --collection analyzers -q \"{_id: { \\$in: [#{analyzer_ids.gsub('"','\\"')}]} }\""
puts cmd
system(cmd)
cmd = "mongodump --db #{db_name} -o dump_#{sim_name} --collection analyses -q \"{analyzer_id: { \\$in: [#{analyzer_ids.gsub('"','\\"')}]} }\""
puts cmd
system(cmd)
