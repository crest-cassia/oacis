Rails.application.routes.draw do

  resources :worker_logs, only: ['index'] do
    collection do
      get "_contents"
    end
  end

  post '/parameter_sets/_delete_selected', to: 'parameter_sets#_delete_selected' if OACIS_ACCESS_LEVEL >= 1
  post '/parameter_sets/_create_runs_on_selected', to: 'parameter_sets#_create_runs_on_selected' if OACIS_ACCESS_LEVEL >= 1

  resources :runs, only: ["index"] do
    collection do
      get "_jobs_table" # for ajax, datatables
      post "_delete_selected" if OACIS_ACCESS_LEVEL >= 1
    end
  end

  resources :analyses, only: [] do
    collection do
      get "_analyses_table" # for ajax, datatables
    end
  end

  # Simulator-ParameterSet-Run relations
  simulator_actions = ["index", "show"]
  simulator_actions += ["new", "create", "edit", "update", "destroy"] if OACIS_ACCESS_LEVEL == 2
  resources :simulators, shallow: true, only: simulator_actions do
    collection do
      post "_sort" # for ajax, update order of the table
    end
    member do
      get "duplicate" if OACIS_ACCESS_LEVEL == 2
      get "export_runs"  # export runs in CSV
      get "_parameter_sets_list" # for ajax, datatables
      get "_analyzer_list" # for ajax, datatables
      get "_parameter_set_filters_list" # for ajax, datatables
      get "_progress" # for progress table
      get "_host_parameters_field" # for ajax, get the fields for host_parameters
      get "_default_mpi_omp" # for ajax, get the default mpi_procs and omp_threads
      get "_cancel_create_ps"
      post "save_filter" if OACIS_ACCESS_LEVEL >= 1
      post "_delete_filter" if OACIS_ACCESS_LEVEL >= 1
      get "_find_filter"
    end

    parameter_set_actions = ["show"]
    parameter_set_actions += ["new", "create", "destroy"] if OACIS_ACCESS_LEVEL >= 1
    resources :parameter_sets, only: parameter_set_actions do
      collection do
        get "_create_cli" # show CLI command for bulk creation
      end
      member do
        get "duplicate" if OACIS_ACCESS_LEVEL >= 1
        get "_runs_and_analyses" # for ajax, get
        get "_runs_list" # for ajax, datatables
        get "_analyses_list" # for ajax, datatables
        get "_similar_parameter_sets_list" # for ajax, datatables
        get "_line_plot" # for line plot
        get "_scatter_plot" # for scatter plot
        get "_figure_viewer" # for figure viewer
        get "_neighbor"
      end

      run_actions = ["show"]
      run_actions += ["create"] if OACIS_ACCESS_LEVEL >= 1
      analysis_actions = ["show"]
      analysis_actions += ["create", "destroy"] if OACIS_ACCESS_LEVEL >= 1
      resources :runs, only: run_actions do
        member do
          get "_analyses_list" # for ajax, datatables
        end
        resources :analyses, only: analysis_actions do
          member do
            get "_result" # for ajax
          end
        end
      end
      resources :analyses, only: analysis_actions
    end

    analyzer_actions = ["show"]
    analyzer_actions += ["new", "create", "edit", "update", "destroy"] if OACIS_ACCESS_LEVEL == 2
    resources :analyzers, only: analyzer_actions do
      member do
        get "_parameters_form" # for ajax
        get "_inner_show" # for ajax, get
        get "_host_parameters_field" # for ajax, get the fields for host_parameters
        get "_default_mpi_omp" # for ajax, get the default mpi_procs and omp_threads
      end
    end
  end

  host_actions = ["index", "show"]
  host_actions += ["new", "create", "edit", "update", "destroy"] if OACIS_ACCESS_LEVEL == 2
  resources :hosts, only: host_actions do
    member do
      get "_check_scheduler_status" if OACIS_ACCESS_LEVEL >= 1
      get "_toggle_status" if OACIS_ACCESS_LEVEL == 2
    end
    collection do
      post "_sort" # for ajax, update order of the table
    end
  end

  host_group_actions = ["show"]
  host_group_actions += ["new", "create", "edit", "update", "destroy"] if OACIS_ACCESS_LEVEL == 2
  resources :host_groups, only: host_group_actions do
  end

  root :to => "simulators#index"
end
