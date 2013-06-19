AcmProto::Application.routes.draw do

  # Simulator-ParameterSet-Run relations
  resources :simulators, only: ["index", "show", "new", "create"] do
    member do
      post "_make_query" # for ajax
      get "_parameters_list" # for ajax, datatables
      get "_parameter_sets_status_count" # for ajax, progress bar
      get "_analyses_list"
    end
    resources :parameter_sets, shallow: true, only: ["show","new","create"] do
      member do
        get 'duplicate'
        get "_runs_status_count" # for ajax, progress bar
        get "_runs_table" # for ajax, datatables
        get "_runs_list" # for ajax, datatables
      end
      resources :runs, only: ["show","create"]
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
  resources :parameter_set_groups, shallow: false, only: [] do
    resources :analysis_runs, :only => ["show"]
  end
  resources :parameter_sets, shallow: false, only: [] do
    resources :analysis_runs, :only => ["show", "create"]
  end
  resources :runs, shallow: false, only: [] do
    resources :analysis_runs, :only => ["show", "create"]
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
