namespace :daemon do

  SERVER_PID = "tmp/pids/server.pid"
  RESQUE_PID = "tmp/pids/resque.pid"
  RESQUE_SCHEDULER_PID = "tmp/pids/resque_scheduler.pid"

  desc "start daemons"
  task :start do
    if File.exist?(SERVER_PID) and File.open(SERVER_PID).gets.present?
      $stderr.puts "server is already running: #{SERVER_PID}"
    else
      cmd = "bundle exec rails s -d"
      puts cmd
      system(cmd)
    end

    if File.exist?(RESQUE_SCHEDULER_PID) and File.open(RESQUE_SCHEDULER_PID).gets.present?
      $stderr.puts "scheduler is already running: #{RESQUE_SCHEDULER_PID}"
    else
      cmd = "bundle exec rake resque:scheduler PIDFILE=./tmp/pids/resque_scheduler.pid BACKGROUND=yes"
      puts cmd
      system(cmd)
    end

    if File.exist?(RESQUE_PID) and File.open(RESQUE_PID).gets.present?
      $stderr.puts "resque is already running: #{RESQUE_PID}"
    else
      cmd = "bundle exec rake resque:work QUEUE='*' VERBOSE=1 PIDFILE=./tmp/pids/resque.pid BACKGROUND=yes"
      puts cmd
      system(cmd)
    end
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

    [RESQUE_PID, RESQUE_SCHEDULER_PID].each do |pidfile|
      if File.exist?(pidfile)
        pid = File.open(pidfile, "r").gets
        if pid.present?
          cmd = "kill -QUIT #{pid.chomp}"
          puts cmd
          system(cmd)
          FileUtils.rm(pidfile)
        end
      else
        $stderr.puts "#{pidfile} is not found"
      end
    end
  end

  desc "restart daemons"
  task :restart do
    Rake::Task['daemon:stop'].invoke
    Rake::Task['daemon:start'].invoke
  end
end
