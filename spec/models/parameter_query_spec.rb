require 'spec_helper'

describe ParameterQuery do
  #pending "add some examples to (or delete) #{__FILE__}"
  before(:each) do
    @query = FactoryGirl.create(:parameter_query)
  end
  describe "basic parameterquery" do
    before(:each) do
      @query.query = [{"L"=>1}, {"T"=>2.0}]
      @query.save
    end
    subject { @query }
    it {should be_a(ParameterQuery)}
    it {should have_at_least(1).query }
    its(:query) {should_not be_empty}
  end
  describe "method tests" do
    before(:each) do
      @query.query = {"L"=>1, "T"=>2.0}
      @query.save
      @sim = FactoryGirl.create(:simulator, 
        parameter_sets_count: 1, 
        runs_count: 1)
      end
    subject { @query }
    its(:get_selector) {should == Query.new.where(v: {"L"=>1, "T"=>2.0}).selector}
    its(:add_constraint, {"S"=>20}) {should == Query.new.where(v: {"L"=>1, "T"=>2.0, "S"=>2.0}).selector}
    its(:del_constraint) {should == Query.new.where(v: {"L"=>1, "T"=>2.0}).selector}
  end
end
