module AnalysisUtil

  def self.error_analysis(data)
    n = data.size
    ave = n > 0 ? (data.inject(:+).to_f / n) : nil
    err = nil
    err = Math.sqrt( data.map {|x| (x-ave)*(x-ave) }.inject(:+) / (n*(n-1)) ) if n > 1
    return ave, err, n
  end
end
