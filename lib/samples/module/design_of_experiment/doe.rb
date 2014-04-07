require 'json'
require_relative '../OACIS_module.rb'
require_relative '../OACIS_module_data.rb'
require_relative 'mean_test'
require_relative 'f_test'
require_relative 'orthogonal_array'

class Doe < OacisModule

  def self.definition
    h = {}
    h["ps_block_count_max"] = 1000
    h["distance_threshold"] = 0.1
    h["target_field"] = "order_parameter"
    h["concurrent_job_max"] = 30
    h["search_parameter_ranges"] = {
      # ex.) 
      # "beta" => [0.5, 0.6],
      # "H" => [-0.1, 0.0]
    }
    h
  end

  def initialize(input_data)
    super(input_data)

    @total_ps_block_count = 0
    @param_names = []
    @step_size = {}

    module_data.data["_input_data"]["search_parameter_ranges"].each do |key, range|
      @param_names.push(key)
      @step_size[key] = range.max - range.min
      @step_size[key] = @step_size[key].round(6) if @step_size[key].is_a?(Float)
    end

    #range_hashes = [
    #                  {"beta"=>[0.2, 0.6], "H"=>[-1.0, 1.0]},
    #                  ...
    #                ]
    range_hash = module_data.data["_input_data"]["search_parameter_ranges"]

    parameter_values = get_parameter_values_from_range_hash(range_hash)

    #ps_block = {
    #             keys: ["beta", "H"],
    #             ps: [
    #                   {v: [0.2, -1.0], result: [-0.483285, -0.484342, -0.483428]},
    #                   ...
    #                 ],
    #             priority: 5.0,
    #             direction: "inside"
    #          }
    ps_block = {}
    ps_block[:keys] = managed_parameters_table.map {|mtb| mtb["key"]}
    ps_block[:ps] = []
    parameter_values.each_with_index do |ps_v, index|
      ps_block[:ps] << {v: ps_v, result: nil}
    end
    ps_block[:priority] = 1.0
    ps_block[:direction] = "outside"
    @ps_block_list = []
    @ps_block_list << ps_block
  end

  private
  #override
  def generate_runs

    @ps_block_list.sort_by! {|ps_block| -ps_block[:priority]}
    ps_count = 0
    num_jobs = module_data.data["_input_data"]["concurrent_job_max"]
    @running_ps_block_list = @ps_block_list.shift(num_jobs)
    @running_ps_block_list.each do |ps_block|
      ps_block[:ps].each do |ps|
        module_data.set_input(@num_iterations, ps_count, ps[:v])
        ps_count += 1
      end
    end

    super
  end

  def get_parameter_values_from_range_hash(range_hash)

    parameter_values = []
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
      parameter_values << managed_parameters_table.map {|mpt| @parameter_hash[mpt["key"]]}
    end

    parameter_values
  end

  #override
  def evaluate_runs

    super

    ps_count = 0
    @running_ps_block_list.each do |ps_block|
      ps_block[:ps].each do |ps|
        ps[:result] = module_data.get_output(@num_iterations, ps_count)
        ps_count += 1
      end
    end

    @running_ps_block_list.each do |ps_block|
      mean_distances = MeanTest.mean_distances(ps_block)
      new_ps_blocks(ps_block, mean_distances).each do |new_ps_block|
        @ps_block_list << new_ps_block if !is_duplicate(new_ps_block)
      end
    end
    @total_ps_block_count += @running_ps_block_list.size
  end

  def new_ps_blocks(ps_block, mean_distances)

    ps_blocks = []

    # => inside 
    mean_distances.each_with_index do |mean_distance, index|
      if mean_distance > module_data.data["_input_data"]["distance_threshold"]
        v_values = ps_block[:ps].map {|ps| ps[:v][index] }
        range = [v_values.min, v_values.max]
        one_third = range[0]*2 / 3 + range[1]   /3
        two_third = range[0]   / 3 + range[1]*2 /3
        one_third = one_third.round(6) if one_third.is_a?(Float)
        two_third = two_third.round(6) if two_third.is_a?(Float)
        ranges = [
          [range.first, one_third], [one_third, two_third], [two_third, range.last]
        ]

        range_hash = ps_block_to_range_hash(ps_block)
        ranges.each do |r|
          range_hash[ps_block[:keys][index]] = r
          ps = get_parameter_values_from_range_hash(range_hash)
          new_ps_block = {}
          new_ps_block[:keys] = ps_block[:keys]
          new_ps_block[:priority] = mean_distance
          new_ps_block[:direction] = "inside"
          new_ps_block[:ps] = ps.map {|p| {v: p}}
          ps_blocks << new_ps_block
        end
      end
    end
    # ==========

    # => outside
    if ps_block[:direction] != "inside"
      mean_distances.each_with_index do |mean_distance, index|
        v_values = ps_block[:ps].map {|ps| ps[:v][index] }
        range = [v_values.min, v_values.max]

        lower = range[0] - @step_size[ps_block[:keys][index]]
        upper = range[1] + @step_size[ps_block[:keys][index]]
        lower = lower.round(6) if lower.is_a?(Float)
        upper = upper.round(6) if upper.is_a?(Float)
        ranges = [
          [lower, range.first], [range.last, upper]
        ]

        range_hash = ps_block_to_range_hash(ps_block)
        ranges.each do |r|
          range_hash[ps_block[:keys][index]] = r
          ps = get_parameter_values_from_range_hash(range_hash)
          new_ps_block = {}
          new_ps_block[:keys] = ps_block[:keys]
          new_ps_block[:priority] = mean_distance
          new_ps_block[:direction] = "outside"
          new_ps_block[:ps] = ps.map {|p| {v: p}}
          ps_blocks << new_ps_block
        end
      end
    end
    # ==========
    ps_blocks
  end

  def ps_block_to_range_hash(ps_block)

    range_hash = {}
    ps_block[:keys].each_with_index do |key, index|
      v_values = ps_block[:ps].map {|ps| ps[:v][index] }
      range_hash[key] = [v_values.min, v_values.max]
    end
    range_hash
  end

  #override
  def finished?

    puts "# of ps_block_list.size = #{@ps_block_list.size}"
    puts "total_ps_block_count = #{@total_ps_block_count}"
    @ps_block_list.empty? or  @total_ps_block_count > module_data.data["_input_data"]["ps_block_count_max"]
  end

  #override
  def get_target_fields(result)
    result.try(:fetch, module_data.data["_input_data"]["target_field"])
  end

  def is_duplicate(check_block)

    return false if @ps_block_list.empty?
    @ps_block_list.each do |ps_block|
      ps_block[:ps].each do |values|
        return false if !check_block[:ps].include?(values)
      end
    end
    true
  end
end
