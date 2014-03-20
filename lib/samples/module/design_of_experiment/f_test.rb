require 'pp'

module FTest


  #[
  #  {:name=>0,
  #   :results=>{
  #                0.2=>[
  #                       -0.483285
  #                       ...,
  #                       0.484342
  #                     ],
  #                0.6=>[
  #                       -0.994595,
  #                       ...,
  #                       0.994443
  #                     ]
  #              }
  #   :effect=>1.4620500000005297e-07,
  #   :free=>1,
  #   :f_value=>1.9038296239370828e-06
  #  },
  #  {name=>1,
  #  ...
  #]
  def self.eff_facts(f_block)

    #f_block = {
    #             keys: ["beta", "H"],
    #             ps: [
    #                   {v: [0.2, -1.0], result: [-0.483285, -0.484342, -0.483428]},
    #                   ...
    #                 ],
    #          }

    @mean = 0
    @ss = 0
    @count = 0

    f_block[:ps].each do |ps|
      cycle_array = ps[:result]
      @mean += cycle_array.inject(:+)
      @ss += cycle_array.map {|x| x*x}.inject(:+)
      @count += cycle_array.size
    end

    @ct = @mean * @mean / @count.to_f
    @mean /= @count.to_f

    effFacts = []
    f_block[:keys].each_with_index do |key, index|
      effFact = {}
      effFact[:name] = index
      effFact[:results] = {}

      f_block[:ps].each do |ps|
        effFact[:results][ps[:v][index]] ||= []
        effFact[:results][ps[:v][index]] += ps[:result]
      end

      effFact[:effect] = 0.0
      effFact[:results].each_value do |v|
        effFact[:effect] += (v.inject(:+) ** 2).to_f / v.size
      end
      effFact[:effect] -= @ct
      effFact[:free] = 1
      effFacts << effFact
    end

    @s_e = @ss - (@ct + effFacts.inject(0) {|sum,ef| sum + ef[:effect]})
    @e_f = @count - 1
    effFacts.each do |ef|
      @e_f -= ef[:free]
    end

    @e_f = 1 if @e_f == 0 # TODO
    @e_v = @s_e / @e_f
    effFacts.each do |fact|
      fact[:f_value] = fact[:effect] / @e_v
    end

    effFacts
  end

  private
  def self.cycles(ps)
    ps.runs.map {|run| run.analyses.only("result").first.result["Cycles"]}
  end
end

if $0 == __FILE__
  ps_array = [
      ParameterSet.where("v.noise" => 0.5, "v.num_games" => 10).first,
      ParameterSet.where("v.noise" => 0.5, "v.num_games" => 9).first,
      ParameterSet.where("v.noise" => 0.0, "v.num_games" => 10).first,
      ParameterSet.where("v.noise" => 0.0, "v.num_games" => 9).first
    ]

  pp FTest.eff_facts(ps_array, ["noise", "num_games"])
end
