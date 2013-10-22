require 'json'

field_map = "kashiwa2"
field_t_max = 3600000
query1 = {"v.map"=> field_map}
query2 = {"v.t_max" => field_t_max}

files = []
files.push(File.open("Vehicle_Total_TripTime.dat",'w'))
files.push(File.open("Vehicle_Average_TripTime.dat",'w'))
files.push(File.open("Vehicle_Total_TripLength.dat",'w'))
files.push(File.open("Vehicle_Average_TripLength.dat",'w'))
files.push(File.open("Vehicle_Average_TripVelocity.dat",'w'))
files.push(File.open("Vehicle_Total_Count.dat",'w'))

ParameterSet.where(query1).where(query2).sort_by{|ps| ps.v["dt_1"]}.each do |ps|
  if ps.runs.count > 0 and ps.runs.first.result.present? and ps.runs.first.result["Vehicle"].present?
    files[0].print [ps.v["dt_1"], ps.v["dt_2"], ps.runs.first.result["Vehicle"]["Total_TripTime"] ].join(' ')+"\n"
    files[1].print [ps.v["dt_1"], ps.v["dt_2"], ps.runs.first.result["Vehicle"]["Average_TripTime"] ].join(' ')+"\n"
    files[2].print [ps.v["dt_1"], ps.v["dt_2"], ps.runs.first.result["Vehicle"]["Total_TripLength"] ].join(' ')+"\n"
    files[3].print [ps.v["dt_1"], ps.v["dt_2"], ps.runs.first.result["Vehicle"]["Average_TripLength"] ].join(' ')+"\n"
    files[4].print [ps.v["dt_1"], ps.v["dt_2"], ps.runs.first.result["Vehicle"]["Average_TripVelocity"] ].join(' ')+"\n"
    files[5].print [ps.v["dt_1"], ps.v["dt_2"], ps.runs.first.result["Vehicle"]["Total_Count"] ].join(' ')+"\n"
  end
end
files.each do |file|
  file.close
end

optimizer_datas = []
Dir.glob("_optimizer_data*.json").each do |file|
  unless file != "_optimizer_data.json"
    io = File.open(file,'r')
    optimizer_datas.push(JSON.load(io))
  end
end

files = []
files.push(File.open("Optimizer_iteration_best_fitness.dat",'w'))
count=0
optimizer_datas.each do |optimizer_data|
  files[0].print [optimizer_data["result"]["best"]["ps_v"]["dt_1"], optimizer_data["result"]["best"]["ps_v"]["dt_2"], optimizer_data["result"]["best"]["val"]].join(' ')
  io = File.open("Optimizer_iteration"+count.to_s+"_Average_TripTime.dat",'w')
  io2 = File.open("Optimizer_iteration"+count.to_s+"_Average_TripVelocity.dat",'w')
  optimizer_data["result"]["population"].each do |pop|
    io.print [pop["ps_v"]["dt_1"], pop["ps_v"]["dt_2"], pop["val"]].join(' ')+"\n"
    ps = ParameterSet.where(query1).where(query2).where("v.dt_1"=>pop["ps_v"]["dt_1"]).where("v.dt_2"=>pop["ps_v"]["dt_2"]).first
    io2.print [pop["ps_v"]["dt_1"], pop["ps_v"]["dt_2"], ps.runs.first.result["Vehicle"]["Average_TripVelocity"]].join(' ')+"\n"
  end
  io.close
  io2.close
end