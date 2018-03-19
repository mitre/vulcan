
module SrgHelper
  def fetch_srgs
    db = connect_to_db
    rows = db.execute('SELECT * FROM SRGs')
    db.close
    rows
  end

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
end
