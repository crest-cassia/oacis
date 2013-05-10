require 'spec_helper'

describe ParameterQuery do
  #pending "add some examples to (or delete) #{__FILE__}"
  before(:each) do
    @query = FactoryGirl.create(:parameter_query)
  end
  describe "basic test" do
    before(:each) do
      @query.query = { "L" => {:eq => 50 } }
    end
    subject { @query }
    it {should be_a(ParameterQuery)}
    it {should have_at_least(1).query}
  end
end
