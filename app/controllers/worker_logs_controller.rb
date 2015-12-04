class WorkerLogsController < ApplicationController
  def index
    @logs = WorkerLog.all.desc('$natural').where(l: {'$gt': 0}).limit(100)
  end

  def _contents
    @logs = WorkerLog.all.desc('$natural').where(l: {'$gt': 0}).limit(100)
    render partial: 'table_contents', layout: false
  end
end
