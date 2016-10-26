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
end
