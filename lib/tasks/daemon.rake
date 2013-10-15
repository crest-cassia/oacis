namespace :daemon do

  SERVER_PID = "tmp/pids/server.pid"

  desc "start daemons"
  task :start do
    if File.exist?(SERVER_PID) and File.open(SERVER_PID).gets.present?
      $stderr.puts "server is already running: #{SERVER_PID}"
    else
      cmd = "bundle exec rails s -d"
      puts cmd
      system(cmd)
    end

    cmd = "bundle exec ruby -r #{Rails.root.join('config','environment.rb')} #{Rails.root.join('app', 'workers', 'worker.rb')} start"
    system(cmd)
  end

  desc "stop daemons"
  task :stop do
    if File.exist?(SERVER_PID)
      pid = File.open(SERVER_PID, "r").gets
      if pid.present?
        cmd = "kill -INT #{pid.chomp}"
        puts cmd
        system(cmd)
      end
    else
      $stderr.puts "#{SERVER_PID} is not found"
    end

    cmd = "bundle exec ruby -r #{Rails.root.join('config','environment.rb')} #{Rails.root.join('app', 'workers', 'worker.rb')} stop"
    system(cmd)
  end

  desc "restart daemons"
  task :restart do
    Rake::Task['daemon:stop'].invoke
    sleep 0.5
    Rake::Task['daemon:start'].invoke
  end
end
