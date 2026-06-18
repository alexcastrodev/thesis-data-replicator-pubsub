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
FactoryBot.define do
  factory :entry do
    sequence(:description) { |n| "Entry #{n}" }
    manufacturer
  end
end
