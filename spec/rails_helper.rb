# frozen_string_literal: true

require "spec_helper"

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "database_cleaner/active_record"

# Pending migrations are an error, not a prompt, in CI.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.use_transactional_fixtures = false # DatabaseCleaner owns isolation
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods

  # Truncation (not transaction): specs switch shards via
  # ConnectionSwitcher.switch_shard, writing through a second connection. A
  # surrounding transaction on the default connection would lock those
  # cross-connection writes, so we keep no open transaction during the example
  # and truncate between examples instead.
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
    DatabaseCleaner.strategy = :truncation
  end

  config.around do |example|
    DatabaseCleaner.cleaning { example.run }
  end
end
