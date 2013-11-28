require 'spec_helper'

describe AnalysisUtil do

  describe ".error_analysis" do

    it "executes error analysis and returns [average, error, number_of_data]" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      result = AnalysisUtil.error_analysis(data)
      result.should have(3).items
      result[0].should be_within(0.0001).of(3.0)
      result[1].should be_within(0.0001).of(Math.sqrt(0.5))
      result[2].should eq 5
    end

    it "first element is nil when the number of data is 0" do
      AnalysisUtil.error_analysis([]).should eq [nil, nil, 0]
    end

    it "second element is nil when the number of data is less than 2" do
      AnalysisUtil.error_analysis([1.0]).should eq [1.0, nil, 1]
    end
  end
end
