# frozen_string_literal: true

# == Schema Information
#
# Table name: manufacturers
# Database name: primary
#
#  id         :uuid             not null, primary key
#  country    :string
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  tenant_id  :uuid             not null
#
# Indexes
#
#  index_manufacturers_on_name       (name) UNIQUE
#  index_manufacturers_on_tenant_id  (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
require "rails_helper"

RSpec.describe Manufacturer do
  let(:tenant) { create(:tenant) }

  it "requires a name" do
    manufacturer = build(:manufacturer, tenant: tenant, name: nil)
    expect(manufacturer).not_to be_valid
    expect(manufacturer.errors[:name]).to include("can't be blank")
  end

  describe "name uniqueness" do
    it "rejects a duplicate name (validation)" do
      create(:manufacturer, tenant: tenant, name: "Sensus")
      duplicate = build(:manufacturer, tenant: tenant, name: "Sensus")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end

    it "is enforced globally, across tenants" do
      other_tenant = create(:tenant)
      create(:manufacturer, tenant: tenant, name: "Sensus")
      duplicate = build(:manufacturer, tenant: other_tenant, name: "Sensus")

      expect(duplicate).not_to be_valid
    end

    it "is backed by a database unique index" do
      create(:manufacturer, tenant: tenant, name: "Sensus")
      # Bypass the validation to prove the DB constraint is the real guarantee.
      duplicate = build(:manufacturer, tenant: tenant, name: "Sensus")
      expect { duplicate.save!(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
