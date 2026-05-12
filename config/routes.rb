require "sidekiq/web"

Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  mount Sidekiq::Web, at: "/sidekiq"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # Dashboard APIs (consolidated from analytics, metrics, and dashboard)
      get "dashboard/latency_analysis", to: "dashboard#latency_analysis"
      get "dashboard/endpoint_reports", to: "dashboard#endpoint_reports"
      get "dashboard/site_distribution", to: "dashboard#site_distribution"
      get "dashboard/response_efficiency", to: "dashboard#response_efficiency"
      get "dashboard/endpoint_metrics", to: "dashboard#endpoint_metrics"
      get "dashboard/grouped_timeseries", to: "dashboard#grouped_timeseries"
      get "dashboard/uplink_timeseries", to: "dashboard#uplink_timeseries"
      get "dashboard/endpoint_health_metrics", to: "dashboard#endpoint_health_metrics"
      get "dashboard/endpoint_location_status", to: "dashboard#endpoint_location_status"
      get "dashboard/location_endpoints", to: "dashboard#location_endpoints"
      get "dashboard/endpoint_locations", to: "dashboard#endpoint_locations"
      get "dashboard/endpoint_timeseries", to: "dashboard#endpoint_timeseries"

      # Filter list APIs
      get "dashboard/resource_list", to: "dashboard#resource_list"

      get "health" => "health#check"

      # CRUD APIs
      resources :endpoint_monitoring_groups do
        member do
          get :config
        end
        collection do
          get :index_stream
          post :set_ep_config
          post :set_ep_thresholds
        end
      end
    end
  end
end
