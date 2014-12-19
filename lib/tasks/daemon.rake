namespace :daemon do

  SERVER_PID = "tmp/pids/server.pid"

  desc "start daemons"
  task :start do
    Rake::Task['db:update_schema'].invoke

    threads = []
    threads << Thread.new do
      if is_server_running?
        $stderr.puts "server is already running: #{SERVER_PID}"
      else
        cmd = "bundle exec rails s -d"
        puts cmd
        system(cmd)
      end
    end

    if AcmProto::Application.config.user_config["read_only"]
      $stderr.puts "OACIS_READ_ONLY mode is enabled"
    else
      threads << Thread.new do
        cmd = "bundle exec ruby -r #{Rails.root.join('config','environment.rb')} #{Rails.root.join('app', 'workers', 'job_worker.rb')} start"
        system(cmd)
      end
      threads << Thread.new do
        cmd = "bundle exec ruby -r #{Rails.root.join('config','environment.rb')} #{Rails.root.join('app', 'workers', 'analyzer_worker.rb')} start"
        system(cmd)
      end
      threads << Thread.new do
        cmd = "bundle exec ruby -r #{Rails.root.join('config','environment.rb')} #{Rails.root.join('app', 'workers', 'service_worker.rb')} start"
        system(cmd)
      end
    end

    threads.each {|t| t.join }
  end

  desc "stop daemons"
  task :stop do
    threads = []
    threads << Thread.new do
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
    end

    threads << Thread.new do
      cmd = "bundle exec ruby -r #{Rails.root.join('config','environment.rb')} #{Rails.root.join('app', 'workers', 'job_worker.rb')} stop"
      system(cmd)
    end

    threads << Thread.new do
      cmd = "bundle exec ruby -r #{Rails.root.join('config','environment.rb')} #{Rails.root.join('app', 'workers', 'analyzer_worker.rb')} stop"
      system(cmd)
    end

    threads << Thread.new do
      cmd = "bundle exec ruby -r #{Rails.root.join('config','environment.rb')} #{Rails.root.join('app', 'workers', 'service_worker.rb')} stop"
      system(cmd)
    end

    threads.each {|t| t.join }
  end

  desc "restart daemons"
  task :restart do
    Rake::Task['daemon:stop'].invoke
    sleep 0.5
    Rake::Task['daemon:start'].invoke
  end

  def is_process_running?(pid, pname)
    cmd = "pgrep -l -f \"#{pname}\""
    IO.popen(cmd) do |f|
      f.each do |line|
        return true if line=~/^#{pid}/ and line=~/#{pname}/
      end
    end

    return false
  end

  def is_server_running?
    return false unless File.exist?(SERVER_PID)

    return false unless File.open(SERVER_PID).gets.present?

    pid=File.open(SERVER_PID).gets.chomp
    pname="rails s -d"
    is_process_running?(pid, pname)
  end
end
