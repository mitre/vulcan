# frozen_string_literal: true

require 'singleton'

# DatabaseService manages the test database connection
# Provides a consistent interface for Docker-based PostgreSQL
class DatabaseService
  include Singleton

  DB_PORT = 5432
  DB_HOST = 'localhost'
  DB_USER = 'postgres'
  DB_PASSWORD = 'vulcan_development'
  DB_NAME = 'vulcan_vue_test'

  attr_reader :uri

  def initialize
    @uri = nil
  end

  # Start the database service
  def start
    start_docker_postgres
    wait_for_postgres
    setup_database
  end

  # Stop the database service
  def stop
    stop_docker_postgres
  end

  # Get database connection URI
  def connection_uri
    @uri || "postgres://#{DB_USER}:#{DB_PASSWORD}@#{DB_HOST}:#{DB_PORT}/#{DB_NAME}"
  end

  # Check if the database is running
  def running?
    system("pg_isready -h #{DB_HOST} -p #{DB_PORT} > /dev/null 2>&1")
  end

  private

  # Start PostgreSQL via Docker
  def start_docker_postgres
    puts "Starting PostgreSQL via Docker..."
    system("docker-compose -f docker-compose.test.yml up -d db-test")
    @uri = "postgres://#{DB_USER}:#{DB_PASSWORD}@#{DB_HOST}:#{DB_PORT}/#{DB_NAME}"
  end

  # Stop Docker PostgreSQL
  def stop_docker_postgres
    puts "Stopping PostgreSQL via Docker..."
    system("docker-compose -f docker-compose.test.yml stop db-test")
  end

  # Wait for PostgreSQL to be ready
  def wait_for_postgres
    puts "Waiting for PostgreSQL to be ready..."
    30.times do |i|
      if running?
        puts "PostgreSQL is ready!"
        return
      end
      print "."
      sleep 1
    end
    raise "Failed to connect to PostgreSQL after 30 attempts"
  end

  # Setup test database
  def setup_database
    if database_exists?
      puts "Test database exists, loading schema..."
      system({
        "DATABASE_URL" => connection_uri,
        "RAILS_ENV" => "test"
      }, "bundle exec rails db:schema:load --trace")
    else
      puts "Creating test database..."
      system({
        "DATABASE_URL" => connection_uri.sub("/#{DB_NAME}", ''),
        "RAILS_ENV" => "test"
      }, "bundle exec rails db:create db:schema:load --trace")
    end
  end
  
  # Seed the database with demo data (default Rails seeding)
  def seed_database(type = "demo")
    puts "Seeding database with #{type} data..."
    env = {
      "DATABASE_URL" => connection_uri,
      "RAILS_ENV" => "test"
    }
    
    case type
    when "minimal"
      env["SEED_TYPE"] = "minimal"
    when "standard"
      env["SEED_TYPE"] = "standard"
    when "demo" # Full dataset as per the default Rails seeds.rb
      # Default seeding without special environment variables
    end
    
    success = system(env, "bundle exec rails db:seed")
    if success
      puts "Database seeded successfully with #{type} data."
    else
      puts "Warning: Database seeding failed!"
    end
    
    return success
  end

  # Check if the test database exists
  def database_exists?
    system("docker exec vulcan-db-test-1 psql -U postgres -lqt | grep -q #{DB_NAME}")
  end
end