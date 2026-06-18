# Infra tasks for the native PostgreSQL logical-replication demo: provisioning
# the databases and wiring up the publication/subscriptions. The replication
# *flow* (seed + verify + demo) lives in replication.rake; this file is the part
# you usually don't need to touch.
#
#   db0 (source / publisher)  CREATE PUBLICATION app_pub FOR TABLE tenants, manufacturers;
#   db1/db2/db3 (subscribers) CREATE SUBSCRIPTION app_sub_<shard>
#                               CONNECTION 'host=db0 port=5432 dbname=... user=... password=...'
#                               PUBLICATION app_pub;
require_relative "support/replication_support"

namespace :replication do
  extend ReplicationSupport

  desc "Drop, recreate and migrate every node (db0..db3) so the published tables exist everywhere"
  task setup: :environment do
    # Tear down any existing replication first: an active subscription holds a
    # logical replication slot on db0, and Postgres refuses to DROP a database
    # while a slot references it (PG::ObjectInUse). Tolerant — a clean slate just
    # has nothing to drop.
    Rake::Task["replication:teardown"].invoke rescue nil

    # Release the pooled connections this process holds to each node, otherwise
    # db:drop fails with "database is being accessed by other users" — our own
    # idle session counts. The db:drop runs in a fresh subprocess below.
    ActiveRecord::Base.connection_handler.clear_all_connections!

    # The development env declares all four connections, so a single drop/create
    # acts on every node. Logical replication does NOT copy schema, so the tables
    # must already exist on each subscriber — that is exactly what migrating every
    # node here guarantees.
    system("bin/rails", "db:drop", "db:create", "db:migrate", exception: true)
  end

  desc "Create the publication on db0 and a subscription on each replica (db1..db3)"
  task publish: :environment do
    publisher_db = ApplicationRecord.connection_db_config.database

    # 1. Publisher: declare what to replicate. DROP first so the task is rerunnable.
    say "==> db0 (publisher): CREATE PUBLICATION #{REPLICATION_PUBLICATION} FOR TABLE #{REPLICATION_TABLES.join(', ')}"
    on_source do |conn|
      conn.execute("DROP PUBLICATION IF EXISTS #{REPLICATION_PUBLICATION}")
      conn.execute(
        "CREATE PUBLICATION #{REPLICATION_PUBLICATION} FOR TABLE #{REPLICATION_TABLES.join(', ')}"
      )
    end

    # 2. Each replica subscribes. CREATE SUBSCRIPTION immediately copies the
    #    current table contents, then streams subsequent changes.
    REPLICATION_SHARDS.each do |shard|
      sub_name = subscription_name(shard)
      conninfo = publisher_conninfo(publisher_db)

      say "==> #{shard} (subscriber): CREATE SUBSCRIPTION #{sub_name} -> " \
          "#{ReplicationSupport::PUBLISHER_HOST}:#{ReplicationSupport::PUBLISHER_PORT}/#{publisher_db}"
      ConnectionSwitcher.switch_shard(shard) do
        conn = ApplicationRecord.connection
        conn.execute("DROP SUBSCRIPTION IF EXISTS #{sub_name}")
        conn.execute(
          "CREATE SUBSCRIPTION #{sub_name} CONNECTION '#{conninfo}' PUBLICATION #{REPLICATION_PUBLICATION}"
        )
      end
    end
  end

  desc "Tear down the subscriptions and publication (does not drop databases)"
  task teardown: :environment do
    REPLICATION_SHARDS.each do |shard|
      sub_name = subscription_name(shard)
      ConnectionSwitcher.switch_shard(shard) do
        conn = ApplicationRecord.connection
        # Detach the remote slot before dropping: a plain DROP SUBSCRIPTION tries
        # to drop the slot on db0 and would hang/error if db0 is unreachable. We
        # disable, detach the slot reference, then drop locally; the publisher's
        # slot is cleared separately below.
        conn.execute("ALTER SUBSCRIPTION #{sub_name} DISABLE")
        conn.execute("ALTER SUBSCRIPTION #{sub_name} SET (slot_name = NONE)")
        conn.execute("DROP SUBSCRIPTION IF EXISTS #{sub_name}")
        say "==> #{shard}: dropped subscription #{sub_name}"
      end
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished => e
      # No such subscription / database not there yet -> nothing to tear down.
      say "==> #{shard}: nothing to tear down (#{e.class})"
    end

    begin
      on_source do |conn|
        conn.execute("DROP PUBLICATION IF EXISTS #{REPLICATION_PUBLICATION}")
        # Drop any replication slots left behind by detached subscriptions, so the
        # database can be dropped and the slots don't accumulate WAL.
        slots = REPLICATION_SHARDS.map { |s| "'#{subscription_name(s)}'" }.join(", ")
        conn.execute(<<~SQL)
          SELECT pg_drop_replication_slot(slot_name)
          FROM pg_replication_slots
          WHERE slot_name IN (#{slots}) AND active = false
        SQL
      end
      say "==> db0: dropped publication #{REPLICATION_PUBLICATION} and any leftover slots"
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished => e
      say "==> db0: nothing to tear down (#{e.class})"
    end
  end
end
