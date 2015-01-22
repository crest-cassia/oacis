require 'spec_helper'

describe "AnalysesListDatatable" do

  describe "GET _analyses_list" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count:1, runs_count:1,
                                analyzers_count: 1, run_analysis: false
                               )
      @run = @sim.parameter_sets.first.runs.first
      @azr = @sim.analyzers.first
     20.times do |i|
        @valid_attr = {
          parameters: {"param1" => 1, "param2" => 2.0},
          analyzer: @azr,
          analyzer_version: (i%2).to_s
        }
        @run.analyses.create!(@valid_attr)
      end
      @context = ActionController::Base.new.view_context
      @context.stub(:params).and_return({sEcho: 1, iDisplayStart: 0, iDisplayLength:10 , iSortCol_0: 0, sSortDir_0: "desc"})
      @context.stub(:link_to) {|str, link_path| link_path }
      @context.stub(:image_tag) {|str, link_path| link_path }
      @context.stub(:analysis_path) {|arn| arn.id.to_s }
      @context.stub(:analyzer_path) {|anz| anz.id.to_s }
      @context.stub(:distance_to_now_in_words).and_return("time")
      @context.stub(:raw).and_return("label")
      @context.stub(:status_label).and_return("status_label")
      @context.stub(:shortened_id).and_return("xxxx..yy")
      @arnld = AnalysesListDatatable.new(Analysis.where(status: :created), @context)
      @arnld_json = JSON.parse(@arnld.to_json)
    end

    it "is initialized" do
      @arnld.instance_variable_get(:@analyses).should eq(Analysis.where(status: :created))
    end

    it "returns json" do
      @arnld_json["iTotalRecords"].should == 20
      @arnld_json["iTotalDisplayRecords"].should == 20
      @arnld_json["aaData"].size.should == 10
      @arnld_json["aaData"][0][1].to_s.should == @run.analyses.order_by("id desc").first.id.to_s
    end

    context "with multiple sort" do

      before(:each) do
        @context = ActionController::Base.new.view_context
        @context.stub(:params).and_return({sEcho: 1, iDisplayStart: 0, iDisplayLength:10, iSortCol_0: 4, iSortCol_1: 0, sSortDir_0: "asc", sSortDir_1: "desc"})
        @context.stub(:link_to) {|str, link_path| link_path }
        @context.stub(:image_tag) {|str, link_path| link_path }
        @context.stub(:analysis_path) {|arn| arn.id.to_s }
        @context.stub(:analyzer_path) {|anz| anz.id.to_s }
        @context.stub(:distance_to_now_in_words).and_return("time")
        @context.stub(:raw).and_return("label")
        @context.stub(:status_label).and_return("status_label")
        @context.stub(:shortened_id).and_return("xxxx..yy")
        @arnld = AnalysesListDatatable.new(Analysis.where(status: :created), @context)
        @arnld_json = JSON.parse(@arnld.to_json)
      end

      it "returns json" do
        @arnld_json["iTotalRecords"].should == 20
        @arnld_json["iTotalDisplayRecords"].should == 20
        @arnld_json["aaData"].size.should == 10
        @arnld_json["aaData"][0][1].to_s.should == @run.analyses.order_by({"analyzer_version"=>"asc", "id"=>"desc"}).first.id.to_s
      end
    end
  end
end
