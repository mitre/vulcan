# frozen_string_literal: true

module Upgrade
  # Shared PostgreSQL admin connection helpers for upgrade services.
  module DatabaseHelper
    private

    def pg_admin_connection
      config = ActiveRecord::Base.connection_db_config.configuration_hash
      conn = PG.connect(host: config[:host], port: config[:port],
                        user: config[:username], password: config[:password],
                        dbname: 'postgres')
      yield conn
    ensure
      conn&.close
    end

    def db_exists?(name)
      pg_admin_connection do |conn|
        conn.exec_params('SELECT 1 FROM pg_database WHERE datname = $1', [name]).ntuples.positive?
      end
    rescue PG::Error
      false
    end
  end
end
