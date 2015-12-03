class WorkerLogsController < ApplicationController
  def index
    @logs = WorkerLog.all.desc('$natural').limit(100)
  end
end
