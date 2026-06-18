# DELETE scenarios for the replication PoC — the paper's open question about
# deleting a replicated public row (Manufacturer) that tenant-owned rows (Entry)
# may reference. Kept in their own `replication:delete:*` namespace so the main
# flow (replication.rake) stays focused on demo/replicate/verify.
#
#   replication:delete:prevented   FK on the SOURCE blocks it -> 'prevent' works
#   replication:delete:clean       no FK anywhere -> DELETE replicates cleanly
#   replication:delete:replica_fk  FK only on a replica -> SILENT ORPHAN
#   replication:delete:demo        set up fresh, then run all three in order
#
# The clean / replica_fk scenarios take a target Manufacturer (ENV["MANUFACTURER"],
# default Itron) so :demo can point them at different rows and not collide.
require_relative "support/replication_support"

namespace :replication do
  namespace :delete do
    extend ReplicationSupport

    desc "Full delete demo: fresh setup, then prevented + clean + replica_fk in order"
    task demo: :environment do
      Rake::Task["replication:setup"].invoke
      Rake::Task["replication:publish"].invoke
      Rake::Task["replication:replicate"].invoke

      say "\n--- 1/3: prevented (FK on the source blocks the delete) ---"
      Rake::Task["replication:delete:prevented"].invoke

      # Distinct targets so the two destructive scenarios don't fight over a row:
      # clean removes Itron, replica_fk removes Diehl.
      say "\n--- 2/3: clean (no FK anywhere -> DELETE replicates) ---"
      delete_clean("Itron")

      say "\n--- 3/3: replica_fk (FK only on db1 -> silent orphan) ---"
      delete_replica_fk("Diehl")
    end

    desc "FK on the SOURCE blocks the delete (Sensus is referenced by an Entry on db0) — 'prevent' strategy"
    task prevented: :environment do
      # The paper's open question: deleting a replicated public row (Manufacturer)
      # that a tenant-owned row (Entry) still references. We adopt the *prevent*
      # strategy — the integrity guard on the SOURCE stops the delete, so it never
      # replicates and no replica is left with a dangling reference.
      #
      # Sensus is referenced by an Entry on db0 (see replication:replicate). Two
      # guards fire:
      #   1. app level: has_many :entries, dependent: :restrict_with_error -> destroy
      #      returns false with an error, before any SQL delete.
      #   2. db level:  the FK entries.manufacturer_id -> manufacturers blocks a raw
      #      DELETE with PG::ForeignKeyViolation.
      sensus = Manufacturer.find_by!(name: "Sensus")
      before = REPLICATION_SHARDS.to_h do |shard|
        [shard, ConnectionSwitcher.switch_shard(shard) { Manufacturer.exists?(sensus.id) }]
      end

      say "==> db0: attempting Manufacturer.destroy on Sensus (referenced by #{sensus.entries.count} entry/entries)"

      # 1. ActiveRecord destroy is restricted by the association.
      if sensus.destroy
        say "    UNEXPECTED: destroy succeeded — the restrict guard did not fire"
      else
        say "    app-level: destroy refused -> #{sensus.errors.full_messages.join('; ')}"
      end

      # 2. And the database FK blocks a raw delete too.
      begin
        on_source { |conn| conn.execute("DELETE FROM manufacturers WHERE id = '#{sensus.id}'") }
        say "    UNEXPECTED: raw DELETE succeeded — the FK did not block it"
      rescue ActiveRecord::InvalidForeignKey => e
        say "    db-level: raw DELETE blocked -> #{e.message.lines.first.strip}"
      end

      # The delete never happened on the source, so nothing replicated. Replicas are
      # unchanged — no dangling reference anywhere.
      still_on_source = Manufacturer.exists?(sensus.id)
      after = REPLICATION_SHARDS.to_h do |shard|
        [shard, ConnectionSwitcher.switch_shard(shard) { Manufacturer.exists?(sensus.id) }]
      end

      say "==> db0: Sensus still present? #{still_on_source}"
      REPLICATION_SHARDS.each do |shard|
        say "==> #{shard}: Sensus present? #{after[shard]} (was #{before[shard]} — unchanged: #{before[shard] == after[shard]})"
      end
    end

    desc "No FK anywhere -> the DELETE replicates and the row disappears everywhere (MANUFACTURER=Itron)"
    task clean: :environment do
      delete_clean(ENV.fetch("MANUFACTURER", "Itron"))
    end

    desc "The hard case: a FK that exists ONLY on a replica -> SILENT ORPHAN (MANUFACTURER=Itron)"
    task replica_fk: :environment do
      delete_replica_fk(ENV.fetch("MANUFACTURER", "Itron"))
    end

    # --- shared implementations (called by the tasks above and by :demo) ---

    # Destroy an UNreferenced Manufacturer on the source; the DELETE streams to
    # every replica, proving DELETE replication itself works (only the FK blocked
    # the prevented case).
    def delete_clean(name)
      mfr = Manufacturer.find_by!(name: name)
      id = mfr.id

      say "==> db0: destroying unreferenced Manufacturer #{name}"
      mfr.destroy!

      deadline = monotonic + Integer(ENV.fetch("TIMEOUT", "30"))
      REPLICATION_SHARDS.each do |shard|
        loop do
          gone = ConnectionSwitcher.switch_shard(shard) { !Manufacturer.exists?(id) }
          if gone
            say "==> #{shard}: DELETE applied — #{name} is gone"
            break
          end
          if monotonic > deadline
            say "==> #{shard}: TIMEOUT — #{name} still present"
            break
          end
          sleep 1
        end
      end
    end

    # Plant a tenant-owned Entry on db1 pointing at a replicated Manufacturer, then
    # delete that Manufacturer on the SOURCE (where nothing references it).
    #
    # KEY FINDING: the source delete succeeds and replicates. On db1 the local FK
    # entries.manufacturer_id -> manufacturers would normally block it — but the
    # logical-replication apply worker runs with session_replication_role =
    # 'replica', and in that mode PostgreSQL does NOT fire FK/trigger checks. So the
    # DELETE is applied on db1 too and the local Entry is left as a SILENT ORPHAN
    # (manufacturer_id pointing at a row that no longer exists). No distributed
    # rollback: db0/db2/db3 stay consistent, db1 is quietly corrupt.
    def delete_replica_fk(name)
      mfr = Manufacturer.find_by!(name: name)
      id = mfr.id

      # 1. Plant a local Entry on db1 referencing the manufacturer (lives only on db1).
      ConnectionSwitcher.switch_shard(:db1) do
        Entry.create!(description: "local PT entry -> #{name}", manufacturer_id: id)
      end
      say "==> db1: planted a local Entry referencing #{name} (FK exists only on db1)"

      # 2. Delete it on the source. No Entry references it there, so it succeeds.
      say "==> db0: destroying #{name} on the source (nothing references it here)"
      mfr.destroy!

      # 3. Wait for the DELETE to reach db1, then inspect the damage.
      deadline = monotonic + Integer(ENV.fetch("TIMEOUT", "30"))
      loop do
        gone = ConnectionSwitcher.switch_shard(:db1) { !Manufacturer.exists?(id) }
        break if gone || monotonic > deadline

        sleep 1
      end

      REPLICATION_SHARDS.each do |shard|
        mfr_present, orphans = ConnectionSwitcher.switch_shard(shard) do
          [Manufacturer.exists?(id), Entry.where(manufacturer_id: id).count]
        end
        label = orphans.positive? ? "SILENT ORPHAN" : "consistent"
        say "==> #{shard}: #{name} present? #{mfr_present} | dangling entries -> #{name}: #{orphans}  (#{label})"
      end

      say "==> note: db1's FK did not block the apply (worker runs as session_replication_role = replica); " \
          "no distributed rollback — db0/db2/db3 stayed consistent, db1 is left with a dangling reference"
    end
  end
end
