# a safe template engine
#   eval is not used to render the template
#   only arithmetic binary functions using +, -, *, /, and % are supported
module SafeTemplateEngine

  CANDIDATE_PATTERN = /<%=\s*.*?\s*%>/
  SUPPORTED_PATTERN = /<%=\s*(\w+)(\s+([\+\-\*\/\%])\s+(\w+))?\s*%>/
  ARITHMETIC_PATTERN = /<%=\s*(\w+)\s+([\+\-\*\/\%])\s+(\w+)\s*%>/
  NUM_PATTERN = /\A\d+\z/

  # return parameters which includes non-supported operations
  def self.invalid_parameters(template)
    reg = CANDIDATE_PATTERN
    arr_matched = template.scan(reg)

    supported = SUPPORTED_PATTERN
    found = arr_matched.find_all do |matched|
      matched !~ supported
    end
    found
  end

  # returns parameters used in the template
  # arithmetic parameters are also included
  def self.extract_parameters(template)
    params = []
    template.scan(SUPPORTED_PATTERN) do |matched|
      params << matched[0] if matched[0] !~ NUM_PATTERN
      params << matched[3] if matched[3] and matched[3] !~ NUM_PATTERN
    end
    params.uniq
  end

  def self.extract_arithmetic_parameters(template)
    params = []
    template.scan(ARITHMETIC_PATTERN) do |matched|
      params << matched[0] if matched[0] !~ NUM_PATTERN
      params << matched[2] if matched[2] !~ NUM_PATTERN
    end
    params.uniq
  end

  def self.render(template, parameters)
    template.gsub(SUPPORTED_PATTERN) do |matched|
      if $2  # arithmetic operation
        operation = $3
        first = $1
        second = $4
        if first =~ NUM_PATTERN
          first = first.to_i
        else
          first = parameters[first].to_i
        end
        if second =~ NUM_PATTERN
          second = second.to_i
        else
          second = parameters[second].to_i
        end

        case operation
        when "+"
          first + second
        when "-"
          first - second
        when "*"
          first * second
        when "/"
          first / second
        when "%"
          first % second
        else
          raise "must not happen #{matched[2]}"
        end
      else
        parameters[$1]
      end
    end
  end
end
