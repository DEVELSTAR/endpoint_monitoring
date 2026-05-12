class Activity < CloudControllerRecord
  include PublicActivity::Common

  self.table_name = "activities"

  belongs_to :owner, polymorphic: true, optional: true
  belongs_to :recipient, polymorphic: true, optional: true
  belongs_to :trackable, polymorphic: true, optional: true
end
