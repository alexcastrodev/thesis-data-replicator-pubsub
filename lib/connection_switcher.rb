# Simplified connection switcher (modelled on the reference app's
# ConnectionSwitcher, without the around-hooks / multi-record machinery).
#
# A single process connects to every node: :default is the source (DB0), and
# :db1/:db2/:db3 are the regional replicas (see ApplicationRecord.connects_to).
# `switch_shard(:db1) { ... }` runs the block against the db1 connection.
#
# The active shard is the gate that tells "source originating a write"
# (:default) apart from "operating on a replica" (a shard) — which is what lets
# the Replicable concern enforce the single-writer rule (published tables are
# writable only on :default; replicas receive rows via Postgres logical
# replication) without a separate "applying" flag.
module ConnectionSwitcher
  ROLE = :writing

  class << self
    def current_shard
      Current.shard || :default
    end

    # Run the block with the given shard as the active writing connection.
    def switch_shard(key)
      shard = normalize_shard(key)
      previous = Current.shard

      ApplicationRecord.connected_to(role: ROLE, shard: shard) do
        Current.shard = shard
        yield
      end
    ensure
      Current.shard = previous
    end

    private

    def normalize_shard(key)
      shard = key.to_s.strip.downcase
      return :default if shard.empty? || shard == "default"

      shard = shard.to_sym
      return shard if REPLICATION_SHARDS.include?(shard)

      raise ArgumentError, "Unknown shard: #{key.inspect}"
    end
  end
end
