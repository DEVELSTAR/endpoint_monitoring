module ActivityTrackable
  extend ActiveSupport::Concern

  class_methods do
    def track_activity_for(resource_key)
      tracked owner: ->(controller, _model) { controller && controller.current_user },
              params: {
                attributes: proc { |_controller, model|
                  {
                    "#{resource_key}(#{model.id})" => model.previous_changes.with_indifferent_access
                  }
                }
              },
              organisation_id: ->(controller, _model) { controller && controller.current_user.organisation_id }

      tracked assumed_by: proc { |controller, _model|
        controller.user_assumed_by if controller
      }
    end
  end
end
