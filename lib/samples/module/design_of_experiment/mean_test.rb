require 'pp'

module MeanTest

  def self.mean_distances(ps_block)

    #ps_block = {
    #             keys: ["beta", "H"],
    #             ps: [
    #                   {v: [0.2, -1.0], result: [-0.483285, -0.484342, -0.483428]},
    #                   ...
    #                 ],
    #          }
    mean_distance = []
    ps_block[:keys].each_with_index do |key, index|
      mean = {}
      ps_block[:ps].each do |ps|
        mean[ps[:v][index]] ||= []
        mean[ps[:v][index]] += ps[:result]
      end
      means = []
      mean.each_pair do |v_val, results|
        means << results.inject(:+) / results.size
      end
      mean_distance << (means.max - means.min)
    end
    mean_distance
  end
end

