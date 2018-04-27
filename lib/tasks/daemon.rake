namespace :daemon do

  SERVER_PID = "tmp/pids/server.pid"
  RESQUE_WORKER_PID = "tmp/pids/resque_worker.pid"

  desc "start daemons"
  task :start do
    ENV['RAILS_ENV'] ||= 'production'
    Rake::Task['db:update_schema'].invoke
    Rake::Task['db:mongoid:create_indexes'].invoke
    Rake::Task['db:mongoid:remove_undefined_indexes'].invoke

    threads = []
    level = AcmProto::Application.config.user_config["access_level"] || 2
    if level == 0
      $stderr.puts "READ_ONLY mode is enabled"
    else
      threads << Thread.new do
        if is_resque_worker_running?
          $stderr.puts "resque worker is already running: #{RESQUE_WORKER_PID}"
        else
          here = File.dirname(__FILE__)
          cmd = "bundle exec ruby -r '#{Rails.root.join('config','environment.rb')}' '#{File.join(here, 'boot_resque_worker.rb')}' start"
          system(cmd)
        end
      end
    end
    threads << Thread.new do
      if is_server_running?
        $stderr.puts "server is already running: #{SERVER_PID}"
      else
        binding_ip = "127.0.0.1"
        binding_ip = "0.0.0.0" if level <= 1
        binding_ip = AcmProto::Application.config.user_config["binding_ip"] || binding_ip
        cmd = "bundle exec rails s -d -b #{binding_ip}"
        puts cmd
        system(cmd)
      end
    end

    if level == 0
      $stderr.puts "READ_ONLY mode is enabled"
    else
      here = File.dirname(__FILE__)
      threads << Thread.new do
        cmd = "bundle exec ruby -r '#{Rails.root.join('config','environment.rb')}' '#{File.join(here, 'boot_job_submitter_worker.rb')}' start"
        system(cmd)
      end
      threads << Thread.new do
        cmd = "bundle exec ruby -r '#{Rails.root.join('config','environment.rb')}' '#{File.join(here, 'boot_job_observer_worker.rb')}' start"
        system(cmd)
      end
      threads << Thread.new do
        cmd = "bundle exec ruby -r '#{Rails.root.join('config','environment.rb')}' '#{File.join(here, 'boot_service_worker.rb')}' start"
        system(cmd)
      end
    end

    threads.each {|t| t.join }
  end

  desc "stop daemons"
  task :stop do
    ENV['RAILS_ENV'] ||= 'production'
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

    here = File.dirname(__FILE__)
    threads << Thread.new do
      cmd = "bundle exec ruby -r '#{Rails.root.join('config','environment.rb')}' '#{File.join(here, 'boot_job_submitter_worker.rb')}' stop"
      system(cmd)
    end

    threads << Thread.new do
      cmd = "bundle exec ruby -r '#{Rails.root.join('config','environment.rb')}' '#{File.join(here, 'boot_job_observer_worker.rb')}' stop"
      system(cmd)
    end

    threads << Thread.new do
      cmd = "bundle exec ruby -r '#{Rails.root.join('config','environment.rb')}' '#{File.join(here, 'boot_service_worker.rb')}' stop"
      system(cmd)
    end

    threads << Thread.new do
      cmd = "bundle exec ruby -r '#{Rails.root.join('config','environment.rb')}' '#{File.join(here, 'boot_resque_worker.rb')}' stop"
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

  def is_resque_worker_running?
    return false unless File.exist?(RESQUE_WORKER_PID)

    return false unless File.open(RESQUE_WORKER_PID).gets.present?

    pid=File.open(RESQUE_WORKER_PID).gets.chomp
    pname="resque"
    is_process_running?(pid, pname)
  end
end
