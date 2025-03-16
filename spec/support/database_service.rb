# frozen_string_literal: true

require 'singleton'

# DatabaseService manages the test database connection
# It supports both Docker-based PostgreSQL and embedded PGLite
class DatabaseService
  include Singleton

  DB_PORT = 5432
  DB_HOST = 'localhost'
  DB_USER = 'postgres'
  DB_PASSWORD = 'vulcan_development'
  DB_NAME = 'vulcan_vue_test'
  PGLITE_DATA_DIR = File.join(Rails.root, 'tmp', 'pglite')

  attr_reader :mode, :uri

  def initialize
    @mode = ENV['TEST_DB_MODE']&.downcase || 'auto'
    @mode = detect_best_mode if @mode == 'auto'
    @pglite_server = nil
  end

  # Start the database service
  def start
    if docker_mode?
      start_docker_postgres
    else
      start_pglite
    end
    wait_for_postgres
    setup_database
  end

  # Stop the database service
  def stop
    if docker_mode?
      stop_docker_postgres
    else
      stop_pglite
    end
  end

  # Get database connection URI
  def connection_uri
    @uri || "postgres://#{DB_USER}:#{DB_PASSWORD}@#{DB_HOST}:#{DB_PORT}/#{DB_NAME}"
  end

  # Check if the database is running
  def running?
    system("pg_isready -h #{DB_HOST} -p #{DB_PORT} > /dev/null 2>&1")
  end

  # Is Docker mode active?
  def docker_mode?
    @mode == 'docker'
  end

  # Is PGLite mode active?
  def pglite_mode?
    @mode == 'pglite'
  end

  private

  # Detect the best available mode based on environment
  def detect_best_mode
    if ENV['CI'] == 'true'
      # In CI environments, prefer Docker for isolation
      'docker'
    elsif defined?(PGLite) && PGLite.installable?
      # PGLite mode if available (faster local development)
      'pglite'
    else
      # Default to Docker if PGLite isn't available
      'docker'
    end
  end

  # Start PostgreSQL via Docker
  def start_docker_postgres
    puts "Starting PostgreSQL via Docker..."
    system("docker-compose -f docker-compose.test.yml up -d db-test")
    @uri = "postgres://#{DB_USER}:#{DB_PASSWORD}@#{DB_HOST}:#{DB_PORT}/#{DB_NAME}"
  end

  # Start PostgreSQL via PGLite
  def start_pglite
    return if @pglite_server&.running?

    puts "Starting PostgreSQL via PGLite..."
    require 'pglite'
    
    # Create directory for PGLite data
    FileUtils.mkdir_p(PGLITE_DATA_DIR)
    
    # Configure and start PGLite
    @pglite_server = PGLite::Server.new(
      data_dir: PGLITE_DATA_DIR,
      port: DB_PORT,
      username: DB_USER, 
      password: DB_PASSWORD
    )
    
    @pglite_server.start
    @uri = @pglite_server.connection_uri
  end

  # Stop Docker PostgreSQL
  def stop_docker_postgres
    puts "Stopping PostgreSQL via Docker..."
    system("docker-compose -f docker-compose.test.yml stop db-test")
  end

  # Stop PGLite
  def stop_pglite
    return unless @pglite_server&.running?

    puts "Stopping PostgreSQL via PGLite..."
    @pglite_server.stop
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

  # Check if the test database exists
  def database_exists?
    if docker_mode?
      system("docker exec vulcan-db-test-1 psql -U postgres -lqt | grep -q #{DB_NAME}")
    else
      conn = PG.connect(
        host: DB_HOST,
        port: DB_PORT,
        user: DB_USER,
        password: DB_PASSWORD
      )
      result = conn.exec("SELECT 1 FROM pg_database WHERE datname='#{DB_NAME}'")
      !result.nil? && result.count > 0
    ensure
      conn&.close
    end
  end
end