class UpdateTtlForInternetQualityTables < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      ALTER TABLE internet_quality_5m
      MODIFY TTL ts + INTERVAL 35 DAY;
    SQL

    execute <<~SQL
      ALTER TABLE internet_quality_1h
      MODIFY TTL ts + INTERVAL 400 DAY;
    SQL

    execute <<~SQL
      ALTER TABLE internet_quality_1d
      MODIFY TTL ts + INTERVAL 3 YEAR;
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE internet_quality_5m
      MODIFY TTL ts + INTERVAL 30 DAY;
    SQL

    execute <<~SQL
      ALTER TABLE internet_quality_1h
      MODIFY TTL ts + INTERVAL 365 DAY;
    SQL

    execute <<~SQL
      ALTER TABLE internet_quality_1d
      MODIFY TTL ts + INTERVAL 1 YEAR;
    SQL
  end
end
