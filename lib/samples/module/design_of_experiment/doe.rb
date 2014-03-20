require 'json'
require_relative '../OACIS_module.rb'
require_relative '../OACIS_module_data.rb'
#require_relative 'f_test.rb'
require_relative 'mean_test.rb'
require_relative 'orthogonal_array'

class Doe < OacisModule

  def self.definition
    h = {}
    h["f_block_count_max"] = 1000
    h["distance_threshold"] = 0.1
    h["target_field"] = "order_parameter"
    h["concurrent_job_max"] = 30
    h
  end

  #NUM_RUNS = 5

  def initialize(input_data)
    super(input_data)
    #@sim = Simulator.where(name: "dilemma_game").first
    #raise "Simulator 'dilemma_game' is not found" unless @sim
    #@host = Host.where(name: "localhost").first
    #raise "Host 'localhost' is not found" unless @host

    @param_names = managed_parameters_table.map {|mpt| mpt["key"]}

    #noise_array = [0, 0.05]
    #num_games_array = [10, 100]

    #if input_data
    #  noise_array = input_data[@param_names[0]]
    #  num_games_array = input_data[@param_names[1]]
    #end

    @total_f_block_count = 0

    #@range_hashes = [ {@param_names[0] => noise_array, @param_names[1] => num_games_array} ]
    #@range_hashes = [
    #                  {"beta"=>[0.2, 0.6], "H"=>[-1.0, 1.0]},
    #                  ...
    #                ]
    range_hash = {}
    managed_parameters_table.each do |pd|
      range_hash[pd["key"]] = pd["range"]
    end
    get_parameter_sets_from_range_hash(range_hash)

    #f_block = {
    #             keys: ["beta", "H"],
    #             ps: [
    #                   {v: [0.2, -1.0], result: [-0.483285, -0.484342, -0.483428]},
    #                   ...
    #                 ],
    #             priority: 5.0
    #          }
    f_block = {}
    f_block[:keys] = managed_parameters_table.map {|mtb| mtb["key"]}
    f_block[:ps] = []
    @parameter_sets.each_with_index do |ps_v, index|
      f_block[:ps] << {v: ps_v, result: nil}
    end
    f_block[:priority] = 1.0
    @f_block_list = []
    @f_block_list << f_block
  end

  def generate_runs

    @f_block_list.sort_by! {|f_block| -f_block[:priority]}
    ps_count = 0
    num_jobs = module_data.data["_input_data"]["concurrent_job_max"]
    @running_f_block_list = @f_block_list.shift(num_jobs)
    @running_f_block_list.each do |f_block|
      f_block[:ps].each do |ps|
        module_data.set_input(@num_iterations, ps_count, ps[:v])
        ps_count += 1
      end
    end

    super
  end

  private
  def get_parameter_sets_from_range_hash(range_hash)
    @parameter_sets = []

    oa_param = @param_names.map do |name|
      {name: name, paramDefs: [0, 1]}
    end
    @orthogonal_array = OrthogonalArray.new(oa_param)

    @orthogonal_array.table.transpose.each do |row|
      @parameter_hash = {}
      @param_names.each_with_index do |name, idx|
        range = range_hash[name]
        parameter_value = range[ row[idx].to_i ]
        @parameter_hash[name] = parameter_value
      end
      #parameter_sets << get_parameter_set(parameter_hash)
      @parameter_sets << managed_parameters_table.map {|mpt| @parameter_hash[mpt["key"]]}
    end

    @parameter_sets
  end

  #def get_parameter_set(parameter_hash)
  #  h = {}
  #  parameter_hash.each {|key,val| h["v.#{key}"] = val }
  #  ps = @sim.parameter_sets.where(h).first
  #  unless ps
  #    ps = @sim.parameter_sets.build({"v" => parameter_hash})
  #    ps.save!
  #  end
  #  ps
  #end

  def create_runs_for(parameter_set)
    created_runs = []
    (NUM_RUNS - parameter_set.runs.count).times do |i|
      run = parameter_set.runs.build
      run.submitted_to = @host
      run.save!
      created_runs << run
    end
    created_runs
  end

  def new_range_hashes(range_hash, relevant_factors)
    new_ranges = []

    ranges_array = managed_parameters_table.map {|mpt| mpt["key"]}.map.with_index do |key, index|
      ranges = [ range_hash[key] ]
      if relevant_factors.include?(index)
        range = range_hash[key]
        one_third = range[0]*2 / 3 + range[1]   /3
        two_third = range[0]   / 3 + range[1]*2 /3
        one_third = one_third.round(6) if one_third.is_a?(Float)
        two_third = two_third.round(6) if two_third.is_a?(Float)
        ranges = [
          [range.first, one_third], [one_third, two_third], [two_third, range.last]
        ]
      end
      ranges
    end

    ranges_array.first.product( *(ranges_array[1..-1]) ).each do |a|
      h = { @param_names[0] => a[0], @param_names[1] => a[1]}
      new_ranges << h
    end
    new_ranges
  end

  def evaluate_runs

    super

    ps_count = 0
    @running_f_block_list.each do |f_block|
      f_block[:ps].each do |ps|
        ps[:result] = module_data.get_output(@num_iterations, ps_count)
        ps_count += 1
      end
    end

    @running_f_block_list.each do |f_block|
      #f_result = FTest.eff_facts(f_block)
      mean_distances = MeanTest.mean_distances(f_block)
      @f_block_list += new_f_blocks(f_block, mean_distances)
      #f_values = f_result.map {|f| f[:f_value]}
      #@f_block_list += new_f_blocks(f_block, f_values)
    end
    @total_f_block_count += @running_f_block_list.size
  end

  #def new_f_blocks(f_block, f_values)
  def new_f_blocks(f_block, mean_distances)
    f_blocks = []
    mean_distances.each_with_index do |mean_distance, index|
      b = mean_distance > module_data.data["_input_data"]["distance_threshold"]
      if b

        v_values = f_block[:ps].map {|ps| ps[:v][index] }
        range = [v_values.min, v_values.max]
        one_third = range[0]*2 / 3 + range[1]   /3
        two_third = range[0]   / 3 + range[1]*2 /3
        one_third = one_third.round(6) if one_third.is_a?(Float)
        two_third = two_third.round(6) if two_third.is_a?(Float)
        ranges = [
          [range.first, one_third], [one_third, two_third], [two_third, range.last]
        ]

        range_hash = f_block_to_range_hash(f_block)
        ranges.each do |r|
          range_hash[f_block[:keys][index]] = r
          ps = get_parameter_sets_from_range_hash(range_hash)
          new_f_block = {}
          new_f_block[:keys] = f_block[:keys]
          new_f_block[:priority] = mean_distance
          new_f_block[:ps] = ps.map {|p| {v: p}}
          f_blocks << new_f_block
        end
      end
    end
    f_blocks
  end

  def f_block_to_range_hash(f_block)
    range_hash = {}
    f_block[:keys].each_with_index do |key, index|
      v_values = f_block[:ps].map {|ps| ps[:v][index] }
      range_hash[key] = [v_values.min, v_values.max]
    end
    range_hash
  end

  def finished?
    puts "# of f_block_list.size = #{@f_block_list.size}"
    puts "total_f_block_count = #{@total_f_block_count}"
    @f_block_list.empty? or  @total_f_block_count > module_data.data["_input_data"]["f_block_count_max"]
  end

  #override
  def get_target_fields(result)
    result.try(:fetch, module_data.data["_input_data"]["target_field"])
  end
end
