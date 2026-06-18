# Public (replicated) table that carries a foreign key into tenant data
# (paper Constraint 3). Owned by DB0; read-only on the replicas.
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
class Manufacturer < ApplicationRecord
  include Replicable

  belongs_to :tenant
  has_many :entries, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
end
