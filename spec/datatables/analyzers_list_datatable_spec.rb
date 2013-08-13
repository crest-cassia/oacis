require 'spec_helper'

describe "AnalyzersListDatatable" do

  describe "GET _analyzers_list" do

    before(:each) do
      @simulator = FactoryGirl.create(:simulator, analyzers_count: 25)
      @context = ActionController::Base.new.view_context
      @context.stub(:params).and_return({id: @simulator.to_param, sEcho: 1, iDisplayStart: 0, iDisplayLength:10 , iSortCol_0: 0, sSortDir_0: "desc"})
      @context.stub(:shortened_id).and_return("id")
      @context.stub(:analyzer_path).and_return("/analyzers/00000000")
      @azrld = AnalyzersListDatatable.new(@context)
      @azrld_json = JSON.parse(@azrld.to_json)
    end

    it "is initialized" do
      @azrld.instance_variable_get(:@analyzers).should eq(Analyzer.where(:simulator_id => @simulator.to_param))
    end
    
    it "return json" do
      @azrld_json["iTotalRecords"].should == 25
      @azrld_json["iTotalDisplayRecords"].should == 25
      @azrld_json["aaData"].size.should == 10
    end
  end
end