require 'spec_helper'

describe ParametersUtil do

  describe ".cast_parameter_values" do

    before(:each) do
      @definitions = [
        ParameterDefinition.new(key: "param1", type: "Integer", description: "System size"),
        ParameterDefinition.new(key: "param2", type: "Float", default: 1.0, description: "temperature"),
        ParameterDefinition.new(key: "param3", type: "Integer", default: 0, description: "sequential update?"),
        ParameterDefinition.new(key: "param4", type: "String", default: "abc", description: "a string parameter"),
        ParameterDefinition.new(key: "param5", type: "Object", default: {"x" => [99,3.14,"hello"]}, description: "an object parameter"),
        ParameterDefinition.new(key: "param6", type: "Selection", default: "option1", options: ["option1", "option2", "option3"], description: "a selection parameter")
      ]
    end

    it "casts values properly according to its definition" do
      parameters = {
        "param1" => "70",
        "param2" => "3.0",
        "param3" => "1",
        "param4" => 12345,
        "param5" => '{"x": [3.14, "hello", "world"], "y": 123}',
        "param6" => "option2"
      }
      casted = ParametersUtil.cast_parameter_values(parameters, @definitions)

      expect(casted["param1"]).to be_a(Integer)
      expect(casted["param1"]).to eq(70)
      expect(casted["param2"]).to be_a(Float)
      expect(casted["param2"]).to eq(3.0)
      expect(casted["param3"]).to be_a(Integer)
      expect(casted["param3"]).to eq(1)
      expect(casted["param4"]).to be_a(String)
      expect(casted["param4"]).to eq("12345")
      expect(casted["param5"]).to be_a(Hash)
      expect(casted["param5"]).to eq({"x" => [3.14, "hello", "world"], "y" => 123})
      expect(casted["param6"]).to eq("option2")
    end

    it "casts values properly even if the argument is a hash whose keys are symbol" do
      parameters = {
        param1: "70",
        param2: "3.0",
        param3: "1",
        param4: 12345,
        param5: '{"x": [3.14, "hello", "world"], "y": 123}',
        param6: "option2"
      }
      casted = ParametersUtil.cast_parameter_values(parameters, @definitions)

      expect(casted["param1"]).to be_a(Integer)
      expect(casted["param1"]).to eq(70)
      expect(casted["param2"]).to be_a(Float)
      expect(casted["param2"]).to eq(3.0)
      expect(casted["param3"]).to be_a(Integer)
      expect(casted["param3"]).to eq(1)
      expect(casted["param4"]).to be_a(String)
      expect(casted["param4"]).to eq("12345")
      expect(casted["param5"]).to be_a(Hash)
      expect(casted["param5"]).to eq({"x" => [3.14, "hello", "world"], "y" => 123})
      expect(casted["param6"]).to eq("option2")
    end

    it "uses the defined default value if a parameter is not specified" do
      parameters = {
        "param1" => "70"
      }
      casted = ParametersUtil.cast_parameter_values(parameters, @definitions)
      expect(casted["param1"]).to eq(70)
      expect(casted["param2"]).to eq(1.0)
      expect(casted["param3"]).to eq(0)
      expect(casted["param4"]).to eq("abc")
      expect(casted["param5"]).to eq( {"x"=>[99,3.14,"hello"]} )
      expect(casted["param6"]).to eq("option1")
    end

    it "returns nil when a parameter is not given for the key whose default value is not defined" do
      parameters = {
        "param2" => "3.0"
      }
      casted = ParametersUtil.cast_parameter_values(parameters, @definitions)
      expect(casted).to be_nil
    end

    it "accept nil as the first argument" do
      casted = ParametersUtil.cast_parameter_values(nil, @definitions)
    end

    context "when unknown keys are given" do

      it "returns nil" do
        parameters = {
          "param1" => "70",
          "param2" => "3.0",
          "param3" => "1",
          "param4" => 12345,
          "param_unknown" => "abc"
        }
        casted = ParametersUtil.cast_parameter_values(parameters, @definitions)
        expect(casted).to be_nil
      end
    end
  end

  describe ".cast_value" do

    it "returns casted value" do
      expect(ParametersUtil.cast_value("-1", "Integer")).to eq(-1)
      expect(ParametersUtil.cast_value("+0.234e5", "Float")).to eq(0.234e5)
      expect(ParametersUtil.cast_value(123, "String")).to eq("123")
    end

    it "returns casted object" do
      expect(ParametersUtil.cast_value('{"x": "hello", "y": "world"}', "Object")).to eq( {"x"=>"hello", "y"=>"world"})
      expect(ParametersUtil.cast_value({"x"=>"hello", "y"=>"world"}, "Object")).to eq( {"x"=>"hello", "y"=>"world"})
      expect(ParametersUtil.cast_value(123, "Object")).to eq(123)
    end

    it "returns nil when format of the value is not valid" do
      expect(ParametersUtil.cast_value("abc", "Integer")).to be_nil
      expect(ParametersUtil.cast_value("def", "Float")).to be_nil
      expect(ParametersUtil.cast_value('{"x": "hello"', "Object")).to eq(nil)
    end
  end
end
