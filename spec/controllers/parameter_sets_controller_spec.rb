require 'spec_helper'

describe ParameterSetsController do

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # ParameterSetsController. Be sure to keep this updated too.
  def valid_session
    {}
  end
  
  describe "GET 'show'" do

    it "returns http success" do
      sim = FactoryGirl.create(:simulator,
                               parameter_sets_count: 1,
                               runs_count: 1,
                               analyzers_count: 1,
                               run_analysis: true)
      get 'show', {id: sim.parameter_sets.first}, valid_session
      expect(response).to be_success
    end

    it "assigns instance variables" do
      sim = FactoryGirl.create(:simulator,
                               parameter_sets_count: 1,
                               runs_count: 1,
                               analyzers_count: 1,
                               run_analysis: true)
      prm = sim.parameter_sets.first
      get 'show', {id: prm}, valid_session
      expect(assigns(:param_set)).to eq(prm)
    end
  end

  describe "GET new" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 0)
    end

    it "assigns instance variables @simulator and @param_set" do
      get 'new', {simulator_id: @sim}, valid_session
      expect(assigns(:param_set)).to be_a_new(ParameterSet)
      expect(assigns(:param_set)).to respond_to(:v)
    end
  end

  describe "GET duplicate" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 0)
      @ps = @sim.parameter_sets.first
    end

    it "assigns instance variables @simulator and @param_set with duplicated parameters" do
      get 'duplicate', {id: @ps}, valid_session
      expect(assigns(:param_set)).to be_a_new(ParameterSet)
      expect(assigns(:param_set)).to respond_to(:v)
      expect(assigns(:param_set).v).to eq(@ps.v)
    end
  end

  describe "POST create" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 0)
    end

    describe "with valid params" do

      before(:each) do
        parameters = {"L" => 10, "T" => 2.0}
        @valid_param = {simulator_id: @sim, v: parameters}
      end

      it "creates a new ParameterSet" do
        expect {
          post :create, @valid_param, valid_session
        }.to change(ParameterSet, :count).by(1)
      end

      it "redirects to the created parameter set" do
        post :create, @valid_param, valid_session
        expect(response).to redirect_to(ParameterSet.last)
      end

      it "creates runs if num_runs are given" do
        expect {
          post :create, @valid_param.update(num_runs: 3, run: {submitted_to: Host.first}), valid_session
        }.to change { Run.count }.by(3)
      end

      it "creates runs with mpi_procs/omp_threads/priority" do
        @sim.update_attribute(:support_mpi, true)
        @sim.update_attribute(:support_omp, true)
        post :create, @valid_param.update(num_runs: 1, run: {submitted_to: Host.first, mpi_procs: 8, omp_threads: 4, priority: 2, host_parameters: {} }), valid_session
        expect(Run.last.mpi_procs).to eq 8
        expect(Run.last.omp_threads).to eq 4
        expect(Run.last.priority).to eq 2
      end

      it "creates runs with host_parameters" do
        h = FactoryGirl.create(:host_with_parameters)
        h.executable_simulators.push @sim
        h.save!
        host_param = {"param1" => "foo", "param2" => "bar" }
        post :create, @valid_param.update(num_runs: 1, run: {submitted_to: h, host_parameters: host_param }), valid_session
        expect(Run.last.host_parameters).to eq host_param
      end

      context "when duplicated parameter_set exists" do

        before(:each) do
          FactoryGirl.create(:parameter_set,
                             simulator: @sim, v: {"L" => 1, "T" => 1.0},
                             runs_count: 1)
        end

        it "creates runs upto the specified number" do
          expect {
            post :create, @valid_param.update(v: {"L" => 1, "T" => 1.0}, num_runs: 3)
          }.to change { Run.count }.by(2)
        end
      end

      describe "creation of multiple parameter sets" do

        it "creates multiple parameter sets if comma-separated-values are given" do
          @valid_param.update(v: {"L" => "1,2,3", "T" => "1.0, 2.0, 3.0"})
          expect {
            post :create, @valid_param, valid_session
          }.to change { ParameterSet.count }.by(9)
        end

        it "redirects to simulator when multiple parameter sets were created" do
          @valid_param.update(v: {"L" => "1,2,3", "T" => "1.0, 2.0, 3.0"})
          post :create, @valid_param, valid_session
          expect(response).to redirect_to(@sim)
        end

        it "non-castable elements are skipped" do
          @valid_param.update(v: {"L" => "1, 2", "T" => "1.0, abc"})
          expect {
            post :create, @valid_param, valid_session
          }.to change { ParameterSet.count }.by(2)
        end

        it "redirects to parameter set when single paraemter set is created" do
          @valid_param.update(v: {"L" => "1", "T" => "1.0, abc"})
          post :create, @valid_param, valid_session
          expect(response).to redirect_to(ParameterSet.last)
        end

        it "does not create duplicated parameter set" do
          @valid_param.update(v: {"L" => "1", "T" => "1.0, 1.0"})
          expect {
            post :create, @valid_param, valid_session
          }.to change { ParameterSet.count }.by(1)
        end

        it "creates runs for each created parameter set" do
          @valid_param.update(v: {"L" => "1", "T" => "1.0, 2.0"}, num_runs: 3, run: {submitted_to: Host.first})
          expect {
            post :create, @valid_param, valid_session
          }.to change { Run.count }.by(6)
        end

        context "when sequential_seed is true" do

          it "creates multiple parameter sets with sequential seeds" do
            @valid_param.update(v: {"L" => "1", "T" => "1.0, 2.0"},
                                num_runs: 3, run: {submitted_to: Host.first} )
            post :create, @valid_param, valid_session
            @sim.parameter_sets.each do |ps|
              expect( ps.runs.map(&:seed) ).to match_array [1,2,3]
            end
          end
        end

        describe "when some of parameter_sets are already created" do

          before(:each) do
            FactoryGirl.create(:parameter_set,
                               simulator: @sim, v: {"L" => 1, "T" => 1.0},
                               runs_count: 1)
          end

          it "skips creation of existing parameter_sets" do
            @valid_param.update( v: {"L" => "1", "T" => "1.0,2.0"} )
            expect {
              post :create, @valid_param, valid_session
            }.to change { ParameterSet.count }.by(1)
          end

          it "creates runs also for existing parameter_sets upto the specified num_runs" do
            @valid_param.update(v: {"L" => "1", "T" => "1.0,2.0"}, num_runs: 3)
            expect {
              post :create, @valid_param, valid_session
            }.to change { Run.count }.by(5)
          end

          it "redirects to simulator when multiple parameter sets are specified" do
            @valid_param.update(v: {"L" => "1", "T" => "1.0,2.0"}, num_runs: 3)
            post :create, @valid_param, valid_session
            expect(response).to redirect_to(@sim)
          end

          it "shows an error when no parameter_sets or runs are created" do
            @valid_param.update(v: {"L" => 1, "T" => 1.0}, num_runs: 1)
            post :create, @valid_param, valid_session
            expect(response).to render_template("new")
          end
        end
      end
    end

    describe "with invalid params" do

      before(:each) do
        parameters = {"L" => 10, "T" => "abc"}
        @invalid_param = {simulator_id: @sim, v: parameters}
      end

      it "assigns a new ParameterSet as @param_set" do
        expect {
          post :create, @invalid_param, valid_session
          expect(assigns(:param_set)).to be_a_new(ParameterSet)
        }.to_not change(ParameterSet, :count)
      end

      it "re-renders the 'new' template" do
        post :create, @invalid_param, valid_session
        expect(response).to render_template("new")
      end

      describe "creation of multiple parameter sets" do

        it "does not create a ParameterSet if too much parameter sets are going to be created" do
          @invalid_param.update(v: {"L" => "1,2,3,4,5,6,7,8,9,10,11,12",
                                    "T" => "1,2,3,4,5,6,7,8,9,10,11,12" })
          expect {
            post :create, @invalid_param, valid_session
          }.to_not change { ParameterSet.count }
        end

        it "re-renders 'new' template" do
          @invalid_param.update(v: {"L" => "1,2,3,4,5,6,7,8,9,10,11,12",
                                    "T" => "1,2,3,4,5,6,7,8,9,10,11,12" })
          post :create, @invalid_param, valid_session
          expect(response).to render_template("new")
        end
      end

      describe "invalid host_parameters" do

        before(:each) do
          @sim.support_mpi = true
          @sim.save!
        end

        it "does not create parameter_sets or runs" do
          parameters = {"L" => 10, "T" => 2.0}
          invalid_param = {simulator_id: @sim, v: parameters, num_runs: 1, run: {mpi_procs: -1}}
          expect {
            post :create, invalid_param, valid_session
          }.to_not change { ParameterSet.count }
        end
      end
    end

    describe "with no permitted params" do

      before(:each) do
        parameters = {"L" => 10, "T" => 1.0}
        @valid_params = {simulator_id: @sim, v: parameters}
      end

      it "create new ps but no permitted params are not saved" do
        invalid_params = @valid_params.update(runs_status_count_cache: {"kill"=>"all"})
                                      .update(progress_rate_cache: 123)
                                      .update(invalid: 1)
        expect {
          post :create, invalid_params, valid_session
        }.to change {ParameterSet.count}.by(1)
        ps = ParameterSet.last
        expect(ps.runs_status_count_cache).not_to eq ({"kill"=>"all"})
        expect(ps.progress_rate_cache).not_to eq 123
      end
    end

    describe "when Boolean parameters are included" do

      before(:each) do
        pds = [ {key: "I", type: "Integer", default: 50},
                {key: "B", type: "Boolean", default: true}]
        pds.map! {|h| ParameterDefinition.new(h) }
        @sim = FactoryGirl.create(:simulator,
                                  parameter_definitions: pds,
                                  parameter_sets_count: 0,
                                  analyzers_count: 0)
      end

      it "creates a parameter_sets correctly when the boolean parameter is false" do
        valid_param = {simulator_id: @sim, v: {"B" => "false"}}
        post :create, valid_param, valid_session
        expect(@sim.parameter_sets.first.v["B"]).to eq false
      end
    end
  end

  describe "GET _create_cli" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 0)
      parameters = {"L" => 10, "T" => 2.0}
      @valid_param = {simulator_id: @sim, v: parameters}
    end

    it "returns CLI command" do
      get :_create_cli, @valid_param, valid_session
      expect(response).to be_success
      expect(response.body).to eq <<-EOS.chomp
