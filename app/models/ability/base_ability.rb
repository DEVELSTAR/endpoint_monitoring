class Ability::BaseAbility
  include CanCan::Ability

  READ_ONLY_ROLES = [
    "monitor_only",
    "network_monitor",
    "customer_care_devices_senior_experts",
    "customer_care_devices_experts",
    "customer_care_devices_specialists",
    "customer_care_general",
    "vendor_techs",
    "nw_onboarding_manager",
    "nw_onboarding_techs",
    "network_r&d",
    "organization_monitor"
  ].freeze

  def initialize(user)
    if user.has_role?(:admin) || user.is_super_admin? || user.has_role?(Role.api_role&.name)
      can :manage, :all
    elsif READ_ONLY_ROLES.include?(user.role&.name)
      can :manage, :dashboard
      can :read, EndpointMonitoringGroup, user_id: user.id
    end
  end
end
