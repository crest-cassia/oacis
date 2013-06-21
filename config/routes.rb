AcmProto::Application.routes.draw do

  # Simulator-ParameterSet-Run relations
  resources :simulators, shallow: true, only: ["index", "show", "new", "create"] do
    member do
      post "_make_query" # for ajax
      get "_parameters_list" # for ajax, datatables
      get "_parameter_sets_status_count" # for ajax, progress bar
      get "_analyses_list" # for ajax
    end
    resources :parameter_set_groups, only: [] do
      resources :analysis_runs, :only => ["show"] do
        member do
          get "_result" # for ajax
        end
      end
    end
    resources :parameter_sets, only: ["show","new","create"] do
      member do
        get 'duplicate'
        get "_runs_status_count" # for ajax, progress bar
        get "_runs_table" # for ajax, datatables
        get "_runs_list" # for ajax, datatables
      end
      resources :runs, only: ["show","create"] do
        resources :analysis_runs, :only => ["show", "create"]
      end
      resources :analysis_runs, :only => ["show", "create"]
    end
  end

  # routes for analyzers and analysis_runs
  resources :simulators, shallow: false, only: [] do
    resources :analyzers, only: ["show"] do
      member do
        get '_parameters_form' # for ajax
      end
    end
  end

  mount Resque::Server, :at => '/resque'

  resources :hosts

  authenticated :user do
    root :to => 'home#index'
  end
  root :to => "home#index"
  devise_for :users
  resources :users
end
