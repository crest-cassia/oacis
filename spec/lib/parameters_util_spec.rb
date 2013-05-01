require 'spec_helper'

describe ParametersUtil do

  describe ".cast_parameter_values" do

    before(:each) do
      @definitions = {
        "param1"=>{"type"=>"Integer", "description" => "System size"},
        "param2"=>{"type"=>"Float", "default" => 1.0, "description" => "Temperature"},
        "param3"=>{"type"=>"Boolean", "default" => false, "description" => "Sequential update?"},
        "param4"=>{"type"=>"String", "default" => "abc", "description" => "a string parameter"}
      }
    end

    it "casts values properly according to its definition" do
      parameters = {
        "param1" => "70",
        "param2" => "3.0",
        "param3" => "1",
        "param4" => 12345
      }
      casted = ParametersUtil.cast_parameter_values(parameters, @definitions)

      casted["param1"].should be_a(Integer)
      casted["param1"].should eq(70)
      casted["param2"].should be_a(Float)
      casted["param2"].should eq(3.0)
      casted["param3"].should be_true
      casted["param4"].should be_a(String)
      casted["param4"].should eq("12345")
    end

    it "uses the defined default value if a parameter is not specified" do
      parameters = {
        "param1" => "70"
      }
      casted = ParametersUtil.cast_parameter_values(parameters, @definitions)
      casted["param1"].should eq(70)
      casted["param2"].should eq(1.0)
      casted["param3"].should be_false
      casted["param4"].should eq("abc")
    end

    it "returns nil when a parameter is not given for the key whose default value is not defined" do
      parameters = {
        "param2" => "3.0"
      }
      casted = ParametersUtil.cast_parameter_values(parameters, @definitions)
      casted.should be_nil
    end
  end
end
