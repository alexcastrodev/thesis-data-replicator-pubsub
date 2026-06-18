# Tenant-owned table — NOT replicated. Read-write locally on each replica.
# It references a replicated Manufacturer, which is what makes the
# "delete a referenced public row" question concrete.
# == Schema Information
#
# Table name: entries
# Database name: primary
#
#  id              :bigint           not null, primary key
#  description     :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  manufacturer_id :uuid             not null
#
# Indexes
#
#  index_entries_on_manufacturer_id  (manufacturer_id)
#
# Foreign Keys
#
#  fk_rails_...  (manufacturer_id => manufacturers.id)
#
class Entry < ApplicationRecord
  belongs_to :manufacturer

  validates :description, presence: true
end
