namespace :daemon do
  desc "[:start,:stop,:restart] deaemons"

  task :start do
    CMD="bundle exec rails s -d"
    puts CMD
    system(CMD)

    CMD="bundle exec rake resque:scheduler PIDFILE=./tmp/pids/resque_scheduler.pid BACKGROUND=yes"
    puts CMD
    system(CMD)

    CMD="bundle exec rake resque:work QUEUE='*' VERBOSE=1 PIDFILE=./tmp/pids/resque.pid BACKGROUND=yes"
    puts CMD
    system(CMD)
  end

  task :stop do
    PID_server=File.open("tmp/pids/server.pid","r").gets
    PID_resque=File.open("tmp/pids/resque.pid","r").gets
    PID_resque_scheduler=File.open("tmp/pids/resque_scheduler.pid","r").gets

    if PID_server.present?
      CMD="kill -INT "+PID_server
      puts CMD
      system(CMD)
    end

    if PID_resque.present?
      CMD="kill -QUIT "+PID_resque
      puts CMD
      system(CMD)
    end

    if PID_resque_scheduler.present?
      CMD="kill -QUIT "+PID_resque_scheduler
      puts CMD
      system(CMD)
    end
  end

  task :restart do
    PID_server=File.open("tmp/pids/server.pid","r").gets
    PID_resque=File.open("tmp/pids/resque.pid","r").gets
    PID_resque_scheduler=File.open("tmp/pids/resque_scheduler.pid","r").gets

    if PID_server.present?
      CMD="kill -INT "+PID_server
      puts CMD
      system(CMD)
    end

    if PID_resque.present?
      CMD="kill -QUIT "+PID_resque
      puts CMD
      system(CMD)
    end

    if PID_resque_scheduler.present?
      CMD="kill -QUIT "+PID_resque_scheduler
      puts CMD
      system(CMD)
    end

    CMD="bundle exec rails s -d"
    puts CMD
    system(CMD)

    CMD="bundle exec rake resque:scheduler PIDFILE=./tmp/pids/resque_scheduler.pid BACKGROUND=yes"
    puts CMD
    system(CMD)

    CMD="bundle exec rake resque:work QUEUE='*' VERBOSE=1 PIDFILE=./tmp/pids/resque.pid BACKGROUND=yes"
    puts CMD
    system(CMD)
  end
end
