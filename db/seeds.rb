# Seed data for the replication PoC.
#
# Run on DB0 (the source of truth): `NODE=db0 bin/rails db:seed`.
# Creating these public rows on DB0 with replication enabled publishes them to
# every shard; or seed each replica directly with `Replicable.applying { ... }`
# to avoid re-emitting.
#
# Idempotent: keyed on subdomain / name.

france = Tenant.find_or_create_by!(subdomain: "france") { |t| t.name = "France HQ" }

manufacturers = [
  { name: "Sensus", country: "FR" },
  { name: "Itron",  country: "US" },
  { name: "Diehl",  country: "DE" }
]

manufacturers.each do |attrs|
  Manufacturer.find_or_create_by!(name: attrs[:name]) do |m|
    m.country = attrs[:country]
    m.tenant  = france
  end
end

# A tenant-owned Entry referencing a replicated Manufacturer — the relationship
# behind the paper's "delete a referenced public row" question.
sensus = Manufacturer.find_by(name: "Sensus")
Entry.find_or_create_by!(description: "Meter batch #1", manufacturer: sensus) if sensus

puts "Seeded #{Tenant.count} tenant(s), #{Manufacturer.count} manufacturer(s), #{Entry.count} entry(ies)."
