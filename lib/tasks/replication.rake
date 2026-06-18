# Replication FLOW — the part to focus on. Infra (provisioning the databases and
# wiring publication/subscriptions) lives in replication_setup.rake.
#
# Postgres does the copying: CREATE SUBSCRIPTION first copies the existing table
# contents, then streams every committed change on the published tables to the
# subscriber. No broker, no application producers/consumers — :replicate only
# writes the source (db0) and :verify watches the replicas converge.
require_relative "support/replication_support"

namespace :replication do
  extend ReplicationSupport

  desc "Full demo: set up the 4 databases, wire up replication, seed the source, and verify"
  task demo: :environment do
    Rake::Task["replication:setup"].invoke
    Rake::Task["replication:publish"].invoke
    Rake::Task["replication:replicate"].invoke
    Rake::Task["replication:verify"].invoke
  end

  desc "Seed the source (db0); PostgreSQL replicates the rows to every subscriber automatically"
  task replicate: :environment do
    # Only the source is written. The replicas converge on their own via the
    # logical-replication stream — no per-shard fan-out from the application.
    Entry.delete_all
    Manufacturer.delete_all
    Tenant.delete_all

    france = Tenant.create!(name: "France HQ", subdomain: "france")
    sensus = Manufacturer.create!(name: "Sensus", country: "FR", tenant: france)
    Manufacturer.create!(name: "Itron", country: "US", tenant: france)
    Manufacturer.create!(name: "Diehl", country: "DE", tenant: france)
    Entry.create!(description: "Meter batch #1", manufacturer: sensus)

    # Then UPDATE an existing row to show that logical replication streams updates,
    # not just the initial INSERT copy. update_columns writes straight to db0 (no
    # callbacks/validations) — on the source that is fine, and Postgres replicates
    # the UPDATE to every subscriber. We assert the new value converged in :verify.
    sensus.update_columns(country: "DE")

    say "==> source (db0): wrote #{Manufacturer.count} manufacturer(s) and updated Sensus.country -> DE; " \
        "Postgres is now streaming the inserts + update to the replicas"
  end

  desc "Poll the replicas until they converge with the source (or time out)"
  task verify: :environment do
    # Convergence = same set of ids AND the latest column values. The country map
    # (id -> country) catches the streamed UPDATE: a replica that copied the
    # initial INSERT but missed the later update_columns would match on ids but
    # not here.
    expected = Manufacturer.order(:id).pluck(:id).sort
    expected_countries = Manufacturer.order(:id).pluck(:id, :country).to_h
    deadline = monotonic + Integer(ENV.fetch("TIMEOUT", "30"))

    REPLICATION_SHARDS.each do |shard|
      loop do
        ids, countries, sensus_country = ConnectionSwitcher.switch_shard(shard) do
          [Manufacturer.order(:id).pluck(:id).sort,
           Manufacturer.order(:id).pluck(:id, :country).to_h,
           Manufacturer.where(name: "Sensus").pick(:country)]
        end

        if ids == expected && countries == expected_countries
          say "==> #{shard}: converged (#{ids.size} rows; streamed UPDATE applied -> Sensus.country=#{sensus_country})"
          break
        end

        if monotonic > deadline
          say "==> #{shard}: TIMEOUT (#{ids.size}/#{expected.size} rows; countries match=#{countries == expected_countries})"
          break
        end

        sleep 1
      end
    end
  end
end
