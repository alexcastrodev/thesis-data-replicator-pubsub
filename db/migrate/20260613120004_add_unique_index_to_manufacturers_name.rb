# Manufacturer name is globally unique. The DB constraint is the real guarantee
# (and is what logical replication relies on to keep replicas consistent); the
# model validation just turns a would-be PG::UniqueViolation into a friendly error.
class AddUniqueIndexToManufacturersName < ActiveRecord::Migration[8.1]
  def change
    add_index :manufacturers, :name, unique: true
  end
end
