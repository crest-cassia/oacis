class Webhook
  include Mongoid::Document

  WEBHOOK_CONDITION = [:each_simulator_finished, :each_parameter_set_finished]
  WEBHOOK_STATUS = [:enabled, :disabled]

  field :webhook_url, type: String, default: ""
  field :webhook_condition, type: Symbol , default: WEBHOOK_CONDITION[0]
  field :status, type: Symbol , default: WEBHOOK_STATUS[0]
  field :webhook_triggered, type: Hash, default: {} # save conditios: {sim_id => {ps_id => {created: 0, submitted: 0, running: 0, finished: 0, failed: 0}}}
  field :status

  public
  def http_post(url, data)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.path)
    req.set_form_data(payload: data.to_json)
    res = http.request(req)
    return res
  end

  public
  def check_status_and_send(simulator, sim_status)
    ps_ids = sim_status.keys
    ps_status = ps_ids.map do |ps_id|
      [:created, :submitted, :running].map do |sym|
        sim_status[ps_id][sym.to_s]
      end.inject(:+)
    end
    # when the condition is all_finished
    if self.webhook_condition == WEBHOOK_CONDITION[0] and ps_status.inject(:+) == 0
      old_num_finished = ps_ids.map do |ps_id|
        num = self.webhook_triggered.try(:fetch, simulator.id.to_s, {}).try(:fetch, ps_id, {}).try(:fetch, "finished", 0)
      end.inject(:+)
      old_num_failed = ps_ids.map do |ps_id|
        num = self.webhook_triggered.try(:fetch, simulator.id.to_s, {}).try(:fetch, ps_id, {}).try(:fetch, "failde", 0)
      end.inject(:+)
      num_finished = ps_ids.map do |ps_id|
        num = sim_status[ps_id]["finished"]
      end.inject(:+)
      num_failed = ps_ids.map do |ps_id|
        num = sim_status[ps_id]["failed"]
      end.inject(:+)
      if (num_finished+num_failed) > (old_num_finished+old_num_failed)
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
          Info: All run on <#{url}|Simulator(#{simulator.name})> was finished.
        EOS
        res = http_post(self.webhook_url, payload)
      end
    end

    # when the condition is each_ps_finished
    if self.webhook_condition == WEBHOOK_CONDITION[1]
      triggered_ps_ids = ps_ids.map.with_index do |ps_id, i|
        id = ps_id
        id = nil if ps_status[i] > 0
        old_num_finished = self.webhook_triggered.try(:fetch, simulator.id.to_s, {}).try(:fetch, ps_id, {}).try(:fetch, "finished", 0)
        old_num_failed = self.webhook_triggered.try(:fetch, simulator.id.to_s, {}).try(:fetch, ps_id, {}).try(:fetch, "failed", 0)
        num_finished = sim_status[ps_id]["finished"]
        num_failed = sim_status[ps_id]["failed"]
        id = nil unless (num_finished+num_failed) > (old_num_finished+old_num_failed)
        id
      end.compact
      if triggered_ps_ids.size > 0
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
            Info: All run on <#{url}|ParameterSet(#{ps_id}) on Simulator(#{simulator.name})> was finished.
          EOS
        end
        res = http_post(self.webhook_url, payload)
      end
    end
  end

  def self.run
    webhook = Webhook.first
    return if webhook.webhook_url.length == 0
    return if webhook.status == :disabled
    conditions={}
    Simulator.all.each do |sim|
      next if sim.runs.count == 0 # do nothing when there is no runs on the simulator
      sim_status = {}
      ParameterSet.runs_status_count_batch(sim.parameter_sets).each do |key, val|
        h = {}
        val.each do |k ,v|
          h[k.to_s] = v
        end
        sim_status[key.to_s] = h
      end
      if sim_status != webhook.webhook_triggered[sim.id.to_s]
        webhook.check_status_and_send(sim, sim_status)
      end
      conditions[sim.id.to_s] = sim_status
    end
    webhook.webhook_triggered = conditions
    webhook.save
  end
end
