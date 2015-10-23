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
        allow(@context).to receive(:params).and_return({id: @simulator.to_param, draw: 1, start: 0, length:25 , "order" => {"0" =>  {"column" => "4", "dir" => "asc"}}})
        allow(@context).to receive(:link_to).and_return("#{@simulator.to_param}")
        allow(@context).to receive(:distance_to_now_in_words).and_return("time")
        allow(@context).to receive(:progress_bar).and_return("<div></div>")
        allow(@context).to receive(:parameter_set_path).and_return("/parameter_sets/00000000ffffff0000ffffffff")
        allow(@context).to receive(:shortened_id_monospaced).and_return("xxxx..yy")
        keys = @simulator.parameter_definitions.map {|x| x.key}
        @psld = ParameterSetsListDatatable.new(@simulator.parameter_sets, keys, @context)
        @psld_json = JSON.parse(@psld.to_json)
      end

      it "is initialized" do
        expect(@psld.instance_variable_get(:@param_sets)).to eq @simulator.parameter_sets
      end

      it "return json" do
        expect(@psld_json["recordsTotal"]).to eq(30)
        expect(@psld_json["recordsFiltered"]).to eq(30)
        expect(@psld_json["data"].size).to eq(25)
        expect(@psld_json["data"].first[4].to_i).to eq(ParameterSet.only("v.L").where(:simulator_id => @simulator.to_param).min("v.L"))
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
        allow(@context).to receive(:params).and_return({id: @simulator.to_param, draw: 1, start: 0, length:5 , "order" =>  {"0" => {"column" => "4", "dir" => "desc"}}, query_id: @query.id})
        allow(@context).to receive(:link_to).and_return("#{@simulator.to_param}")
        allow(@context).to receive(:distance_to_now_in_words).and_return("time")
        allow(@context).to receive(:progress_bar).and_return("<div></div>")
        allow(@context).to receive(:parameter_set_path).and_return("/parameter_sets/00000000ffffff0000ffffffff")
        allow(@context).to receive(:shortened_id_monospaced).and_return("xxxx..yy")
        keys = @simulator.parameter_definitions.map {|x| x.key}
        @psld = ParameterSetsListDatatable.new(@query.parameter_sets, keys, @context)
        @psld_json = JSON.parse(@psld.to_json)
      end

      it "is initialized" do
        expect(@psld.instance_variable_get(:@param_sets)).to eq(@query.parameter_sets)
      end

      it "return json" do
        expect(@psld_json["recordsTotal"]).to eq(25)
        expect(@psld_json["recordsFiltered"]).to eq(25)
        expect(@psld_json["data"].size).to eq(5)
        expect(@psld_json["data"].first[4].to_i).to eq(@query.parameter_sets.only("v.L").max("v.L"))#["aaData"].first[4].to_i is qeual to v.L (["aaData"].first[id, updated_at, [keys]])
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
        allow(@context).to receive(:params).and_return({id: @simulator.to_param, draw: 1, start: 0, length:25 , "order" => {"0" => {"column" => 4, "dir" => "desc"}, "1" => {"column" => 0, "dir" => "asc"}}})
        allow(@context).to receive(:link_to).and_return("#{@simulator.to_param}")
        allow(@context).to receive(:distance_to_now_in_words).and_return("time")
        allow(@context).to receive(:progress_bar).and_return("<div></div>")
        allow(@context).to receive(:parameter_set_path).and_return("/parameter_sets/00000000ffffff0000ffffffff")
        allow(@context).to receive(:shortened_id_monospaced).and_return("xxxx..yy")
        keys = @simulator.parameter_definitions.map {|x| x.key}
        @psld = ParameterSetsListDatatable.new(@simulator.parameter_sets, keys, @context)
        @psld_json = JSON.parse(@psld.to_json)
      end

      it "return json" do
        expect(@psld_json["recordsTotal"]).to eq(30)
        expect(@psld_json["recordsFiltered"]).to eq(30)
        expect(@psld_json["data"].size).to eq(25)
        expect(@psld_json["data"].first[4].to_i).to eq(ParameterSet.only("v.L").where(:simulator_id => @simulator.to_param).max("v.L"))
        expect(@psld_json["data"].first[5].to_f).to eq(ParameterSet.only("v.T").where(:simulator_id => @simulator.to_param).where({"v.L"=>14}).min("v.T"))
      end
    end
  end

  describe ".header" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 0)
    end

    it "returns array of th tags" do
      arr = ParameterSetsListDatatable.header(@sim)
      expect(arr).to be_an(Array)
      expect(arr.size).to eq (5 + @sim.parameter_definitions.size)
    end
  end
end
