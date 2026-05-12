-- ClickHouse test data for location_endpoints API
-- Run with: clickhouse-client -d your_database < db/seeds/clickhouse_location_endpoint_test_data.sql

-- Clear existing test data
DELETE FROM router_metrics_raw WHERE org_id = '3';

-- Good endpoints (low latency, no failures)
INSERT INTO router_metrics_raw (org_id, endpoint_id, region, host, device_id, latency_ms, http_status, tcp_status, ts)
VALUES 
  ('3', '1', 'Delhi', 'http://google.com', 'dev_001', 45, 200, '1', now()),
  ('3', '1', 'Delhi', 'http://google.com', 'dev_002', 52, 200, '1', now()),
  ('3', '2', 'Delhi', 'http://cloudflare.com', 'dev_003', 38, 200, '1', now()),
  
  ('3', '3', 'Mumbai', 'http://aws.amazon.com', 'dev_004', 48, 200, '1', now()),
  ('3', '4', 'Mumbai', 'http://azure.microsoft.com', 'dev_005', 150, 200, '1', now()),
  ('3', '5', 'Mumbai', 'http://bad-endpoint.com', 'dev_006', 250, 200, '1', now());

-- Critical endpoints (medium latency OR 20-60% failures)
INSERT INTO router_metrics_raw (org_id, endpoint_id, region, host, device_id, latency_ms, http_status, tcp_status, ts)
VALUES 
  ('3', '6', 'Delhi', 'http://unstable-api.com', 'dev_007', 80, 500, '1', now()),
  ('3', '6', 'Delhi', 'http://unstable-api.com', 'dev_007', 85, 200, '1', now()),
  ('3', '6', 'Delhi', 'http://unstable-api.com', 'dev_007', 82, 503, '1', now()),
  
  ('3', '7', 'Bangalore', 'http://slow-service.io', 'dev_008', 120, 200, '1', now()),
  ('3', '8', 'Bangalore', 'http://medium-latency.com', 'dev_009', 145, 200, '1', now());

-- Down endpoints (>60% failures OR very high latency)
INSERT INTO router_metrics_raw (org_id, endpoint_id, region, host, device_id, latency_ms, http_status, tcp_status, ts)
VALUES 
  ('3', '9', 'Mumbai', 'http://broken-api.com', 'dev_010', 50, 500, '1', now()),
  ('3', '9', 'Mumbai', 'http://broken-api.com', 'dev_010', 55, 503, '1', now()),
  ('3', '9', 'Mumbai', 'http://broken-api.com', 'dev_010', 52, 502, '1', now()),
  ('3', '9', 'Mumbai', 'http://broken-api.com', 'dev_010', 48, 500, '1', now()),
  ('3', '9', 'Mumbai', 'http://broken-api.com', 'dev_010', 51, 200, '1', now()),
  
  ('3', '10', 'Delhi', 'tcp-failing.net', 'dev_011', 0, 0, '2', now()),
  ('3', '10', 'Delhi', 'tcp-failing.net', 'dev_012', 0, 0, '2', now()),
  ('3', '10', 'Delhi', 'tcp-failing.net', 'dev_013', 0, 0, '2', now()),
  
  ('3', '11', 'Bangalore', 'http://timeout-service.com', 'dev_014', 300, 200, '1', now()),
  ('3', '11', 'Bangalore', 'http://timeout-service.com', 'dev_014', 300, 200, '1', now());
