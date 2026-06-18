# Public (replicated) table that itself carries a foreign key into tenant data
# (Constraint 3 of the paper): a manufacturer belongs to a tenant.
class CreateManufacturers < ActiveRecord::Migration[8.1]
  def change
    create_table :manufacturers, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.string :country
      # tenant is itself a UUID-keyed public table.
      t.references :tenant, null: false, type: :uuid, foreign_key: true

      t.timestamps
    end
  end
end
