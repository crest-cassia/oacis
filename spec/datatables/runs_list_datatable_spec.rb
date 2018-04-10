require 'spec_helper'

describe "RunsListDatatable" do

  describe "GET _runs_list" do

    before(:each) do
      @simulator = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 30)
      @param_set = @simulator.parameter_sets.first
      @runs = @param_set.runs
      @context = ActionController::Base.new.view_context
      allow(@context).to receive(:params).and_return({id: @param_set.to_param, draw: 1, start: 0, length:25 , "order" => {"0" => {"column" => "1", "dir" => "desc"}}})
      allow(@context).to receive(:link_to) {|str, link_path| link_path }
      allow(@context).to receive(:run_path) {|run| run.id.to_s }
      allow(@context).to receive(:priority) {|run| Run::PRIORITY_ORDER[run.priority].to_s }
      allow(@context).to receive(:distance_to_now_in_words).and_return("time")
      allow(@context).to receive(:formatted_elapsed_time).and_return("time")
      allow(@context).to receive(:raw).and_return("label")
      allow(@context).to receive(:status_label).and_return("status_label")
      allow(@context).to receive(:shortened_id_monospaced).and_return("xxxx..yy")
      allow(@context).to receive(:host_path).and_return("/host/xxx")
      allow(@context).to receive(:shortened_job_id).and_return("123456..")
      @rld = RunsListDatatable.new(@runs, @context)
      @rld_json = JSON.parse(@rld.to_json)
    end

    it "is initialized" do
      expect( @rld.instance_variable_get(:@runs) ).to match_array @runs
    end

    it "return json" do
      expect(@rld_json["recordsTotal"]).to eq 30
      expect(@rld_json["recordsFiltered"]).to eq 30
      expect(@rld_json["data"].size).to eq 25
      expect(@rld_json["data"][0][1].to_s).to eq @runs.order_by("id desc").first.id.to_s
    end

    context "with multiple sort" do

      before(:each) do
        @simulator = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 30)
        @param_set = @simulator.parameter_sets.first
        @runs = @param_set.runs
        run = @runs.first
        run.priority = :low
        run.save
        @context = ActionController::Base.new.view_context
        allow(@context).to receive(:params).and_return({id: @param_set.to_param, draw: 1, start: 0, length:25 , "order" => {"0" => {"column" => "3", "dir" => "asc"}, "1" => {"column" => "1", "dir" => "desc"}}})
        allow(@context).to receive(:link_to) {|str, link_path| link_path }
        allow(@context).to receive(:run_path) {|run| run.id.to_s }
        allow(@context).to receive(:priority) {|run| Run::PRIORITY_ORDER[run.priority].to_s }
        allow(@context).to receive(:distance_to_now_in_words).and_return("time")
        allow(@context).to receive(:formatted_elapsed_time).and_return("time")
        allow(@context).to receive(:raw).and_return("label")
        allow(@context).to receive(:status_label).and_return("status_label")
        allow(@context).to receive(:shortened_id_monospaced).and_return("xxxx..yy")
        allow(@context).to receive(:host_path).and_return("/host/xxx")
        allow(@context).to receive(:shortened_job_id).and_return("123456..")
        @rld = RunsListDatatable.new(@runs, @context)
        @rld_json = JSON.parse(@rld.to_json)
      end

      it "return json" do
        expect(@rld_json["recordsTotal"]).to eq 30
        expect(@rld_json["recordsFiltered"]).to eq 30
        expect(@rld_json["data"].size).to eq 25
        expect(@rld_json["data"][0][1].to_s).to eq @runs.order_by({"priority"=>"asc", "id"=>" desc"}).first.id.to_s
      end
    end
  end
end

