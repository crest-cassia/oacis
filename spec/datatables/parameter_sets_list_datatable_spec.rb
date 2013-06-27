require 'spec_helper'

describe "ParameterSetsListDatatable" do

  describe "GET _parameter_list" do

    context "without quey" do

      before(:each) do
        @simulator = FactoryGirl.create(:simulator, parameter_sets_count: 0)
        30.times do |i|
          FactoryGirl.create(:parameter_set,
                             simulator: @simulator,
                             runs_count: 0,
                             v: {"L" => i, "T" => i*2.0}
                             )
        end
        @query = FactoryGirl.create(:parameter_set_query,
                                    simulator: @simulator,
                                    query: {"L" => {"gte" => 5}})

        @context = ActionController::Base.new.view_context
        @context.stub(:params).and_return({id: @simulator.to_param, sEcho: 1, iDisplayStart: 0, iDisplayLength:25 , iSortCol_0: 0, sSortDir_0: "asc"})
        @context.stub(:link_to).and_return("#{@simulator.to_param}")
        @context.stub(:distance_to_now_in_words).and_return("time")
        @context.stub(:parameter_set_path).and_return("path")
        @context.stub(:progress_bar).and_return("progress")
        @psld = ParameterSetsListDatatable.new(@context)
        @psld_json = JSON.parse(@psld.to_json)
      end

      it "is initialized" do
        @psld.instance_variable_get(:@simulator).should eq(Simulator.find(@simulator.to_param))
        @psld.instance_variable_get(:@param_sets).should eq(ParameterSet.where(:simulator_id => @simulator.to_param))
      end
      
      it "return json" do
        @psld_json["iTotalRecords"].should == 30
        @psld_json["iTotalDisplayRecords"].should == 30
        @psld_json["aaData"].size.should == 25
        @psld_json["aaData"].first[2].to_i.should == ParameterSet.only("v.L").where(:simulator_id => @simulator.to_param).min("v.L")
      end
    end

    context "with query" do

      before(:each) do
        @simulator = FactoryGirl.create(:simulator, parameter_sets_count: 0)
        30.times do |i|
          FactoryGirl.create(:parameter_set,
                             simulator: @simulator,
                             runs_count: 0,
                             v: {"L" => i, "T" => i*2.0}
                             )
        end
        @query = FactoryGirl.create(:parameter_set_query,
                                    simulator: @simulator,
                                    query: {"L" => {"gte" => 5}})

        @context = ActionController::Base.new.view_context
        @context.stub(:params).and_return({id: @simulator.to_param, sEcho: 1, iDisplayStart: 0, iDisplayLength:5 , iSortCol_0: 1, sSortDir_0: "desc", query_id: @query.id})
        @context.stub(:link_to).and_return("#{@simulator.to_param}")
        @context.stub(:distance_to_now_in_words).and_return("time")
        @context.stub(:parameter_set_path).and_return("path")
        @context.stub(:progress_bar).and_return("progress")
        @psld = ParameterSetsListDatatable.new(@context)
        @psld_json = JSON.parse(@psld.to_json)
      end

      it "is initialized" do
        @psld.instance_variable_get(:@simulator).should eq(Simulator.find(@simulator.to_param))
        @psld.instance_variable_get(:@param_sets).should eq(@query.parameter_sets)
      end

      it "return json" do
        @psld_json["iTotalRecords"].should == 25
        @psld_json["iTotalDisplayRecords"].should == 25
        @psld_json["aaData"].size.should == 5
        @psld_json["aaData"].first[3].to_i.should == @query.parameter_sets.only("v.L").max("v.L")
        #["aaData"].first[3].to_i is qeual to v.L (img, ["aaData"].first[id, updated_at, [keys]])
      end
    end
  end
end