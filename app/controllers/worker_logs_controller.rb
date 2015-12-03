class WorkerLogsController < ApplicationController
  def index
    @logs = WorkerLog.all.desc('$natural').where(l: {'$gt': 0}).limit(100)
  end
end
