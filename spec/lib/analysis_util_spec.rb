require 'spec_helper'

describe AnalysisUtil do

  describe ".error_analysis" do

    it "executes error analysis and returns [average, error, number_of_data]" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      result = AnalysisUtil.error_analysis(data)
      expect(result.size).to eq 3
      expect(result[0]).to be_within(0.0001).of(3.0)
      expect(result[1]).to be_within(0.0001).of(Math.sqrt(0.5))
      expect(result[2]).to eq 5
    end

    it "first element is nil when the number of data is 0" do
      expect(AnalysisUtil.error_analysis([])).to eq [nil, nil, 0]
    end

    it "second element is nil when the number of data is less than 2" do
      expect(AnalysisUtil.error_analysis([1.0])).to eq [1.0, nil, 1]
    end
  end
end
