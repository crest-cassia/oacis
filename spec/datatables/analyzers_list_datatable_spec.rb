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

    context "with multiple srot" do

      before(:each) do
        analyzers = @simulator.analyzers
        analyzers.each_with_index do |anz, i|
          anz.description = (i%2).to_s
          anz.save
        end
        @context = ActionController::Base.new.view_context
        @context.stub(:params).and_return({id: @simulator.to_param, sEcho: 1, iDisplayStart: 0, iDisplayLength:10, iSortCol_0: 4, iSortCol_1: 0, sSortDir_0: "asc", sSortDir_1: "desc"})
        @context.stub(:shortened_id).and_return("id")
        @context.stub(:analyzer_path).and_return("/analyzers/00000000")
        @azrld = AnalyzersListDatatable.new(@context)
        @azrld_json = JSON.parse(@azrld.to_json)
      end

      it "resutnr json" do
        @azrld_json["iTotalRecords"].should == 25
        @azrld_json["iTotalDisplayRecords"].should == 25
        @azrld_json["aaData"].size.should == 10
        @azrld_json["aaData"][0][2].to_s.should == @simulator.analyzers.order_by({"description"=>"asc", "id"=>"desc"}).first.name.to_s
      end
    end
  end
end
