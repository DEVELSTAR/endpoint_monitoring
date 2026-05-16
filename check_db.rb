require 'socket'

def check_port(host, port)
  begin
    Socket.tcp(host, port, connect_timeout: 1) { |sock| true }
  rescue => e
    false
  end
end

puts "MySQL 8.0 (3308): #{check_port('127.0.0.1', 3308)}"
puts "MySQL 5.7 (3306): #{check_port('127.0.0.1', 3306)}"
puts "ClickHouse (8123): #{check_port('127.0.0.1', 8123)}"
puts "Kafka (9092): #{check_port('127.0.0.1', 9092)}"
puts "Redis (6379): #{check_port('127.0.0.1', 6379)}"
