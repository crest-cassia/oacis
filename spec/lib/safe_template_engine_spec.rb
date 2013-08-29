require 'spec_helper'

describe JobScriptUtil do

  before(:each) do
    @sample_template = <<-EOS
param1: <%= param1 %>
param2: <%= param2 / 4 %>
param3: <%= param3 % param4 %>
<%= param1 %><%= param2 %>
EOS
  end

  describe ".invalid_parameters" do

    it "returns an empty array for a valid template" do
      SafeTemplateEngine.invalid_parameters(@sample_template).should be_empty
    end

    it "returns an array of invalid parameters for a template including non-supported operations" do
      # only single binary operation is supported
      invalid_template = <<-EOS
param1: <%= param1 + param2 % param3 %>
param2: <%= a b %>
  EOS
      arr = SafeTemplateEngine.invalid_parameters(invalid_template)
      arr.should eq ["<%= param1 + param2 % param3 %>", "<%= a b %>"]
    end
  end

  describe ".extract_parameters" do

    it "returns parameters used in template" do
      params = SafeTemplateEngine.extract_parameters(@sample_template)
      params.should eq ["param1", "param2", "param3", "param4"]
    end
  end

  describe ".extract_arithmetic_parameters" do

    it "returns parameters used for arithmetic operations" do
      params = SafeTemplateEngine.extract_arithmetic_parameters(@sample_template)
      params.should eq ["param2", "param3", "param4"]
    end
  end

  describe ".render" do

    it "renders template with the given parameters" do
      parameters = {"param1" => "ABC", "param2" => 8, "param3" => 7, "param4" => 4}
      rendered = SafeTemplateEngine.render(@sample_template, parameters)
      rendered.should eq <<-EOS
param1: ABC
param2: 2
param3: 3
ABC8
EOS
    end
  end
end