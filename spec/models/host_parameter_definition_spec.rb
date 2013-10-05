require 'spec_helper'

describe HostParameterDefinition do

  describe "validation" do

    before(:each) do
      @valid_attr = {key: "node"}
    end

    it "is valid with valid attributes" do
      hpd = HostParameterDefinition.new(@valid_attr)
      hpd.should be_valid
    end

    it "must have key" do
      hpd = HostParameterDefinition.new()
      hpd.should_not be_valid
    end

    it "reserved words can not be used as a key" do
      hpd = HostParameterDefinition.new(@valid_attr.update(key: "mpi_procs"))
      hpd.should_not be_valid
    end

    it "default value must conform to the format" do
      updated = @valid_attr.update(default: "10:00:00", format: "\\d\\d:\\d\\d:\\d\\d")
      hpd = HostParameterDefinition.new(updated)
      hpd.should be_valid

      updated = @valid_attr.update(default: "xx:00:00", format: "\\d\\d:\\d\\d:\\d\\d")
      hpd = HostParameterDefinition.new(updated)
      hpd.should_not be_valid
    end
  end
end
