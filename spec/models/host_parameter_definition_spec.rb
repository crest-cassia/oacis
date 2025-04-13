require 'spec_helper'

describe HostParameterDefinition do

  describe "validation" do

    before(:each) do
      @valid_attr = {key: "node"}
    end

    it "is valid with valid attributes" do
      hpd = HostParameterDefinition.new(@valid_attr)
      expect(hpd).to be_valid
    end

    it "must have key" do
      hpd = HostParameterDefinition.new()
      expect(hpd).not_to be_valid
    end

    it "reserved words can not be used as a key" do
      hpd = HostParameterDefinition.new(@valid_attr.update(key: "mpi_procs"))
      expect(hpd).not_to be_valid
    end

    it "default value must conform to the format" do
      updated = @valid_attr.update(default: "10:00:00", format: "\\d\\d:\\d\\d:\\d\\d")
      hpd = HostParameterDefinition.new(updated)
      expect(hpd).to be_valid

      updated = @valid_attr.update(default: "xx:00:00", format: "\\d\\d:\\d\\d:\\d\\d")
      hpd = HostParameterDefinition.new(updated)
      expect(hpd).not_to be_valid
    end

    describe "options field" do

      it "is valid with an array of strings" do
        hpd = HostParameterDefinition.new(@valid_attr)
        expect(hpd).to be_valid
      end

      it "ignores options when options is an empty array" do
        hpd = HostParameterDefinition.new(@valid_attr.update(options: []))
        expect(hpd).to be_valid
      end

      it "ignores format when options are given" do
        hpd = HostParameterDefinition.new(@valid_attr.update(format: "\\d+", options: ["option1", "option2"]))
        expect(hpd).to be_valid
        expect(hpd.format).to_not be_present
      end

      it "default value is the first element of the options" do
        hpd = HostParameterDefinition.new(@valid_attr.update(default: nil, options: ["option1", "option2"]))
        expect(hpd).to be_valid
        expect(hpd.default).to eq "option1"
      end

      it "is raises an exception when options is not an array" do
        expect {
          hpd = HostParameterDefinition.new(@valid_attr.update(options: "option1"))
        }.to raise_error(Mongoid::Errors::InvalidValue)
      end

      it "is not valid with an array containing non-string values" do
        hpd = HostParameterDefinition.new(@valid_attr.update(options: ["option1", 2]))
        expect(hpd).not_to be_valid
      end

      it "default value must be one of the options" do
        hpd = HostParameterDefinition.new(@valid_attr.update(default: "option1", options: ["option1", "option2"]))
        expect(hpd).to be_valid

        hpd = HostParameterDefinition.new(@valid_attr.update(default: "option3", options: ["option1", "option2"]))
        expect(hpd).not_to be_valid
      end
    end
  end
end
