# PublicActivity configuration for endpoint monitoring microservice
# Based on cloudcontroller project patterns, adapted for legacy database usage

PublicActivity.enabled = true

# Configure PublicActivity to use our custom Activity model
PublicActivity::Config.orm = :active_record

# Override PublicActivity's activity class to use our Activity model
# This ensures activities are created using the legacy database connection
Rails.application.config.after_initialize do
  PublicActivity.const_set('Activity', Activity)
end
