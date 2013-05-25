AcmProto::Application.routes.draw do

  # Simulator-ParameterSet-Run relations
  resources :simulators, only: ["index", "show", "new", "create"] do
    member do
      post "_make_query" # for ajax
    end
    resources :parameter_sets, shallow: true, only: ["show","new","create"] do
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
