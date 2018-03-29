class WorkerLogsController < ApplicationController
  def index
    @filtering = false
    @level = '-10'
    @tstart = ''
    @tend = ''
    @kwd = ''
    if params['commit'] == nil
      @logs = WorkerLog.all.desc('$natural').where(l: {'$gt': 0}).limit(100)
      return
    end

    @filtering = true
    query_level = nil
    query_tstart = nil
    query_tend = nil
    query_kwd = nil
    if params['severity'] != nil && params['severity'] != ''
      @level = params['severity']
      query_level = {l: {'$gt': params['severity'].to_i}}
    end
    if params['duration_start'] != nil && params['duration_start'] != ''
      @tstart = params['duration_start']
      query_tstart = {created_at: {'$gt': params['duration_start'].in_time_zone}}
    end
    if params['duration_end'] != nil && params['duration_end'] != ''
      @tend = params['duration_end']
      query_tend = {created_at: {'$lt': params['duration_end'].in_time_zone}}
    end
    if params['match_keyword'] != nil && params['match_keyword'] != ''
      ctx_kwd = params['match_keyword']
      @kwd = params['match_keyword']
      query_kwd = {m: /#{ctx_kwd}/}
    end

    query_set = [query_level, query_tstart, query_tend, query_kwd]
    @logs = WorkerLog.all.desc('$natural').all_of(query_set)
  end

  def _contents
    @logs = WorkerLog.all.desc('$natural').where(l: {'$gt': 0}).limit(100)
    render partial: 'table_contents', layout: false
  end
end
