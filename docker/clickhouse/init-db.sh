#!/bin/bash
set -e

clickhouse-client --multiquery <<'SQL'
CREATE DATABASE IF NOT EXISTS default;
CREATE DATABASE IF NOT EXISTS default_test;
SQL

