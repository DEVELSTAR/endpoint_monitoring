# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  config.openapi_root = Rails.root.join('swagger').to_s

  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Endpoint Monitoring API',
        version: 'v1',
        description: 'API documentation for Endpoint Monitoring Dashboard'
      },
      servers: [
        { url: ENV.fetch('SWAGGER_URL', 'http://localhost:3000') }
      ],
      components: {
        securitySchemes: {
          api_key: {
            type: :apiKey,
            name: 'X-AUTH-TOKEN',
            in: :header
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
