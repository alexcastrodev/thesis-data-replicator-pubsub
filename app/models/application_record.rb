class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # One process connects to the source (default = DB0) and to every replica, so
  # tooling (e.g. the replication rake task) can read a replica directly via
  # ConnectionSwitcher.switch_shard(<shard>) to verify convergence. The shard
  # names match the connections declared in config/database.yml. Replicas are
  # written ONLY by PostgreSQL logical replication, never by this process.
  connects_to shards: {
    default: { writing: :primary },
    db1: { writing: :db1 },
    db2: { writing: :db2 },
    db3: { writing: :db3 }
  }
end
