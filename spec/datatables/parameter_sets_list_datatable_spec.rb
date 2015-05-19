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
        # columns ["id", "progress_rate_cache", "id", "updated_at"] + @param_keys.map {|key| "v.#{key}"} + ["id"]
        @context.stub(:params).and_return({id: @simulator.to_param, draw: 1, start: 0, length:25 , "order" => {"0" =>  {"column" => "4", "dir" => "asc"}}})
        @context.stub(:link_to).and_return("#{@simulator.to_param}")
        @context.stub(:distance_to_now_in_words).and_return("time")
        @context.stub(:progress_bar).and_return("<div></div>")
        @context.stub(:parameter_set_path).and_return("/parameter_sets/00000000ffffff0000ffffffff")
        @context.stub(:shortened_id_monospaced).and_return("xxxx..yy")
        keys = @simulator.parameter_definitions.map {|x| x.key}
        @psld = ParameterSetsListDatatable.new(@simulator.parameter_sets, keys, @context)
        @psld_json = JSON.parse(@psld.to_json)
      end

      it "is initialized" do
        @psld.instance_variable_get(:@param_sets).should eq @simulator.parameter_sets
      end

      it "return json" do
        @psld_json["recordsTotal"].should == 30
        @psld_json["recordsFiltered"].should == 30
        @psld_json["data"].size.should == 25
        @psld_json["data"].first[4].to_i.should == ParameterSet.only("v.L").where(:simulator_id => @simulator.to_param).min("v.L")
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
        # columns ["id", "progress_rate_cache", "id", "updated_at"] + @param_keys.map {|key| "v.#{key}"} + ["id"]
        @context.stub(:params).and_return({id: @simulator.to_param, draw: 1, start: 0, length:5 , "order" =>  {"0" => {"column" => "4", "dir" => "desc"}}, query_id: @query.id})
        @context.stub(:link_to).and_return("#{@simulator.to_param}")
        @context.stub(:distance_to_now_in_words).and_return("time")
        @context.stub(:progress_bar).and_return("<div></div>")
        @context.stub(:parameter_set_path).and_return("/parameter_sets/00000000ffffff0000ffffffff")
        @context.stub(:shortened_id_monospaced).and_return("xxxx..yy")
        keys = @simulator.parameter_definitions.map {|x| x.key}
        @psld = ParameterSetsListDatatable.new(@query.parameter_sets, keys, @context)
        @psld_json = JSON.parse(@psld.to_json)
      end

      it "is initialized" do
        @psld.instance_variable_get(:@param_sets).should eq(@query.parameter_sets)
      end

      it "return json" do
        @psld_json["recordsTotal"].should == 25
        @psld_json["recordsFiltered"].should == 25
        @psld_json["data"].size.should == 5
        @psld_json["data"].first[4].to_i.should == @query.parameter_sets.only("v.L").max("v.L")#["aaData"].first[4].to_i is qeual to v.L (["aaData"].first[id, updated_at, [keys]])
      end
    end

    context "with multiple sort" do

      before(:each) do
        @simulator = FactoryGirl.create(:simulator, parameter_sets_count: 0)
        30.times do |i|
          FactoryGirl.create(:parameter_set,
                             simulator: @simulator,
                             runs_count: 0,
                             v: {"L" => i%15, "T" => i*2.0}
                             )
        end
        @context = ActionController::Base.new.view_context
        # columns ["id", "progress_rate_cache", "id", "updated_at"] + @param_keys.map {|key| "v.#{key}"} + ["id"]
        @context.stub(:params).and_return({id: @simulator.to_param, draw: 1, start: 0, length:25 , "order" => {"0" => {"column" => 4, "dir" => "desc"}, "1" => {"column" => 0, "dir" => "asc"}}})
        @context.stub(:link_to).and_return("#{@simulator.to_param}")
        @context.stub(:distance_to_now_in_words).and_return("time")
        @context.stub(:progress_bar).and_return("<div></div>")
        @context.stub(:parameter_set_path).and_return("/parameter_sets/00000000ffffff0000ffffffff")
        @context.stub(:shortened_id_monospaced).and_return("xxxx..yy")
        keys = @simulator.parameter_definitions.map {|x| x.key}
        @psld = ParameterSetsListDatatable.new(@simulator.parameter_sets, keys, @context)
        @psld_json = JSON.parse(@psld.to_json)
      end

      it "return json" do
        @psld_json["recordsTotal"].should == 30
        @psld_json["recordsFiltered"].should == 30
        @psld_json["data"].size.should == 25
        @psld_json["data"].first[4].to_i.should == ParameterSet.only("v.L").where(:simulator_id => @simulator.to_param).max("v.L")
        @psld_json["data"].first[5].to_i.should == ParameterSet.only("v.T").where(:simulator_id => @simulator.to_param).where({"v.L"=>14}).min("v.T")
      end
    end
  end

  describe ".header" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 0)
    end

    it "returns array of th tags" do
      arr = ParameterSetsListDatatable.header(@sim)
      arr.should be_an(Array)
      expect(arr.size).to eq (5 + @sim.parameter_definitions.size)
    end
  end
end
