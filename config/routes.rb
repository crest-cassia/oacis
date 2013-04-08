AcmProto::Application.routes.draw do
  resources :simulators, :only => ["index", "show"]

  authenticated :user do
    root :to => 'home#index'
  end
  root :to => "home#index"
  devise_for :users
  resources :users
end