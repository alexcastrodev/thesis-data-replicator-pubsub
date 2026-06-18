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
FactoryBot.define do
  factory :manufacturer do
    sequence(:name) { |n| "Manufacturer #{n}" }
    country { "FR" }
    tenant
  end
end
