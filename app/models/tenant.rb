# Public (replicated) table — owned by DB0, copied read-only to every replica.
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
class Tenant < ApplicationRecord
  include Replicable

  has_many :manufacturers, dependent: :restrict_with_error

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: true
end
