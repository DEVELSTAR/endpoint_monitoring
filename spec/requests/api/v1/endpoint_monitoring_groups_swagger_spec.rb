# spec/requests/api/v1/endpoint_monitoring_groups_swagger_spec.rb
require 'swagger_helper'

RSpec.describe 'Endpoint Monitoring Groups API', type: :request do
  path '/api/v1/endpoint_monitoring_groups' do
    get 'List all endpoint monitoring groups' do
      tags 'Endpoint Monitoring Groups'
      description 'Retrieves a paginated list of all endpoint monitoring groups for the current user'
      operationId 'listEndpointMonitoringGroups'
      produces 'application/json'

      security [ { api_key: [] } ]

      parameter name: :page, in: :query, type: :integer, required: false,
                description: 'Page number for pagination',
                default: 1

      parameter name: :per_page, in: :query, type: :integer, required: false,
                description: 'Number of groups per page',
                default: 10

      response '200', 'Successful retrieval of endpoint monitoring groups' do
        schema type: :object,
               properties: {
                 endpoint_monitoring_groups: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       name: { type: :string },
                       user_id: { type: :integer },
                       organisation_id: { type: :integer },
                       group_type: { type: :string, nullable: true },
                       associated_resources: {
                         type: :array,
                         items: {
                           type: :object,
                           properties: {
                             id: { type: :integer },
                             resourceable_type: { type: :string },
                             resourceable_id: { type: :integer },
                             endpoint_monitoring_group_id: { type: :integer },
                             name: { type: :string, nullable: true }
                           }
                         }
                       },
                       endpoint_monitoring_endpoints: {
                         type: :array,
                         items: {
                           type: :object,
                           properties: {
                             id: { type: :integer },
                             name: { type: :string },
                             host: { type: :string },
                             monitoring_mode: { type: :string, enum: [ 'icmp', 'tcp', 'http' ] },
                             port: { type: :integer, nullable: true },
                             latency_critical: { type: :integer, nullable: true },
                             latency_warning: { type: :integer, nullable: true },
                             response_time: { type: :integer, nullable: true },
                             acceptable_response_codes: { type: :array, items: { type: :integer }, nullable: true }
                           }
                         }
                       }
                     }
                   }
                 },
                 meta: {
                   type: :object,
                   properties: {
                     current_page: { type: :integer },
                     next_page: { type: :integer, nullable: true },
                     prev_page: { type: :integer, nullable: true },
                     total_pages: { type: :integer },
                     total_count: { type: :integer }
                   }
                 }
               }

        examples 'application/json' => {
          complete_response: {
            value: {
              endpoint_monitoring_groups: [
                {
                  id: 2,
                  name: 'Entertainment',
                  user_id: 6,
                  organisation_id: 5,
                  group_type: 'network',
                  associated_resources: [
                    {
                      id: 4,
                      resourceable_type: 'RouterInventory',
                      resourceable_id: 1,
                      endpoint_monitoring_group_id: 2,
                      name: '00:25:22:2E:D2:41'
                    },
                    {
                      id: 5,
                      resourceable_type: 'LocationNetwork',
                      resourceable_id: 9,
                      endpoint_monitoring_group_id: 2,
                      name: 'PavanTest'
                    },
                    {
                      id: 6,
                      resourceable_type: 'ActsAsTaggableOn::Tag',
                      resourceable_id: 1,
                      endpoint_monitoring_group_id: 2,
                      name: 'BLR'
                    }
                  ],
                  endpoint_monitoring_endpoints: [
                    {
                      id: 6,
                      name: 'Google',
                      host: 'google.com',
                      monitoring_mode: 'icmp',
                      latency_critical: 250,
                      latency_warning: 80
                    },
                    {
                      id: 7,
                      name: 'StackOverflow',
                      host: 'http://stackoverflow.com',
                      monitoring_mode: 'http',
                      response_time: 250,
                      acceptable_response_codes: [ 200, 204 ]
                    },
                    {
                      id: 8,
                      name: 'Redis',
                      host: 'redis.example.net',
                      monitoring_mode: 'tcp',
                      port: 6379
                    }
                  ]
                }
              ],
              meta: {
                current_page: 1,
                next_page: nil,
                prev_page: nil,
                total_pages: 1,
                total_count: 1
              }
            }
          }
        }

        let(:'X-AUTH-TOKEN') { '797750767469' }

        before do
          # Mock authentication
          user = create(:admin_user,
            id: 123,
            organisation_id: 456
          )

          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)

          # Mock groups with associations
          mock_group = double('EndpointMonitoringGroup',
            id: 1,
            name: 'Production Servers',
            user_id: 123,
            organisation_id: 456,
            group_type: 'infrastructure',
            endpoint_monitoring_endpoints: [],
            ep_config_mappings: []
          )

          mock_groups = [ mock_group ]

          # Create a paginated collection that responds to both array and pagination methods
          paginated_groups = double('PaginatedRelation')
          allow(paginated_groups).to receive(:to_a).and_return(mock_groups)
          allow(paginated_groups).to receive(:each).and_yield(mock_group)
          allow(paginated_groups).to receive(:flat_map).and_yield(mock_group).and_return([])
          allow(paginated_groups).to receive(:current_page).and_return(1)
          allow(paginated_groups).to receive(:next_page).and_return(nil)
          allow(paginated_groups).to receive(:prev_page).and_return(nil)
          allow(paginated_groups).to receive(:total_pages).and_return(1)
          allow(paginated_groups).to receive(:total_count).and_return(1)
          allow(paginated_groups).to receive(:any?).and_return(true)

          allow(user.endpoint_monitoring_groups).to receive(:includes).and_return(
            double('Relation',
              order: double('Relation',
                page: double('Relation',
                  per: paginated_groups
                )
              )
            )
          )
        end

        run_test!
      end

      response '401', 'Unauthorized - Invalid or missing authentication token' do
        let(:'X-AUTH-TOKEN') { 'invalid_token' }

        before do
          allow(User).to receive(:find_by).with(access_token: 'invalid_token').and_return(nil)
        end

        run_test! do |response|
          expect(response.status).to eq(401)
        end
      end
    end

    post 'Create a new endpoint monitoring group' do
      tags 'Endpoint Monitoring Groups'
      description 'Creates a new endpoint monitoring group with endpoints and associated resources'
      operationId 'createEndpointMonitoringGroup'
      consumes 'application/json'
      produces 'application/json'

      security [ { api_key: [] } ]

      parameter name: :endpoint_monitoring_group, in: :body, schema: {
        type: :object,
        required: [ 'endpoint_monitoring_group' ],
        properties: {
          endpoint_monitoring_group: {
            type: :object,
            required: [ 'name' ],
            properties: {
              name: { type: :string },
              group_type: { type: :string },
              associated_resources: {
                type: :array,
                items: { type: :string },
                description: 'Format: "AP:{id}" for RouterInventory, "network:{id}" for LocationNetwork, "tag:{id}" for Tags'
              },
              endpoint_monitoring_endpoints_attributes: {
                type: :array,
                items: {
                  type: :object,
                  required: [ 'name', 'host', 'monitoring_mode' ],
                  properties: {
                    name: { type: :string },
                    host: { type: :string, description: 'Domain/IP for ICMP/TCP, full URL for HTTP' },
                    monitoring_mode: { type: :string, enum: [ 'icmp', 'tcp', 'http' ] },
                    port: { type: :integer, description: 'Required for TCP mode' },
                    latency_critical: { type: :integer, description: 'ICMP mode - critical threshold in ms' },
                    latency_warning: { type: :integer, description: 'ICMP mode - warning threshold in ms' },
                    response_time: { type: :integer, description: 'HTTP mode - max response time in ms' },
                    acceptable_response_codes: { type: :array, items: { type: :integer }, description: 'HTTP mode - acceptable status codes' }
                  }
                }
              }
            }
          }
        },
        example: {
          endpoint_monitoring_group: {
            name: 'Entertainment',
            group_type: 'network',
            associated_resources: [ 'AP:1', 'network:9', 'tag:1' ],
            endpoint_monitoring_endpoints_attributes: [
              {
                name: 'Google',
                host: 'google.com',
                monitoring_mode: 'icmp',
                latency_warning: 80,
                latency_critical: 250
              },
              {
                name: 'StackOverflow',
                host: 'http://stackoverflow.com',
                monitoring_mode: 'http',
                response_time: 250,
                acceptable_response_codes: [ 200, 204 ]
              },
              {
                name: 'Redis',
                host: 'redis.example.net',
                monitoring_mode: 'tcp',
                port: 6379
              }
            ]
          }
        }
      }

      response '201', 'Endpoint monitoring group created successfully' do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Endpoint monitoring group created successfully' }
               }

        examples 'application/json' => {
          success_response: {
            value: {
              message: 'Endpoint monitoring group created successfully'
            }
          }
        }

        let(:'X-AUTH-TOKEN') { '797750767469' }
        let(:endpoint_monitoring_group) do
          {
            endpoint_monitoring_group: {
              name: 'Test Group',
              group_type: 'infrastructure',
              associated_resources: [ 'AP:1' ],
              endpoint_monitoring_endpoints_attributes: [
                {
                  name: 'Google DNS',
                  host: '8.8.8.8',
                  monitoring_mode: 'icmp',
                  latency_critical: 200,
                  latency_warning: 100
                }
              ]
            }
          }
        end

        before do
          router = create(:router_inventory, id: 1)
          user = create(:admin_user,
            id: 123,
            organisation_id: 456
          )

          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)

          mock_group = double('EndpointMonitoringGroup',
            id: 1,
            name: 'Test Group',
            user_id: 123,
            organisation_id: 456,
            group_type: 'infrastructure',
            save: true,
            reload: true,
            associated_resources: [ 'AP:1' ],
            endpoint_monitoring_endpoints: [],
            ep_config_mappings: []
          )

          allow(mock_group).to receive(:organisation_id=)

          allow(user.endpoint_monitoring_groups).to receive(:new).and_return(mock_group)
          allow(user.endpoint_monitoring_groups).to receive(:includes).and_return(
            double('Relation', find: mock_group)
          )
        end

        run_test!
      end

      response '422', 'Unprocessable Content - Validation errors' do
        schema type: :object,
               properties: {
                 errors: { type: :array, items: { type: :string } }
               }

        let(:'X-AUTH-TOKEN') { '797750767469' }
        let(:endpoint_monitoring_group) do
          {
            endpoint_monitoring_group: {
              name: '',
              endpoint_monitoring_endpoints_attributes: []
            }
          }
        end

        before do
          user = create(:admin_user,
            id: 123,
            organisation_id: 456
          )

          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)

          mock_group = double('EndpointMonitoringGroup',
            save: false,
            errors: double('Errors', full_messages: [ "Name can't be blank" ])
          )

          allow(mock_group).to receive(:organisation_id=)

          allow(user.endpoint_monitoring_groups).to receive(:new).and_return(mock_group)
        end

        run_test!
      end
    end
  end

  path '/api/v1/endpoint_monitoring_groups/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'ID of the endpoint monitoring group'

    get 'Get a specific endpoint monitoring group' do
      tags 'Endpoint Monitoring Groups'
      description 'Retrieves detailed information about a specific endpoint monitoring group'
      operationId 'getEndpointMonitoringGroup'
      produces 'application/json'

      security [ { api_key: [] } ]

      response '200', 'Successful retrieval' do
        schema type: :object,
               properties: {
                 endpoint_monitoring_group: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     name: { type: :string },
                     user_id: { type: :integer },
                     organisation_id: { type: :integer },
                     group_type: { type: :string, nullable: true },
                     associated_resources: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           id: { type: :integer },
                           resourceable_type: { type: :string },
                           resourceable_id: { type: :integer },
                           endpoint_monitoring_group_id: { type: :integer },
                           name: { type: :string, nullable: true }
                         }
                       }
                     },
                     endpoint_monitoring_endpoints: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           id: { type: :integer },
                           name: { type: :string },
                           host: { type: :string },
                           monitoring_mode: { type: :string, enum: [ 'icmp', 'tcp', 'http' ] },
                           port: { type: :integer, nullable: true },
                           latency_critical: { type: :integer, nullable: true },
                           latency_warning: { type: :integer, nullable: true },
                           response_time: { type: :integer, nullable: true },
                           acceptable_response_codes: { type: :array, items: { type: :integer }, nullable: true }
                         }
                       }
                     }
                   }
                 }
               }

        examples 'application/json' => {
          complete_response: {
            value: {
              endpoint_monitoring_group: {
                id: 2,
                name: 'Entertainment',
                user_id: 6,
                organisation_id: 5,
                group_type: 'network',
                associated_resources: [
                  {
                    id: 4,
                    resourceable_type: 'RouterInventory',
                    resourceable_id: 1,
                    endpoint_monitoring_group_id: 2,
                    name: '00:25:22:2E:D2:41'
                  },
                  {
                    id: 5,
                    resourceable_type: 'LocationNetwork',
                    resourceable_id: 9,
                    endpoint_monitoring_group_id: 2,
                    name: 'PavanTest'
                  },
                  {
                    id: 6,
                    resourceable_type: 'ActsAsTaggableOn::Tag',
                    resourceable_id: 1,
                    endpoint_monitoring_group_id: 2,
                    name: 'BLR'
                  }
                ],
                endpoint_monitoring_endpoints: [
                  {
                    id: 6,
                    name: 'Google',
                    host: 'google.com',
                    monitoring_mode: 'icmp',
                    latency_critical: 250,
                    latency_warning: 80
                  },
                  {
                    id: 7,
                    name: 'StackOverflow',
                    host: 'http://stackoverflow.com',
                    monitoring_mode: 'http',
                    response_time: 250,
                    acceptable_response_codes: [ 200, 204 ]
                  },
                  {
                    id: 8,
                    name: 'Redis',
                    host: 'redis.example.net',
                    monitoring_mode: 'tcp',
                    port: 6379
                  }
                ]
              }
            }
          }
        }

        let(:'X-AUTH-TOKEN') { '797750767469' }
        let(:id) { 1 }

        before do
          user = create(:admin_user,
            id: 123,
            organisation_id: 456
          )

          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)

          mock_group = double('EndpointMonitoringGroup',
            id: 1,
            name: 'Production Servers',
            user_id: 123,
            organisation_id: 456,
            group_type: 'infrastructure',
            endpoint_monitoring_endpoints: [],
            ep_config_mappings: []
          )

          allow(user.endpoint_monitoring_groups).to receive(:includes).and_return(
            double('Relation', find: mock_group)
          )
        end

        run_test!
      end

      response '404', 'Endpoint monitoring group not found' do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Endpoint Monitoring Group not found' }
               }

        let(:'X-AUTH-TOKEN') { '797750767469' }
        let(:id) { 999 }

        before do
          user = create(:admin_user,
            id: 123,
            organisation_id: 456
          )

          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)

          allow(user.endpoint_monitoring_groups).to receive(:includes).and_return(
            double('Relation').tap { |r| allow(r).to receive(:find).and_raise(ActiveRecord::RecordNotFound) }
          )
        end

        run_test! do |response|
          expect(response.status).to eq(404)
        end
      end
    end

    patch 'Update an endpoint monitoring group' do
      tags 'Endpoint Monitoring Groups'
      description 'Updates an existing endpoint monitoring group and its endpoints'
      operationId 'updateEndpointMonitoringGroup'
      consumes 'application/json'
      produces 'application/json'

      security [ { api_key: [] } ]

      parameter name: :endpoint_monitoring_group, in: :body, schema: {
        type: :object,
        required: [ 'endpoint_monitoring_group' ],
        properties: {
          endpoint_monitoring_group: {
            type: :object,
            properties: {
              name: { type: :string },
              group_type: { type: :string },
              associated_resources: {
                type: :array,
                items: { type: :string },
                description: 'Format: "AP:{id}" for RouterInventory, "network:{id}" for LocationNetwork, "tag:{id}" for Tags'
              },
              endpoint_monitoring_endpoints_attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer, description: 'For updating existing endpoint' },
                    name: { type: :string },
                    host: { type: :string, description: 'Domain/IP for ICMP/TCP, full URL for HTTP' },
                    monitoring_mode: { type: :string, enum: [ 'icmp', 'tcp', 'http' ] },
                    port: { type: :integer, description: 'Required for TCP mode' },
                    latency_critical: { type: :integer, description: 'ICMP mode - critical threshold in ms' },
                    latency_warning: { type: :integer, description: 'ICMP mode - warning threshold in ms' },
                    response_time: { type: :integer, description: 'HTTP mode - max response time in ms' },
                    acceptable_response_codes: { type: :array, items: { type: :integer }, description: 'HTTP mode - acceptable status codes' },
                    _destroy: { type: :boolean, description: 'Set to true to delete this endpoint' }
                  }
                }
              }
            }
          }
        },
        example: {
          endpoint_monitoring_group: {
            associated_resources: [ 'AP:1', 'network:9', 'tag:1' ],
            endpoint_monitoring_endpoints_attributes: [
              {
                id: 6,
                name: 'GoogleDns'
              }
            ]
          }
        }
      }

      response '200', 'Endpoint monitoring group updated successfully' do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Endpoint monitoring group updated successfully' }
               }

        examples 'application/json' => {
          success_response: {
            value: {
              message: 'Endpoint monitoring group updated successfully'
            }
          }
        }

        let(:'X-AUTH-TOKEN') { '797750767469' }
        let(:id) { 1 }
        let(:endpoint_monitoring_group) do
          {
            endpoint_monitoring_group: {
              name: 'Updated Group Name',
              associated_resources: [ 'AP:1' ]
            }
          }
        end

        before do
          router = create(:router_inventory, id: 1)
          user = create(:admin_user,
            id: 123,
            organisation_id: 456
          )

          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)

          mock_group = double('EndpointMonitoringGroup',
            id: 1,
            name: 'Updated Group Name',
            user_id: 123,
            organisation_id: 456,
            group_type: 'infrastructure',
            update: true,
            reload: true,
            associated_resources: [ 'AP:1' ],
            endpoint_monitoring_endpoints: [],
            ep_config_mappings: []
          )

          allow(user.endpoint_monitoring_groups).to receive(:includes).and_return(
            double('Relation', find: mock_group)
          )
        end

        run_test!
      end

      response '404', 'Endpoint monitoring group not found' do
        schema type: :object,
               properties: {
                 message: { type: :string }
               }

        let(:'X-AUTH-TOKEN') { '797750767469' }
        let(:id) { 999 }
        let(:endpoint_monitoring_group) do
          {
            endpoint_monitoring_group: {
              name: 'Updated Name'
            }
          }
        end

        before do
          user = create(:admin_user,
            id: 123,
            organisation_id: 456
          )

          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)

          allow(user.endpoint_monitoring_groups).to receive(:includes).and_return(
            double('Relation').tap { |r| allow(r).to receive(:find).and_raise(ActiveRecord::RecordNotFound) }
          )
        end

        run_test! do |response|
          expect(response.status).to eq(404)
        end
      end

      response '422', 'Unprocessable Content - Validation errors' do
        schema type: :object,
               properties: {
                 errors: { type: :array, items: { type: :string } }
               }

        let(:'X-AUTH-TOKEN') { '797750767469' }
        let(:id) { 1 }
        let(:endpoint_monitoring_group) do
          {
            endpoint_monitoring_group: {
              name: ''
            }
          }
        end

        before do
          user = create(:admin_user,
            id: 123,
            organisation_id: 456
          )

          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)

          mock_group = double('EndpointMonitoringGroup',
            update: false,
            errors: double('Errors', full_messages: [ "Name can't be blank" ]),
            ep_config_mappings: []
          )

          allow(user.endpoint_monitoring_groups).to receive(:includes).and_return(
            double('Relation', find: mock_group)
          )
        end

        run_test!
      end
    end

    delete 'Delete an endpoint monitoring group' do
      tags 'Endpoint Monitoring Groups'
      description 'Permanently deletes an endpoint monitoring group and all its endpoints'
      operationId 'deleteEndpointMonitoringGroup'
      produces 'application/json'

      security [ { api_key: [] } ]

      response '200', 'Endpoint monitoring group deleted successfully' do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Endpoint monitoring group deleted successfully' }
               }

        let(:'X-AUTH-TOKEN') { '797750767469' }
        let(:id) { 1 }

        before do
          user = create(:admin_user,
            id: 123,
            organisation_id: 456
          )

          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)

          mock_group = double('EndpointMonitoringGroup',
            destroy: true,
            ep_config_mappings: []
          )

          allow(user.endpoint_monitoring_groups).to receive(:includes).and_return(
            double('Relation', find: mock_group)
          )
        end

        run_test!
      end

      response '404', 'Endpoint monitoring group not found' do
        schema type: :object,
               properties: {
                 message: { type: :string }
               }

        let(:'X-AUTH-TOKEN') { '797750767469' }
        let(:id) { 999 }

        before do
          user = create(:admin_user,
            id: 123,
            organisation_id: 456
          )

          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)

          allow(user.endpoint_monitoring_groups).to receive(:includes).and_return(
            double('Relation').tap { |r| allow(r).to receive(:find).and_raise(ActiveRecord::RecordNotFound) }
          )
        end

        run_test! do |response|
          expect(response.status).to eq(404)
        end
      end
    end
  end

  path '/api/v1/endpoint_monitoring_groups/set_ep_config' do
    post 'Reset endpoint monitoring redis data' do
      tags 'Endpoint Monitoring Groups'
      description 'Resets the application configuration in Redis and optionally syncs with Cloud Controller'
      operationId 'resetEpgRedis'
      produces 'application/json'

      security [ { api_key: [] } ]

      parameter name: :access_token, in: :query, type: :string, required: false,
                description: 'Alternative way to provide authentication token'

      response '200', 'Redis data reset successfully' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     endpoint_monitoring_groups: { type: :object, properties: { status: { type: :string } } },
                     ep_config_mappings: { type: :object, properties: { status: { type: :string } } },
                     cloud_controller_sync: { type: :object, properties: { status: { type: :string } } }
                   }
                 },
                 errors: { type: :array, items: { type: :string } }
               }

        let(:'X-AUTH-TOKEN') { '797750767469' }

        before do
          user = create(:admin_user)
          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)

          mock_result = {
            success: true,
            results: {
              endpoint_monitoring_groups: { status: "success" },
              ep_config_mappings: { status: "success" },
              cloud_controller_sync: { status: "success" }
            },
            errors: []
          }

          allow_any_instance_of(CloudController::RedisResetService).to receive(:call).and_return(mock_result)
        end

        run_test!
      end

      response '500', 'Internal Server Error - Reset failed' do
        schema type: :object,
               properties: {
                 data: { type: :object },
                 errors: { type: :array, items: { type: :string } }
               }

        let(:'X-AUTH-TOKEN') { '797750767469' }

        before do
          user = create(:admin_user)
          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)

          mock_result = {
            success: false,
            results: {
              endpoint_monitoring_groups: { status: "failed" }
            },
            errors: [ "Redis connection error" ]
          }

          allow_any_instance_of(CloudController::RedisResetService).to receive(:call).and_return(mock_result)
        end
      end
    end
  end

  path '/api/v1/endpoint_monitoring_groups/set_ep_thresholds' do
    post 'Sync endpoint thresholds to Redis' do
      tags 'Endpoint Monitoring Groups'
      description 'Bulk syncs all endpoint latency thresholds to Redis for fast access'
      operationId 'syncEpThresholds'
      produces 'application/json'

      security [ { api_key: [] } ]

      response '200', 'Thresholds synced successfully' do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Thresholds synced to Redis successfully' }
               }

        let(:'X-AUTH-TOKEN') { '797750767469' }

        before do
          user = create(:admin_user)
          allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)

          # Use doubles for performance if needed, or just let it run if lightweight
          allow(EndpointMonitoringEndpoint).to receive(:find_each).and_yield(
            double('Endpoint', id: 1, monitoring_mode: 'icmp', latency_warning: 100, latency_critical: 200)
          )
          allow($redis).to receive(:hset).and_return(true)
        end

        run_test!
      end
    end
  end
end
