Rails.application.routes.draw do
  root "dashboard#index"
  
  resources :rooms do
    member do
      patch :update_metadata
    end
    collection do
      post :generate_token
    end
    
    resources :participants, only: [:index, :show] do
      member do
        delete :remove
        patch :mute_track
        patch :update
      end
    end
  end
  
  resources :recordings, only: [:index] do
    collection do
      get :new_egress
      post :create_egress
      get :new_ingress
      post :create_ingress
    end
    member do
      delete :stop_egress
      patch :update_layout
      delete :delete_ingress
    end
  end
  
  resources :videos do
    member do
      post :play
      post :publish
      post :start_stream
      post :stop_stream
      get :hls_player
    end
  end
  
  # VOD endpoints
  scope 'vod/:video_id', controller: :vod, as: :video do
    get :watch, as: :watch
    get :stream, as: :stream
    post :get_token, as: :token
    post :update_session, as: :update_session
    get :analytics, as: :analytics
  end
  
  # Streaming Test Suite
  resources :streaming_test, only: [:index] do
    collection do
      post :test_stream
      post :stop_test
      post :room_stats
    end
  end
  
  resources :monitoring, only: [:index] do
    collection do
      get :health
      get :metrics
      get :logs
      get :jobs
    end
  end
  
  # API endpoints for external access
  namespace :api do
    namespace :v1 do
      resources :rooms, only: [:index, :create, :destroy]
      post 'tokens/generate', to: 'tokens#generate'
      get 'server/info', to: 'server#info'
    end
  end
  
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
