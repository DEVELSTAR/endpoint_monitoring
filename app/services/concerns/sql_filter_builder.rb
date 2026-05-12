module SqlFilterBuilder
  extend ActiveSupport::Concern

  # Field to database column mapping
  FIELD_COLUMN_MAP = {
    org_id: "org_id",
    host: "host",
    region: "region",
    isp: "isp",
    endpoint_id: "endpoint_id",
    location_id: "location_network_id",
    device_id: "device_id",
    router_id: "router_inventory_id"
  }.freeze

  # Fields that should use ILIKE for partial matching
  ILIKE_FIELDS = %i[host region isp].freeze

  def build_sql_filters(*fields)
    filters = []

    fields.each do |field|
      value = instance_variable_get("@#{field}")
      next unless value.present?

      column_name = FIELD_COLUMN_MAP[field] || field.to_s

      values_array = value.to_s.split(',').map(&:strip).reject(&:blank?)

      if ILIKE_FIELDS.include?(field)
        ilike_conditions = values_array.map do |v|
          sanitized = sanitize_sql_value(v)
          "#{column_name} ILIKE '%#{sanitized}%'"
        end
        filters << "(#{ilike_conditions.join(' OR ')})"
      else
        sanitized_values = values_array.map { |v| "'#{sanitize_sql_value(v)}'" }
        filters << "#{column_name} IN (#{sanitized_values.join(',')})"
      end
    end

    filters
  end

  private

  # Basic SQL injection protection
  def sanitize_sql_value(value)
    return "" unless value
    value.to_s.gsub("'", "''")
  end
end
