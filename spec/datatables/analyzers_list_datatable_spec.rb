require 'spec_helper'

describe "AnalyzersListDatatable" do

  describe "GET _analyzers_list" do

    before(:each) do
      @simulator = FactoryGirl.create(:simulator, analyzers_count: 25)
      @context = ActionController::Base.new.view_context
      @context.stub(:params).and_return({id: @simulator.to_param, draw: 1, start: 0, length:10 , "order" => {"0" => {"column" => "0", "dir" => "desc"}}})
      @context.stub(:link_to) {|str, link_path| link_path }
      @context.stub(:shortened_id_monospaced).and_return("id")
      @context.stub(:analyzer_path).and_return("/analyzers/00000000")
      @azrld = AnalyzersListDatatable.new(@context)
      @azrld_json = JSON.parse(@azrld.to_json)
    end

    it "is initialized" do
      expect(@azrld.instance_variable_get(:@analyzers)).to eq Analyzer.where(:simulator_id => @simulator.to_param)
    end

    it "return json" do
      expect(@azrld_json["recordsTotal"]).to eq 25
      expect(@azrld_json["recordsFiltered"]).to eq 25
      expect(@azrld_json["data"].size).to eq 10
    end

    context "with multiple srot" do

      before(:each) do
        analyzers = @simulator.analyzers
        analyzers.each_with_index do |anz, i|
          anz.description = (i%2).to_s
          anz.save
        end
        @context = ActionController::Base.new.view_context
        @context.stub(:params).and_return({id: @simulator.to_param, draw: 1, start: 0, length:10, "order" => {"0" => {"column" => "4", "dir" => "asc"}, "1" => {"column" => "0", "dir" => "desc"}}})
        @context.stub(:link_to) {|str, link_path| link_path }
        @context.stub(:shortened_id_monospaced).and_return("id")
        @context.stub(:analyzer_path).and_return("/analyzers/00000000")
        @azrld = AnalyzersListDatatable.new(@context)
        @azrld_json = JSON.parse(@azrld.to_json)
      end

      it "resutnr json" do
        expect(@azrld_json["recordsTotal"]).to eq 25
        expect(@azrld_json["recordsFiltered"]).to eq 25
        expect(@azrld_json["data"].size).to eq 10
        expect(@azrld_json["data"][0][2].to_s).to eq @simulator.analyzers.order_by({"description"=>"asc", "id"=>"desc"}).first.name.to_s
      end
    end
  end
end
