# frozen_string_literal: true

require "rails_helper"

# With native PostgreSQL logical replication the copying is done by Postgres, not
# by the application — there is no producer/consumer to drive from a spec, and a
# single test process shares one physical database, so there is no live
# replication stream to assert against here. (The end-to-end copy is exercised by
# `bin/rails replication:demo` against the docker-compose topology.)
#
# What the application is still responsible for is the *single-writer* invariant
# that logical replication assumes: the published tables are read-write only on
# the source (:default); on a replica they are read-only, since rows arrive there
# solely over the Postgres subscription. These specs pin that guard.
RSpec.describe "Replication single-writer guard", type: :model do
  let(:tenant) { create(:tenant) }

  it "allows writes to a published table on the source (:default)" do
    expect { Manufacturer.create!(name: "Sensus", tenant: tenant, country: "FR") }
      .to change(Manufacturer, :count).by(1)
  end

  it "rejects creating a published row on a replica connection" do
    tenant # create it on the source first; the guard below is about the replica write
    ConnectionSwitcher.switch_shard(:db1) do
      manufacturer = Manufacturer.new(name: "Itron", tenant: tenant, country: "US")
      expect(manufacturer.save).to be(false)
      expect(manufacturer.errors[:base].join).to match(/read-only on db1/)
    end
  end

  it "aborts destroying a published row on a replica connection" do
    manufacturer = Manufacturer.create!(name: "Diehl", tenant: tenant, country: "DE")

    ConnectionSwitcher.switch_shard(:db1) do
      expect(manufacturer.destroy).to be(false)
    end

    expect(Manufacturer.exists?(manufacturer.id)).to be(true)
  end
end
