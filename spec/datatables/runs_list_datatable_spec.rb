require 'spec_helper'

describe "RunsListDatatable" do

  describe "GET _runs_list" do

    before(:each) do
      @simulator = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 30)
      @param_set = @simulator.parameter_sets.first
      @runs = @param_set.runs 
      @context = ActionController::Base.new.view_context
      @context.stub(:params).and_return({id: @param_set.to_param, sEcho: 1, iDisplayStart: 0, iDisplayLength:25 , iSortCol_0: 0, sSortDir_0: "desc"})
      @context.stub(:link_to) {|str, link_path| link_path }
      @context.stub(:run_path) {|run| run.id.to_s }
      @context.stub(:distance_to_now_in_words).and_return("time")
      @context.stub(:formatted_elapsed_time).and_return("time")
      @context.stub(:raw).and_return("label")
      @context.stub(:status_label).and_return("status_label")
      @context.stub(:shortened_id).and_return("xxxx..yy")
      @rld = RunsListDatatable.new(@runs, @context)
      @rld_json = JSON.parse(@rld.to_json)
    end

    it "is initialized" do
      @rld.instance_variable_get(:@runs).should eq(Run.where(:parameter_set_id => @param_set.to_param))
    end
    
    it "return json" do
      @rld_json["iTotalRecords"].should == 30
      @rld_json["iTotalDisplayRecords"].should == 30
      @rld_json["aaData"].size.should == 25
      @rld_json["aaData"][0][0].to_s.should == @runs.order_by("id desc").first.id.to_s
    end
  end
end