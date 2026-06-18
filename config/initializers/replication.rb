# The replica shards that subscribe to the source's publication (the regional
# replicas). The source is the :default connection (DB0); these are the replica
# connections (see ApplicationRecord.connects_to). Each one runs a Postgres
# CREATE SUBSCRIPTION against DB0's publication — see lib/tasks/replication.rake.
#
# Defined here (not in an autoloaded concern) so the replication rake task and
# the Replicable concern can both reference it without an autoload-ordering
# dependency.
REPLICATION_SHARDS = %i[db1 db2 db3].freeze

# Name of the PostgreSQL publication on the source and of the subscription each
# replica creates against it. Kept here so the rake task and any tooling agree.
REPLICATION_PUBLICATION = "app_pub"

# The tables copied to every replica. These go into CREATE PUBLICATION app_pub
# FOR TABLE ...; everything else (e.g. the tenant-owned `entries`) stays local.
REPLICATION_TABLES = %w[tenants manufacturers].freeze
