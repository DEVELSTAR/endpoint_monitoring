# frozen_string_literal: true
# /Users/akibu/Desktop/endpoint_monitoring/lib/tasks/clickhouse.rake
namespace :db do
  namespace :migrate do
    namespace :clickhouse do
      def with_clickhouse
        ActiveRecord::Base.establish_connection(:clickhouse)
        yield
      end

      def migration_context
        cfg = Rails.configuration.database_configuration[Rails.env]["clickhouse"]
        ActiveRecord::MigrationContext.new(
          cfg["migrations_paths"],
          ActiveRecord::Base.connection.schema_migration
        )
      end

      desc "Run all ClickHouse migrations"
      task up: :environment do
        with_clickhouse do
          migration_context.migrate
          puts "ClickHouse migrations completed"
        end
      end

      desc "Drop all ClickHouse migrations"
      task down: :environment do
        with_clickhouse do
          migration_context.migrate(0)
          puts "All ClickHouse migrations rolled back"
        end
      end

      desc "Show ClickHouse migration status"
      task status: :environment do
        with_clickhouse do
          ctx = migration_context
          migrated = ctx.schema_migration.versions.map(&:to_i) rescue []

          puts "\nClickHouse Migration Status"
          puts "-" * 60
          ctx.migrations.each do |m|
            puts "#{migrated.include?(m.version) ? 'up' : 'down'}  #{m.version}  #{m.name}"
          end
        end
      end

      desc "Rollback one ClickHouse migration (or to VERSION=x)"
      task :rollback, [ :version ] => :environment do |_t, args|
        with_clickhouse do
          args[:version] ? migration_context.migrate(args[:version].to_i)
                         : migration_context.rollback
        end
      end

      desc "Reset ClickHouse DB"
      task reset: :environment do
        with_clickhouse do
          tables = ActiveRecord::Base.connection
                    .execute("SHOW TABLES")
                    .map { |row| row[0] }

          tables.each do |table|
            ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{table}")
          end
        end

        Rake::Task["db:migrate:clickhouse:up"].reenable
        Rake::Task["db:migrate:clickhouse:up"].invoke
      end
    end
  end
end
