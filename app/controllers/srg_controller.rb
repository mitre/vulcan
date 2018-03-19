require 'roo'

class SrgController < ApplicationController

  def upload
    db = connect_to_db
    excl = read_excel(params[:file].path)
    headers = excl.row(1)
    srg_name = params[:file].original_filename[0..-6]
    create_table(db, headers, srg_name)
    insert_rows(db, excl, srg_name)
    insert_new_srg(db, srg_name)
    db.close
    redirect_to srg_index_path
  end

  private

  def connect_to_db
    begin
        db = SQLite3::Database.new 'development.sqlite3'
        puts 'Connected to sqlite'
    rescue SQLite3::Exception => e
        puts "Exception occurred"
        puts e
    end
    db
  end

  def insert_new_srg(db, srg_name)
    db.execute"INSERT INTO SRGs VALUES(\'#{srg_name}\', datetime(\'now\', \'localtime\'))"
  end

  def create_table(db, attributes, table_name)
    query = "CREATE TABLE IF NOT EXISTS #{table_name} ("
    attributes.each do |header|
      header = header.gsub(/\s/, '_')
      header = header.gsub(/Check/, 'check_text')
      query += header + ' TEXT, '
    end
    query = query[0..-3] + ');'
    begin
      db.execute(query)
    rescue SQLite3::Exception => e
      puts "Exception occurred"
      puts e
    end
  end

  def insert_rows(db, excl, srg_name)
    (2..excl.last_row).each do |i|
      row_data = (1..excl.last_column).collect { |j| excl.cell(i,j) }
      query = "INSERT INTO #{srg_name} VALUES("
      row_data.each do |data|
        data = data.gsub(/\'/, '\'\'') unless data.nil?
        query += '\'' + data + '\'' + ', ' unless data.nil?
        query += '\'\', ' if data.nil?
      end
      query = query[0..-3] + ');'
      puts query
      db.execute(query)
    end
  end

  def read_csv(csv_file)
    csv_handle = CSV.parse(csv_file, encoding: 'ISO8859-1')
  rescue => e
    puts "Exception: #{e.message}"
    puts 'Existing...'
    exit
  end

  def read_excel(excel_path)
    excel = Roo::Spreadsheet.open(excel_path)
  rescue => e
    puts "Exception: #{e.message}"
    puts 'Existing...'
    exit
  end
end
