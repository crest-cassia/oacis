require 'spec_helper'

describe "FilesListDatatable" do

  describe "GET _files_list" do
    before(:each) do
      @simulator = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 30)
      @param_set = @simulator.parameter_sets.first
      @runs = @param_set.runs
      @context = ActionController::Base.new.view_context
      allow(@context).to receive(:params).and_return({ id: @param_set.to_param, draw: 1, start: 0, length: 25, file_name: 'bar.png' })
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
      allow_any_instance_of(Run).to receive(:result_paths).and_return([Pathname.new('/test/foo.png'), Pathname.new('/test/bar.png')])
      @fld = FilesListDatatable.new(@runs, @context)
      @fld_json = JSON.parse(@fld.to_json)
    end

    it "is initialized" do
      expect( @fld.instance_variable_get(:@runs) ).to match_array @runs
    end

    it "return json" do
      expect(@fld_json["recordsTotal"]).to eq 30
      expect(@fld_json["recordsFiltered"]).to eq 30
      expect(@fld_json["data"].size).to eq 25
      expect(@fld_json["data"][0][0].to_s).to eq @runs.order_by("updated_at desc").first.id.to_s
      expect( @fld_json["data"][0][1]).to include '/test/bar.png'
    end
  end
end
