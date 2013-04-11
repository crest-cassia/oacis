require 'spec_helper'

describe Run do

  before(:each) do
    @simulator = FactoryGirl.create(:simulator)
    @parameter = @simulator.parameters.first
    @valid_attribute = {}
  end

  describe "validations" do

    it "creates a Run with a valid attribute" do
      @parameter.runs.build.should be_valid
    end

    it "assigns 'created' stauts by default" do
      run = @parameter.runs.create
      run.status.should == :created
    end

    it "assigns a seed by default" do
      run = @parameter.runs.create
      run.seed.should be_a(Integer)
    end

    it "assigned seeds are unique" do
      seeds = []
      n = 10
      n.times do |i|
        run = @parameter.runs.create
        seeds << run.seed
      end
      seeds.uniq.size.should == n
    end
  end

  describe "relations" do

    before(:each) do
      @run = @parameter.runs.first
    end

    it "belongs to parameter" do
      @run.should respond_to(:parameter)
    end
  end

end
