namespace :test do
  desc 'Setup legacy test database schema'
  task setup_legacy_db: :environment do
    # Database configuration
    config = Rails.configuration.database_configuration['test']['legacy']
    
    # Create database if it doesn't exist
    ActiveRecord::Base.establish_connection(
      config.merge('database' => nil)
    )
    
    begin
      ActiveRecord::Base.connection.create_database(config['database'])
      puts "Created database '#{config['database']}'"
    rescue ActiveRecord::StatementInvalid => e
      puts "Database '#{config['database']}' already exists"
    end
    
    # Connect to the test database
    ActiveRecord::Base.establish_connection(config)
    
    # Load and execute the schema SQL
    schema_sql = File.read(Rails.root.join('legacy_test_schema.sql'))
    
    # Split and execute each statement separately
    schema_sql.split(';').each do |statement|
      statement.strip!
      next if statement.empty?
      begin
        ActiveRecord::Base.connection.execute(statement)
      rescue ActiveRecord::StatementInvalid => e
        puts "Warning: #{e.message}" unless e.message.include?("Table") && e.message.include?("doesn't exist")
      end
    end
    
    puts "Legacy test database schema loaded successfully!"
  end
  
  # Hook into the existing test:prepare task
  task prepare: :setup_legacy_db
end
