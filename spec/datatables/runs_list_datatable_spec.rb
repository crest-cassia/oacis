require 'spec_helper'

describe "RunsListDatatable" do

  describe "GET _runs_list" do

    before(:each) do
      @simulator = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 30)
      @param_set = @simulator.parameter_sets.first
      @runs = @param_set.runs
      @context = ActionController::Base.new.view_context
      @context.stub(:params).and_return({id: @param_set.to_param, draw: 1, start: 0, length:25 , "order" => {"0" => {"culumn" => "0", "dir" => "desc"}}})
      @context.stub(:link_to) {|str, link_path| link_path }
      @context.stub(:run_path) {|run| run.id.to_s }
      @context.stub(:priority) {|run| Run::PRIORITY_ORDER[run.priority].to_s }
      @context.stub(:distance_to_now_in_words).and_return("time")
      @context.stub(:formatted_elapsed_time).and_return("time")
      @context.stub(:raw).and_return("label")
      @context.stub(:status_label).and_return("status_label")
      @context.stub(:shortened_id_monospaced).and_return("xxxx..yy")
      @context.stub(:host_path).and_return("/host/xxx")
      @context.stub(:shortened_job_id).and_return("123456..")
      @rld = RunsListDatatable.new(@runs, @context)
      @rld_json = JSON.parse(@rld.to_json)
    end

    it "is initialized" do
      expect(@rld.instance_variable_get(:@runs)).to eq Run.where(:parameter_set_id => @param_set.to_param)
    end

    it "return json" do
      expect(@rld_json["recordsTotal"]).to eq 30
      expect(@rld_json["recordsFiltered"]).to eq 30
      expect(@rld_json["data"].size).to eq 25
      expect(@rld_json["data"][0][0].to_s).to eq @runs.order_by("id desc").first.id.to_s
    end

    context "with multiple sort" do

    before(:each) do
      @simulator = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 30)
      @param_set = @simulator.parameter_sets.first
      @runs = @param_set.runs
      run = @runs.first
      run.priority = :low
      run.save
      @context = ActionController::Base.new.view_context
      @context.stub(:params).and_return({id: @param_set.to_param, draw: 1, start: 0, length:25 , "order" => {"0" => {"column" => "2", "dir" => "asc"}, "1" => {"column" => "0", "dir" => "desc"}}})
      @context.stub(:link_to) {|str, link_path| link_path }
      @context.stub(:run_path) {|run| run.id.to_s }
      @context.stub(:priority) {|run| Run::PRIORITY_ORDER[run.priority].to_s }
      @context.stub(:distance_to_now_in_words).and_return("time")
      @context.stub(:formatted_elapsed_time).and_return("time")
      @context.stub(:raw).and_return("label")
      @context.stub(:status_label).and_return("status_label")
      @context.stub(:shortened_id_monospaced).and_return("xxxx..yy")
      @context.stub(:host_path).and_return("/host/xxx")
      @context.stub(:shortened_job_id).and_return("123456..")
      @rld = RunsListDatatable.new(@runs, @context)
      @rld_json = JSON.parse(@rld.to_json)
    end

      it "return json" do
        expect(@rld_json["recordsTotal"]).to eq 30
        expect(@rld_json["recordsFiltered"]).to eq 30
        expect(@rld_json["data"].size).to eq 25
        expect(@rld_json["data"][0][0].to_s).not_to eq @runs.order_by({"id"=>" desc"}).first.id.to_s
        expect(@rld_json["data"][0][0].to_s).to eq @runs.order_by({"priority"=>"asc", "id"=>" desc"}).first.id.to_s
      end
    end
  end
end