./bin/oacis_cli create_parameter_sets -s #{@sim.id} -i '{"L":10,"T":2.0}' -o ps.json
      EOS
    end

    it "returns CLI with valid runs_option" do
      h = FactoryGirl.create(:host_with_parameters)
      h.executable_simulators.push @sim
      h.save!
      @valid_param[:run] = {mpi_procs:"4",omp_threads:"8",priority:"2", submitted_to: h.id.to_s,
                            host_parameters: {"param1" => "xxx", "param2" => "yyy"} }
      @valid_param[:num_runs] = 3

      get :_create_cli, @valid_param, valid_session
      expect(response).to be_success
      expect(response.body).to eq <<-EOS.chomp
./bin/oacis_cli create_parameter_sets -s #{@sim.id} -i '{"L":10,"T":2.0}' -r '{"num_runs":3,"mpi_procs":4,"omp_threads":8,"priority":2,"submitted_to":"#{h.id.to_s}","host_parameters":{"param1":"xxx","param2":"yyy"}}' -o ps.json
      EOS
    end
  end

  describe "DELETE destroy" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      @ps = @sim.parameter_sets.first
    end

    it "reduces the number of parameter_sets in default scope" do
      expect {
        delete :destroy, {id: @ps.to_param}, valid_session
      }.to change(ParameterSet, :count).by(-1)
    end

    it "does not destroy ParameterSet" do
      expect {
        delete :destroy, {id: @ps.to_param}, valid_session
      }.to_not change{ ParameterSet.unscoped.count }
    end

    context "called by remote:true" do

      it "respond to simulator show" do
        delete :destroy, {id: @ps.to_param, format: :js}, valid_session
        expect(response).not_to redirect_to(@sim)
      end
    end

    context "called by parameter_set#show" do

      it "respond to simulator show" do
        delete :destroy, {id: @ps.to_param, format: :html}, valid_session
        expect(response).to redirect_to(@sim)
      end
    end
  end

  describe "GET _runs_list" do
    before(:each) do
      @simulator = FactoryGirl.create(:simulator,
                                      parameter_sets_count: 1, runs_count: 30,
                                      analyzers_count: 0, run_analysis: false,
                                      parameter_set_queries_count: 0
                                      )
      @param_set = @simulator.parameter_sets.first
      get :_runs_list, {id: @param_set.to_param, draw: 1, start: 0, length:25 , "order" => {"0" => {"column" => "0", "dir" => "asc"}}}, :format => :json
      @parsed_body = JSON.parse(response.body)
    end

    it "return json format" do
      expect(response.header['Content-Type']).to include 'application/json'
      expect(@parsed_body["recordsTotal"]).to eq 30
      expect(@parsed_body["recordsFiltered"]).to eq 30
    end

    it "paginates the list of parameters" do
      expect(@parsed_body["data"].size).to eq 25
    end
  end

  describe "GET _similar_parameter_sets_list" do

    before(:each) do
      parameter_definitions = [
        ParameterDefinition.new(key: "I", type: "Integer", default: 0),
        ParameterDefinition.new(key: "F", type: "Float", default: 1.0),
        ParameterDefinition.new(key: "S", type: "String", default: 'abc'),
        ParameterDefinition.new(key: "B", type: "Boolean", default: false)
      ]

      @simulator = FactoryGirl.create(:simulator,
                                      parameter_definitions: parameter_definitions,
                                      parameter_sets_count: 0
                                      )
      [0,1,2].each do |i|
        [0.0, 1.0, 2.0].each do |f|
          ['a', 'b', 'c'].each do |s|
            [true, false].each do |b|
              @simulator.parameter_sets.create!(v: {'I'=>i,'F'=>f,'S'=>s,'B'=>b})
            end
          end
        end
      end
      @param_set = @simulator.parameter_sets.where('v.I'=>1,'v.F'=>1.0,'v.S'=>'b','v.B'=>true).first
      get :_similar_parameter_sets_list, {id: @param_set.to_param, draw: 1, start: 0, length:25 , "order" => {"0" => {"column" => "0", "dir" => "asc"}}}, :format => :json
      @parsed_body = JSON.parse(response.body)
    end

    it "return json format" do
      expect(response).to be_success
      expect(response.header['Content-Type']).to include 'application/json'
    end

    it "returns correct number of parameter sets" do
      parsed_body = JSON.parse(response.body)
      expect(parsed_body['recordsTotal']).to eq 8
    end
  end

  describe "GET _line_plot" do

    before(:each) do
      pds = [ {key: "L", type: "Integer", default: 50, description: "First parameter"},
              {key: "T", type: "Float", default: 1.0, description: "Second parameter"},
              {key: "P", type: "Float", default: 1.0, description: "Third parameter"}]
      pds.map! {|h| ParameterDefinition.new(h) }
      @sim = FactoryGirl.create(:simulator,
                               parameter_definitions: pds,
                               parameter_sets_count: 0,
                               analyzers_count: 0)
      param_values = [ {"L" => 1, "T" => 1.0, "P" => 1.0},
                       {"L" => 2, "T" => 1.0, "P" => 1.0},
                       {"L" => 3, "T" => 1.0, "P" => 1.0},
                       {"L" => 1, "T" => 2.0, "P" => 1.0},
                       {"L" => 2, "T" => 2.0, "P" => 1.0},
                       {"L" => 3, "T" => 2.0, "P" => 2.0}  # P is different from others
                     ]
      host = FactoryGirl.create(:host)
      @ps_array = param_values.map do |v|
        ps = @sim.parameter_sets.create(v: v)
        run = ps.runs.create
        run.status = :finished
        run.submitted_to = host
        run.create_job_result(submittable_parameter: run.parameter_set, result: {"ResultKey1" => 99})
        run.cpu_time = 10.0
        run.real_time = 3.0
        run.save!
        ps
      end
    end

    it "returns in json format" do
      get :_line_plot,
        {id: @ps_array.first, x_axis_key: "L", y_axis_key: ".ResultKey1", series: "", irrelevants: "", format: :json}
      expect(response.header['Content-Type']).to include 'application/json'
    end

    it "returns valid json" do
      get :_line_plot,
        {id: @ps_array.first, x_axis_key: "L", y_axis_key: ".ResultKey1", series: "", irrelevants: "", format: :json}
      expected = {
        xlabel: "L", ylabel: "ResultKey1", series: "", series_values: [], irrelevants: [],
        plot_url: parameter_set_url(@ps_array.first) + "?plot_type=line&x_axis=L&y_axis=.ResultKey1&series=&irrelevants=#!tab-plot",
        data: [
          [
            [1, 99.0, nil, @ps_array[0].id.to_s],
            [2, 99.0, nil, @ps_array[1].id.to_s],
            [3, 99.0, nil, @ps_array[2].id.to_s],
          ]
        ]
      }.to_json
      expect(response.body).to eq expected
    end

    it "returns elapsed times when 'real_time' or 'cpu_time' is specified as y_axis_key" do
      get :_line_plot,
        {id: @ps_array.first, x_axis_key: "L", y_axis_key: "cpu_time", series: "", irrelevants: "", format: :json}
      expected = {
        xlabel: "L", ylabel: "cpu_time", series: "", series_values: [], irrelevants: [],
        plot_url: parameter_set_url(@ps_array.first) + "?plot_type=line&x_axis=L&y_axis=cpu_time&series=&irrelevants=#!tab-plot",
        data: [
          [
            [1, 10.0, nil, @ps_array[0].id.to_s],
            [2, 10.0, nil, @ps_array[1].id.to_s],
            [3, 10.0, nil, @ps_array[2].id.to_s],
          ]
        ]
      }.to_json
      expect(response.body).to eq expected
    end

    context "when parameter 'series' is given" do

      it "returns series of data when parameter 'series' is given" do
        get :_line_plot,
          {id: @ps_array.first, x_axis_key: "L", y_axis_key: ".ResultKey1", series: "T", irrelevants: "", format: :json}
        expected = {
          xlabel: "L", ylabel: "ResultKey1", series: "T", series_values: [2.0, 1.0], irrelevants: [],
          plot_url: parameter_set_url(@ps_array.first) + "?plot_type=line&x_axis=L&y_axis=.ResultKey1&series=T&irrelevants=#!tab-plot",
          data: [
            [
              [1, 99.0, nil, @ps_array[3].id.to_s],
              [2, 99.0, nil, @ps_array[4].id.to_s],
            ],
            [
              [1, 99.0, nil, @ps_array[0].id.to_s],
              [2, 99.0, nil, @ps_array[1].id.to_s],
              [3, 99.0, nil, @ps_array[2].id.to_s]
            ]
          ]
        }.to_json
        expect(response.body).to eq expected
      end
    end

    context "when 'irrelevants' are given" do

      it "data includes parameter sets having different irrelevant parameters " do
        get :_line_plot,
          {id: @ps_array.first, x_axis_key: "L", y_axis_key: ".ResultKey1", series: "T", irrelevants: "P", format: :json}
        expected = {
          xlabel: "L", ylabel: "ResultKey1", series: "T", series_values: [2.0, 1.0], irrelevants: ["P"],
          plot_url: parameter_set_url(@ps_array.first) + "?plot_type=line&x_axis=L&y_axis=.ResultKey1&series=T&irrelevants=P#!tab-plot",
          data: [
            [
              [1, 99.0, nil, @ps_array[3].id.to_s],
              [2, 99.0, nil, @ps_array[4].id.to_s],
              [3, 99.0, nil, @ps_array[5].id.to_s]
            ],
            [
              [1, 99.0, nil, @ps_array[0].id.to_s],
              [2, 99.0, nil, @ps_array[1].id.to_s],
              [3, 99.0, nil, @ps_array[2].id.to_s]
            ]
          ]
        }.to_json
        expect(response.body).to eq expected
      end
    end
  end

  describe "GET _scatter_plot" do

    before(:each) do
      pds = [ {key: "L", type: "Integer", default: 50, description: "First parameter"},
              {key: "T", type: "Float", default: 1.0, description: "Second parameter"},
              {key: "P", type: "Float", default: 1.0, description: "Third parameter"}]
      pds.map! {|h| ParameterDefinition.new(h) }
      @sim = FactoryGirl.create(:simulator,
                               parameter_definitions: pds,
                               parameter_sets_count: 0,
                               analyzers_count: 0)
      param_values = [ {"L" => 1, "T" => 1.0, "P" => 1.0},
                       {"L" => 2, "T" => 1.0, "P" => 1.0},
                       {"L" => 3, "T" => 1.0, "P" => 1.0},
                       {"L" => 1, "T" => 2.0, "P" => 1.0},
                       {"L" => 2, "T" => 2.0, "P" => 1.0},
                       {"L" => 3, "T" => 2.0, "P" => 2.0}  # P is different from others
                     ]
      host = FactoryGirl.create(:host)
      @ps_array = param_values.map do |v|
        ps = @sim.parameter_sets.create(v: v)
        run = ps.runs.create
        run.status = :finished
        run.cpu_time = 10.0
        run.real_time = 3.0
        run.submitted_to = host
        run.create_job_result(submittable_parameter: run.parameter_set, result: {"ResultKey1" => 99})
        run.save!
        ps
      end
    end

    it "returns in json format" do
      get :_scatter_plot,
        {id: @ps_array.first, x_axis_key: "L", y_axis_key: "T", result: ".ResultKey1", irrelevants: "", format: :json}
      expect(response.header['Content-Type']).to include 'application/json'
    end

    it "returns valid json" do
      get :_scatter_plot,
        {id: @ps_array.first, x_axis_key: "L", y_axis_key: "T", result: ".ResultKey1", irrelevants: "", format: :json}
      expected_data = [
        [@ps_array[0].v, 99.0, nil, @ps_array[0].id.to_s],
        [@ps_array[3].v, 99.0, nil, @ps_array[3].id.to_s],
        [@ps_array[1].v, 99.0, nil, @ps_array[1].id.to_s],
        [@ps_array[4].v, 99.0, nil, @ps_array[4].id.to_s],
        [@ps_array[2].v, 99.0, nil, @ps_array[2].id.to_s]
      ]

      loaded = JSON.load(response.body)
      expect(loaded["xlabel"]).to eq "L"
      expect(loaded["ylabel"]).to eq "T"
      expect(loaded["result"]).to eq "ResultKey1"
      expect(loaded["irrelevants"]).to eq []
      expect(loaded["data"]).to match_array(expected_data)
    end

    it "returns records specified by range" do
      get :_scatter_plot,
        { id: @ps_array.first,
          x_axis_key: "L", y_axis_key: "T", result: ".ResultKey1",
          irrelevants: "", range: {"L" => [1,2]}.to_json,
          format: :json}
      expected_data = [
        [@ps_array[0].v, 99.0, nil, @ps_array[0].id.to_s],
        [@ps_array[3].v, 99.0, nil, @ps_array[3].id.to_s],
        [@ps_array[1].v, 99.0, nil, @ps_array[1].id.to_s],
        [@ps_array[4].v, 99.0, nil, @ps_array[4].id.to_s]
      ]

      loaded = JSON.load(response.body)
      expect(loaded["xlabel"]).to eq "L"
      expect(loaded["ylabel"]).to eq "T"
      expect(loaded["result"]).to eq "ResultKey1"
      expect(loaded["irrelevants"]).to eq []
      expect(loaded["data"]).to match_array(expected_data)
    end

    it "returns elapsed time when params[:result] is 'cpu_time' or 'real_time'" do
      get :_scatter_plot,
        {id: @ps_array.first, x_axis_key: "L", y_axis_key: "T", result: "cpu_time", irrelevants: "", format: :json}
      expected_data = [
        [@ps_array[0].v, 10.0, nil, @ps_array[0].id.to_s],
        [@ps_array[3].v, 10.0, nil, @ps_array[3].id.to_s],
        [@ps_array[1].v, 10.0, nil, @ps_array[1].id.to_s],
        [@ps_array[4].v, 10.0, nil, @ps_array[4].id.to_s],
        [@ps_array[2].v, 10.0, nil, @ps_array[2].id.to_s]
      ]

      loaded = JSON.load(response.body)
      expect(loaded["xlabel"]).to eq "L"
      expect(loaded["ylabel"]).to eq "T"
      expect(loaded["result"]).to eq "cpu_time"
      expect(loaded["irrelevants"]).to eq []
      expect(loaded["data"]).to match_array(expected_data)
    end

    it "returns collect values when irrelevant keys are given" do
      get :_scatter_plot,
        {id: @ps_array.first, x_axis_key: "L", y_axis_key: "T", result: "cpu_time", irrelevants: "P", format: :json}

      loaded = JSON.load(response.body)
      expect(loaded["xlabel"]).to eq "L"
      expect(loaded["ylabel"]).to eq "T"
      expect(loaded["result"]).to eq "cpu_time"
      expect(loaded["irrelevants"]).to eq ["P"]
      expect(loaded["data"]).to include( [@ps_array[5].v, 10.0, nil, @ps_array[5].id.to_s] )
    end

    it "contains url for the plot" do
      get :_scatter_plot,
        {id: @ps_array.first, x_axis_key: "L", y_axis_key: "T", result: "cpu_time", irrelevants: "P", format: :json}
      loaded = JSON.load(response.body)
      expect(loaded["plot_url"]).to match (/\?plot_type=scatter&x_axis=L&y_axis=T&result=cpu_time&irrelevants=P\#\!tab-plot$/)
    end
  end

  describe "GET _figure_viewer" do

    before(:each) do
      pds = [ {key: "L", type: "Integer", default: 50, description: "First parameter"},
              {key: "T", type: "Float", default: 1.0, description: "Second parameter"},
              {key: "P", type: "Float", default: 1.0, description: "Third parameter"}]
      pds.map! {|h| ParameterDefinition.new(h) }
      @sim = FactoryGirl.create(:simulator,
                               parameter_definitions: pds,
                               parameter_sets_count: 0,
                               analyzers_count: 0)
      param_values = [ {"L" => 1, "T" => 1.0, "P" => 1.0},
                       {"L" => 2, "T" => 1.0, "P" => 1.0},
                       {"L" => 3, "T" => 1.0, "P" => 1.0},
                       {"L" => 1, "T" => 2.0, "P" => 1.0},
                       {"L" => 2, "T" => 2.0, "P" => 1.0},
                       {"L" => 3, "T" => 2.0, "P" => 2.0}  # P is different from others
                     ]
      host = FactoryGirl.create(:host)
      @ps_array = param_values.map do |v|
        ps = @sim.parameter_sets.create(v: v)
        run = ps.runs.create
        run.status = :finished
        run.submitted_to = host
        run.save!
        FileUtils.touch( run.dir.join("fig1.png") )
        ps
      end
    end

    it "returns in json format" do
      get :_figure_viewer,
        {id: @ps_array.first, x_axis_key: "L", y_axis_key: "T", result: "/fig1.png", irrelevants: "", logscales: "", format: :json}
      expect(response.header['Content-Type']).to include 'application/json'
    end

    def path_to_fig(ps)
      path = ps.runs.first.dir.join("fig1.png")
      ApplicationController.helpers.file_path_to_link_path(path).to_s
    end

    it "returns valid json" do
      get :_figure_viewer,
        {id: @ps_array.first, x_axis_key: "L", y_axis_key: "T", result: "/fig1.png", irrelevants: "", format: :json}
      expected_data = [
        [1, 1.0, path_to_fig(@ps_array[0]), @ps_array[0].id.to_s],
        [1, 2.0, path_to_fig(@ps_array[3]), @ps_array[3].id.to_s],
        [2, 1.0, path_to_fig(@ps_array[1]), @ps_array[1].id.to_s],
        [2, 2.0, path_to_fig(@ps_array[4]), @ps_array[4].id.to_s],
        [3, 1.0, path_to_fig(@ps_array[2]), @ps_array[2].id.to_s]
      ]

      loaded = JSON.load(response.body)
      expect(loaded["xlabel"]).to eq "L"
      expect(loaded["ylabel"]).to eq "T"
      expect(loaded["result"]).to eq "/fig1.png"
      expect(loaded["irrelevants"]).to eq []
      expect(loaded["data"]).to match_array(expected_data)
    end

    it "returns irrelevant keys" do
      get :_figure_viewer,
        {id: @ps_array.first, x_axis_key: "L", y_axis_key: "T", result: "/fig1.png", irrelevants: "P", format: :json}

      loaded = JSON.load(response.body)
      expect(loaded["irrelevants"]).to eq ["P"]
      expect(loaded["data"]).to include( [3, 2.0, path_to_fig(@ps_array[5]), @ps_array[5].id.to_s] )
    end

    it "contains url for the plot" do
      get :_figure_viewer,
        {id: @ps_array.first, x_axis_key: "L", y_axis_key: "T", result: "/fig1.png", irrelevants: "P", format: :json}
      loaded = JSON.load(response.body)
      expect(loaded["plot_url"]).to match (/\?plot_type=figure&x_axis=L&y_axis=T&result=%2Ffig1.png&irrelevants=P\#\!tab-plot$/)
    end

    context "when run is not created for all runs" do

      before(:each) do
        @ps_array[1].runs.first.destroy
      end

      it "empty fig_path is returned for missing run" do
        get :_figure_viewer,
          {id: @ps_array.first, x_axis_key: "L", y_axis_key: "T", result: "/fig1.png", irrelevants: "", format: :json}
        expected_data = [
          [1, 1.0, path_to_fig(@ps_array[0]), @ps_array[0].id.to_s],
          [1, 2.0, path_to_fig(@ps_array[3]), @ps_array[3].id.to_s],
          [2, 1.0, '', @ps_array[1].id.to_s],
          [2, 2.0, path_to_fig(@ps_array[4]), @ps_array[4].id.to_s],
          [3, 1.0, path_to_fig(@ps_array[2]), @ps_array[2].id.to_s]
        ]

        expect(JSON.load(response.body)["data"]).to match_array(expected_data)
      end
    end
  end
end
