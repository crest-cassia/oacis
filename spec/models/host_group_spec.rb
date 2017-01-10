require 'spec_helper'

RSpec.describe HostGroup do

  describe "validation" do

    before(:each) do
      @valid_attr = {
        name: "host_group1",
        hosts: [ FactoryGirl.create(:host) ]
      }
    end

    it "'name' must be present" do
      @valid_attr.delete(:name)
      expect( HostGroup.new(@valid_attr) ).not_to be_valid
    end

    it "'name' must be unique" do
      HostGroup.create!(@valid_attr)
      expect( HostGroup.new(@valid_attr) ).not_to be_valid
    end

    it "'name' must not be empty" do
      @valid_attr[:name] = ''
      expect( HostGroup.new(@valid_attr) ).not_to be_valid
    end

    it "must have at least one host" do
      @valid_attr[:hosts] = []
      expect( HostGroup.new( @valid_attr ) ).not_to be_valid
    end
  end

  describe ".find_by_name" do

    it "returns the host_group with the given name" do
      hg = FactoryGirl.create(:host_group)
      found = HostGroup.find_by_name(hg.name)
      expect(hg).to eq found
    end

    it "raises an exception when the host_group is not found" do
      expect {
        HostGroup.find_by_name("do_not_exist")
      }.to raise_error("HostGroup do_not_exist is not found")
    end
  end
end
