# app/services/concerns/clickhouse_client.rb
# Module for Clickhouse client connection
module ClickhouseClient
  extend ActiveSupport::Concern

  def client
    @client ||= Clickhouse::Base.connection
  end
end
