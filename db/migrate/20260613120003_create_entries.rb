# Tenant-owned table (NOT replicated). Read-write locally on each replica.
# It references a Manufacturer, which IS a replicated row — so on a replica an
# Entry may depend on a row that originated at DB0. This is the relationship
# that makes the "delete a referenced Manufacturer" question (paper Future Work)
# concrete.
class CreateEntries < ActiveRecord::Migration[8.1]
  def change
    # Tenant-owned rows keep a local bigint primary key — they are never
    # replicated, so a global id is unnecessary. Only the FK into the
    # UUID-keyed manufacturers table needs to be a UUID.
    create_table :entries do |t|
      t.string :description, null: false
      t.references :manufacturer, null: false, type: :uuid, foreign_key: true

      t.timestamps
    end
  end
end
