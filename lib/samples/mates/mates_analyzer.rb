require 'json'

def output_json
  sum_of_time=0
  sum_of_length=0
  sum_of_velocity=0
  vehicle_count=0

  File.open('result/vehicle_distance.txt', 'r').each do |line| 
    data = line.split(",")
    if data[2].to_i > 0
      sum_of_time += data[2].to_i
      sum_of_length += data[1].to_i
      sum_of_velocity += data[1].to_f/data[2].to_f
      vehicle_count += 1
    end
  end

  h = {}
  h["Vehicle"] = {}
  h["Vehicle"]["Total_TripTime"]=0.001*sum_of_time #(sec)
  h["Vehicle"]["Total_TripLength"]=sum_of_velocity.to_f #(m)
  h["Vehicle"]["Average_TripVelocity"]=(3600.0*sum_of_velocity/vehicle_count.to_f) #3600*(m/msec)=(km/h)
  h["Vehicle"]["Total_Count"]=vehicle_count.to_i
  io = File.open("_output.json", 'w')
  io.print h.to_json
  io.close
end

output_json