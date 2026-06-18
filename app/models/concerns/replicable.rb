# Mixin for the public/configuration tables that are copied to every regional
# replica (DB1, DB2, DB3). With native PostgreSQL logical replication the actual
# copying is done by Postgres itself (CREATE PUBLICATION on the source, CREATE
# SUBSCRIPTION on each replica — see lib/tasks/replication.rake); the application
# does NOT produce or consume change events.
#
#   class Manufacturer < ApplicationRecord
#     include Replicable
#   end
#
# So what's left for the model to do is enforce the *single-writer* rule that
# logical replication assumes: the published tables are read-write only on the
# source (DB0). On a replica they are read-only — rows appear there solely via the
# Postgres subscription, never through application writes. Including this concern
# turns a stray `Model.save` / `Model.destroy` on a replica connection into a
# validation failure instead of a write that would later collide with replication.
#
# NB: named `Replicable` (not `Replicateable`) because the Rails application
# module is itself `Replicateable` — reusing that name would collide with the
# app's root namespace under Zeitwerk.
module Replicable
  extend ActiveSupport::Concern

  # The replica shards that subscribe to the source's publication. The canonical
  # value lives in config/initializers/replication.rb so it is available before
  # Zeitwerk autoloading (e.g. to the replication rake task).
  SHARDS = REPLICATION_SHARDS

  included do
    # Single-writer guard: a published table is writable only on the source
    # connection (:default). Any save through ActiveRecord on a replica fails
    # validation. Replicas receive rows only over the Postgres logical-replication
    # stream (no ActiveRecord callbacks), so this never blocks a legitimate
    # replicated apply — it only stops a stray `Model.save` on a replica.
    validate :writable_on_source
    # destroy skips validations, so guard it with a callback that aborts on a
    # replica connection.
    before_destroy :writable_on_source!
  end

  private

  def source_connection?
    ConnectionSwitcher.current_shard == :default
  end

  def writable_on_source
    return if source_connection?

    errors.add(:base, "public tables are read-only on #{ConnectionSwitcher.current_shard}; " \
                      "only the source (:default) may write them — replicas receive rows " \
                      "via PostgreSQL logical replication")
  end

  # before_destroy variant: abort the destroy on a replica connection.
  def writable_on_source!
    throw :abort unless source_connection?
  end
end
