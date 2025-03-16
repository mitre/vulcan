# frozen_string_literal: true

require 'singleton'

# DatabaseService manages the test database connection
# It supports both Docker-based PostgreSQL and embedded pg_tmp
class DatabaseService
  include Singleton

  DB_PORT = 5432
  DB_HOST = 'localhost'
  DB_USER = 'postgres'
  DB_PASSWORD = 'vulcan_development'
  DB_NAME = 'vulcan_vue_test'
  PG_TMP_DIR = File.join(Rails.root, 'tmp', 'pg_tmp')

  attr_reader :mode, :uri

  def initialize
    @mode = ENV['TEST_DB_MODE']&.downcase || 'auto'
    @mode = detect_best_mode if @mode == 'auto'
    @pg_tmp_server = nil
  end

  # Start the database service
  def start
    if docker_mode?
      start_docker_postgres
    else
      start_pg_tmp
    end
    wait_for_postgres
    setup_database
  end

  # Stop the database service
  def stop
    if docker_mode?
      stop_docker_postgres
    else
      stop_pg_tmp
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

  # Is pg_tmp mode active?
  def pg_tmp_mode?
    @mode == 'pg_tmp'
  end

  private

  # Detect the best available mode based on environment
  def detect_best_mode
    if ENV['CI'] == 'true'
      # In CI environments, prefer Docker for isolation
      'docker'
    elsif defined?(PgTmp) || system('which pg_tmp > /dev/null 2>&1')
      # pg_tmp mode if available (faster local development)
      'pg_tmp'
    else
      # Default to Docker if pg_tmp isn't available
      'docker'
    end
  end

  # Start PostgreSQL via Docker
  def start_docker_postgres
    puts "Starting PostgreSQL via Docker..."
    system("docker-compose -f docker-compose.test.yml up -d db-test")
    @uri = "postgres://#{DB_USER}:#{DB_PASSWORD}@#{DB_HOST}:#{DB_PORT}/#{DB_NAME}"
  end

  # Start PostgreSQL via pg_tmp
  def start_pg_tmp
    return if @pg_tmp_server && @pg_tmp_server.alive?

    puts "Starting PostgreSQL via pg_tmp..."
    require 'pg_tmp'
    
    # Create directory for pg_tmp
    FileUtils.mkdir_p(PG_TMP_DIR)
    
    # Start pg_tmp server
    @pg_tmp_server = PgTmp::Server.new
    
    # Set up connection info
    conn_info = @pg_tmp_server.connection_string.match(/postgresql:\/\/(\w+)@([^:]+):(\d+)\/(\w+)/)
    username = conn_info[1]
    host = conn_info[2]
    port = conn_info[3].to_i
    database = conn_info[4]
    
    # Create our database user
    system(
      "PGPASSWORD= psql -h #{host} -p #{port} -U #{username} -d #{database} -c " +
      "'CREATE USER #{DB_USER} WITH SUPERUSER PASSWORD ''#{DB_PASSWORD}'';'"
    )
    
    @uri = "postgres://#{DB_USER}:#{DB_PASSWORD}@#{host}:#{port}/#{DB_NAME}"
  end

  # Stop Docker PostgreSQL
  def stop_docker_postgres
    puts "Stopping PostgreSQL via Docker..."
    system("docker-compose -f docker-compose.test.yml stop db-test")
  end

  # Stop pg_tmp
  def stop_pg_tmp
    return unless @pg_tmp_server&.alive?

    puts "Stopping PostgreSQL via pg_tmp..."
    @pg_tmp_server.stop
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
    if docker_mode?
      system("docker exec vulcan-db-test-1 psql -U postgres -lqt | grep -q #{DB_NAME}")
    else
      # For pg_tmp, we need to parse the connection URI to get the actual host and port
      uri = URI.parse("postgres://#{@uri.split('//')[1]}") if @uri
      host = uri ? uri.host : DB_HOST
      port = uri ? uri.port : DB_PORT
      user = uri ? uri.user : DB_USER
      password = uri ? uri.password : DB_PASSWORD
      
      begin
        conn = PG.connect(
          host: host,
          port: port,
          user: user,
          password: password
        )
        result = conn.exec("SELECT 1 FROM pg_database WHERE datname='#{DB_NAME}'")
        !result.nil? && result.count > 0
      rescue PG::Error => e
        puts "Error checking database existence: #{e.message}"
        false
      ensure
        conn&.close
      end
    end
  end
end