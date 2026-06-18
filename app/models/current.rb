# Per-request/per-message state. `shard` is the active database connection:
# :default is the source (DB0), :db1/:db2/:db3 are the regional replicas.
class Current < ActiveSupport::CurrentAttributes
  attribute :shard
end
