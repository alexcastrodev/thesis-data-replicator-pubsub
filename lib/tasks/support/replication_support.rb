# Shared helpers/constants for the replication rake tasks. The tasks are split
# across two files — replication_setup.rake (infra: setup/publish/teardown) and
# replication.rake (flow: replicate/verify/demo) — and both `extend` this module
# so the helpers live in one place instead of leaking onto Object as top-level
# `def`s.
module ReplicationSupport
  # The connection info each *subscriber* uses to reach the *publisher* (db0).
  # IMPORTANT: this string is resolved inside the replica's Postgres process, so
  # the host must be reachable from there. Inside docker-compose that is the
  # service name `db0` on the internal port 5432 (the default below). Override
  # via PUBLISHER_HOST / PUBLISHER_PORT when running elsewhere.
  PUBLISHER_HOST     = ENV.fetch("PUBLISHER_HOST", "db0")
  PUBLISHER_PORT     = ENV.fetch("PUBLISHER_PORT", "5432")
  PUBLISHER_USER     = ENV.fetch("POSTGRES_USER", "postgres")
  PUBLISHER_PASSWORD = ENV.fetch("POSTGRES_PASSWORD", "dev")

  module_function

  # Name of the subscription a replica creates against db0's publication.
  def subscription_name(shard)
    "app_sub_#{shard}"
  end

  # The conninfo string baked into CREATE SUBSCRIPTION (resolved on the replica).
  def publisher_conninfo(publisher_db)
    "host=#{PUBLISHER_HOST} port=#{PUBLISHER_PORT} dbname=#{publisher_db} " \
      "user=#{PUBLISHER_USER} password=#{PUBLISHER_PASSWORD}"
  end

  # Run a block against the source (:default / db0) connection.
  def on_source
    ConnectionSwitcher.switch_shard(:default) { yield ApplicationRecord.connection }
  end

  def say(message)
    puts message
  end

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
