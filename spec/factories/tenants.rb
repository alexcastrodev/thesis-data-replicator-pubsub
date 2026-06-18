# == Schema Information
#
# Table name: tenants
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  subdomain  :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_tenants_on_subdomain  (subdomain) UNIQUE
#
FactoryBot.define do
  factory :tenant do
    sequence(:name) { |n| "Tenant #{n}" }
    sequence(:subdomain) { |n| "tenant#{n}" }
  end
end
