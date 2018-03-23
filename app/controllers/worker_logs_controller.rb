class WorkerLogsController < ApplicationController
  def index
    @filtering = false
    @level = '-10'
    @dur_choice = '-1'
    @kwd = ''
    if params['commit'] == nil
      @logs = WorkerLog.all.desc('$natural').where(l: {'$gt': 0}).limit(100)
      return
    end

    @filtering = true
    query_level = nil
    query_duration = nil
    query_kwd = nil
    if params['severity'].present?
      @level = params['severity']
      query_level = {l: {'$gt': params['severity'].to_i}}
    end
    if params['duration'].present?
      @dur_choice = params['duration']
      bd = params['duration'].to_i
      if bd > 0
        query_duration = {created_at: {'$gt': Time.current - bd.days}}
      end
    end
    if params['match_keyword'].present?
      ctx_kwd = params['match_keyword']
      @kwd = params['match_keyword']
      query_kwd = {m: /#{ctx_kwd}/}
    end

    query_set = [query_level, query_duration, query_kwd]
    @logs = WorkerLog.all.desc('$natural').all_of(query_set).limit(500)
  end

  def _contents
    @logs = WorkerLog.all.desc('$natural').where(l: {'$gt': 0}).limit(100)
    render partial: 'table_contents', layout: false
  end
end
