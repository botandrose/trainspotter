module Trainspotter
  class Record < ActiveRecord::Base
    self.abstract_class = true

    SCHEMA_VERSION = 4

    class << self
      def ensure_connected
        return if @connected

        establish_connection(
          adapter: "sqlite3",
          database: Trainspotter.database_path,
          pool: 5,
          timeout: 5000
        )
        ensure_schema
        @connected = true
      end

      def reset_connection!
        return unless @connected

        connection_pool.disconnect!
        connection_handler.remove_connection_pool(name) rescue nil
        @connected = false
      end

      private

      def ensure_schema
        if schema_version != SCHEMA_VERSION
          connection.drop_table(:requests, if_exists: true)
          connection.drop_table(:sessions, if_exists: true)
          connection.drop_table(:file_positions, if_exists: true)
        end

        define_schema
      end

      def define_schema
        connection.create_table :requests, if_not_exists: true do |t|
          t.string :log_request_id, null: false
          t.string :log_file, null: false
          t.string :method
          t.string :path
          t.integer :status
          t.float :duration_ms
          t.string :ip
          t.string :controller
          t.string :action
          t.text :params_json
          t.datetime :started_at
          t.text :entries_json
          t.boolean :completed, default: false
          t.string :session_id
          t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }

          t.index :log_request_id, unique: true, name: "idx_requests_log_request_id", if_not_exists: true
          t.index [:log_file, :started_at], order: { started_at: :desc }, name: "idx_requests_log_file_started_at", if_not_exists: true
          t.index [:log_file, :created_at], name: "idx_requests_log_file_created_at", if_not_exists: true
          t.index :session_id, name: "idx_requests_session_id", if_not_exists: true
        end

        connection.create_table :sessions, id: false, if_not_exists: true do |t|
          t.string :id, null: false, primary_key: true
          t.string :ip, null: false
          t.string :email
          t.datetime :started_at
          t.datetime :ended_at
          t.string :end_reason, default: "ongoing"
          t.integer :request_count, default: 0
          t.string :log_file, null: false

          t.index [:ip, :started_at], order: { started_at: :desc }, name: "idx_sessions_ip_started_at", if_not_exists: true
          t.index :log_file, name: "idx_sessions_log_file", if_not_exists: true
          t.index [:log_file, :ended_at], order: { ended_at: :desc }, name: "idx_sessions_log_file_ended_at", if_not_exists: true
        end

        connection.create_table :file_positions, id: false, if_not_exists: true do |t|
          t.string :log_file, null: false, primary_key: true
          t.integer :position, default: 0
          t.datetime :updated_at, default: -> { "CURRENT_TIMESTAMP" }
        end

        connection.create_table :schema_migrations, id: false, if_not_exists: true do |t|
          t.string :version, null: false
        end

        unless schema_version == SCHEMA_VERSION
          connection.execute("DELETE FROM schema_migrations")
          quoted_version = connection.quote(SCHEMA_VERSION.to_s)
          connection.execute("INSERT INTO schema_migrations (version) VALUES (#{quoted_version})")
        end
      end

      def schema_version
        connection.select_value("SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1")&.to_i
      rescue ActiveRecord::StatementInvalid
        nil
      end
    end
  end
end
