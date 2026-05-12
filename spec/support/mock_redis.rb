# spec/support/mock_redis.rb
require 'mock_redis'

RSpec.configure do |config|
  config.before(:each) do
    $redis = MockRedis.new
  end

  config.after(:each) do
    $redis = nil
  end
end
