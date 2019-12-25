class Webhook
  include Mongoid::Document

  WEBHOOK_CONDITION = {0=>:all_finished, 1=>:each_ps_finished}

  field :webhook_url, type: String, default: ""
  field :webhook_condition, type: Symbol , default: WEBHOOK_CONDITION[1]
  field :webhook_triggered, type: Hash, default: {} # save conditios: {ps_id => {created: 0, submitted: 0, running: 0, finished: 0, failed: 0}}

  belongs_to :simulator

  private
  def http_post(url, data)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    req = Net::HTTP::Post.new(url)
    req.set_form_data(data)
    res = http.request(req)
    return res
  end

  private
  def run
    trigger_condition = {}
    ParameterSet.runs_status_count_batch(simulator.parameter_sets).each do |key, val|
      trigger_condition[key.to_s] = val
    end
    return if trigger_condition == self.webhook_triggered
    return if self.webhook_url.length == 0

    ps_ids = trigger_condition.keys
    ps_status = ps_ids.map do |ps_id|
      [:created, :submitted, :running].map do |sym|
        trigger_condition[ps_id][sym]
      end.inject(:+)
    end
    # when the condition is all_finished
    if self.webhook_condition == WEBHOOK_CONDITION[0] and ps_status.inject(:+) == 0
      url = "/" + simulator.id.to_s
      sim_name = simulator.name
      payload={
        "username": "oacis bot",
        "icon_url": "https://slack.com/img/icons/app-57.png"
      }
      payload["text"] = <<~EOS
        This is posted by #oacis.
      EOS
      payload["text"] += <<~EOS
        Info: All run on <a href="#{url}">Simulator("#{simulator.id.to_s}")</a> was finished.
      EOS
      res = http_post(self.webhook_url, {"payload"=>payload})
    end

    # when the condition is each_ps_finished
    if self.webhook_condition == WEBHOOK_CONDITION[1]
      triggered_ps_ids = ps_ids.map.with_index do |ps_id, i|
        id = ps_id
        if self.webhook_triggered[ps_id]
          old_status = [:created, :submitted, :running].map do |sym| self.webhook_triggered[ps_id][sym] end.inject(:+)
          id = nil unless ps_status[i] == 0 and old_status > 0
        else
          id = nil unless ps_status[i] == 0
        end
        id
      end.compact
      payload={
        "username": "oacis bot",
        "icon_url": "https://slack.com/img/icons/app-57.png"
      }
      payload["text"] = <<~EOS
        This is posted by #oacis.
      EOS
      triggered_ps_ids.each do |ps_id|
        url = "/" + simulator.id.to_s + "/" + ps_id
        payload["text"] += <<~EOS
          Info: All run on <a href="#{url}">ParameterSet("#{ps_id}")</a> was finished.
        EOS
      end
      if triggered_ps_ids.size > 0
        res = http_post(self.webhook_url, {"payload"=>payload})
      end
    end

    # save the trigger_condition
    self.update_attribute(:webhook_triggered, trigger_condition)
  end
end
