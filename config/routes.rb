AcmProto::Application.routes.draw do

  resources :runs, only: ["index"] do
    collection do
      get "_jobs_table" # for ajax, datatables
    end
  end

  # Simulator-ParameterSet-Run relations
  resources :simulators, shallow: true, only: ["index", "show", "new", "create", "edit", "update", "destroy"] do
    member do
      get 'duplicate'
      get 'explore'
      post "_make_query" # for ajax
      get "_parameters_list" # for ajax, datatables
      get "_analyzer_list" # for ajax, datatables
      get "_progress" # for progress table
    end
    resources :parameter_sets, only: ["show","new","create","destroy"] do
      member do
        get 'duplicate'
        get "_runs_and_analyses" # for ajax, get
        get "_runs_list" # for ajax, datatables
        get "_analyses_list" # for ajax, datatables
        get "_line_plot" # for line plot
        get "_scatter_plot" # for scatter plot
      end
      resources :runs, only: ["show","create", "destroy"] do
        member do
          get "_analyses_list" # for ajax, datatables
        end
        resources :analyses, :only => ["show", "create", "destroy"] do
          member do
            get "_result" # for ajax
          end
        end
      end
      resources :analyses, :only => ["show", "create", "destroy"]
    end
    resources :analyzers, only: ["show", "new", "create", "edit", "update", "destroy"] do
      member do
        get '_parameters_form' # for ajax
        get "_inner_show" # for ajax, get
      end
    end
  end

  resources :hosts

  root :to => "simulators#index"
end
