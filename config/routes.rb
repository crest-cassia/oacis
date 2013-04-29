AcmProto::Application.routes.draw do

  resources :simulators, :only => ["index", "show"] do
    resources :parameter_sets, :shallow => true, :only => ["show"] do
      resources :runs, :only => ["show","create"]
    end

    resources :analyzers, :only => ["show"]
  end

  mount Resque::Server, :at => '/resque'

  authenticated :user do
    root :to => 'home#index'
  end
  root :to => "home#index"
  devise_for :users
  resources :users
end