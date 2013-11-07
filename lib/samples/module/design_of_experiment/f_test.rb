require 'pp'

module FTest

  def self.eff_facts(ps_array)

    @mean = 0
    @ss = 0
    @count = 0

    ps_array.each do |ps|
      cycle_array = cycles(ps)
      @mean += cycle_array.inject(:+)
      @ss += cycle_array.map {|x| x*x}.inject(:+)
      @count += cycle_array.size
    end

    @ct = @mean * @mean / @count.to_f
    @mean /= @count.to_f

    effFacts = ["noise", "num_games"].map do |parameter_key|
      effFact ={}
      effFact[:name] = parameter_key
      effFact[:results] = {}
      ps_array.each do |ps|
        effFact[:results][ps.v[parameter_key]] ||= []
        effFact[:results][ps.v[parameter_key]] += cycles(ps)
      end

      effFact[:effect] = 0.0
      effFact[:results].each_value do |v|
        effFact[:effect] += (v.inject(:+) ** 2).to_f / v.size
      end
      effFact[:effect] -= @ct
      effFact[:free] = 1
      effFact
    end

    @s_e = @ss - (@ct + effFacts.inject(0) {|sum,ef| sum + ef[:effect]})
    @e_f = @count - 1
    effFacts.each do |ef|
      @e_f -= ef[:free]
    end

    @e_v = @s_e / @e_f
    effFacts.each do |fact|
      fact[:f_value] = fact[:effect] / @e_v
    end

    result = {}
    effFacts.each do |ef|
      result[ ef[:name] ] = ef
      result[ ef[:name] ].delete(:name)
    end

    result
  end

  private
  def self.cycles(ps)
    ps.runs.map {|run| run.analyses.first.result["Cycles"]}
  end

end

if $0 == __FILE__
  ps_array = [
      ParameterSet.where("v.noise" => 0.5, "v.num_games" => 10).first,
      ParameterSet.where("v.noise" => 0.5, "v.num_games" => 9).first,
      ParameterSet.where("v.noise" => 0.0, "v.num_games" => 10).first,
      ParameterSet.where("v.noise" => 0.0, "v.num_games" => 9).first
    ]

  pp FTest.eff_facts(ps_array)
end