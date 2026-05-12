class User < CloudControllerRecord
  has_many :endpoint_monitoring_groups,
           foreign_key: "user_id"
  belongs_to :role

  def has_role?(name)
    role&.name == name.to_s
  end
end
