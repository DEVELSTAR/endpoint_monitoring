class Ability
  include CanCan::Ability

  def initialize(user)
    # Define abilities for the passed in user here. For example:
    #
    user ||= User.new # guest user
    Dir[Rails.root.join("app/models/ability/*.rb")].each do |ability|
      ability_class = ("Ability::" + File.basename(ability, ".rb").camelize).constantize
      merge(ability_class.new(user))
    end
  end
end
