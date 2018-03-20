require 'roo'
require 'happymapper'
require 'nokogiri'

class SrgController < ApplicationController

  def upload
    # db = connect_to_db
    controls = parse_xccdf(params[:file].path)
    
    
    # headers = excl.row(1)
    # srg_name = params[:file].original_filename[0..-6]
    # create_table(db, headers, srg_name)
    # insert_rows(db, excl, srg_name)
    # insert_new_srg(db, srg_name)
    # db.close
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

  def insert_rows(db, controls, srg_name)
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
  
  def parse_xccdf(srg_path)
    controls = []
    xccdf_xml = File.read(xccdf_path)
    cci_xml = File.read('/data/U_CCI_List.xml')
    cci_items = CCI_List.parse(cci_xml)
    Benchmark.parse(xccdf_xml).each do |group|
      control = {}
      control.id      = group.id
      control.title   = group.rule.title
      control.desc    = group.rule.description 
      control.impact  = get_impact(group.rule.severity)
      control.gtitle  = group.title
      control.gid     = group.id
      control.rid     = group.rule.id
      control.stig_id = group.rule.version
      control.ccis    = group.rule.indents
      control.nists   = cci_items.fetch_nists(group.rule.idents)
      control.check   = group.rule.check.check_content
      control.fix     = group.rule.fixtext
      control.fix_id  = group.rule.fix.id
      
      controls << control
    end
    controls
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

class Check
  include HappyMapper
  tag 'check'
  
  element 'check-content', String, tag: 'check-content'
end

class Fix
  include HappyMapper
  tag 'fix'
  
  attribute :id, String, tag: 'id'
end

class Rule
  include HappyMapper
  tag 'Rule'
  
  attribute :id, String, tag: 'id'
  attribute :severity, String, tag: 'severity'
  element :version, String, tag: 'version'
  element :title, String, tag: 'title'
  element :description, String, tag: 'description'
  has_many :idents, String, tag: 'ident'
  element :fixtext, String, tag: 'fixtext'
  has_one :fix, Fix, tag: 'fix'
  has_one :check, Check, tag: 'check'
end

class Group
  include HappyMapper
  tag 'Group'
  
  attribute :id, String, tag: 'id'
  element :title, String, tag: 'title'
  element :description, String, tag: 'description'
  has_one :rule, Rule, tag: 'Rule'
end

class ReferenceInfo
  include HappyMapper
  tag 'reference'
  
  attribute :href, String, :tag => 'href'
  element :publisher, String, :tag => 'publisher', :namespace => 'dc'
  element :source, String, :tag => 'source', :namespace => 'dc'
end

class ReleaseDate
  include HappyMapper
  tag 'status'
  
  attribute :release_date, String, tag: 'date'
end

class Benchmark
  include HappyMapper
  tag 'Benchmark'
  
  has_one :release_date, ReleaseDate, tag: 'status'
  element :status, String, tag: 'status'
  element :title, String, tag: 'title'
  element :description, String, tag: 'description'
  element :version, String, tag: 'version'
  has_one :reference, ReferenceInfo, tag: 'reference'
  has_many :group, Group, tag: 'Group'
end

class Reference
  include HappyMapper
  tag 'reference'
  
  attribute :creator, String, tag: 'creator'
  attribute :title, String, tag: 'title'
  attribute :version, String, tag: 'version'
  attribute :location, String, tag: 'location'
  attribute :index, String, tag: 'index'
end

class References
  include HappyMapper
  tag 'references'
  
  has_many :references, Reference, tag: 'reference'
end

class CCI_Item
  include HappyMapper
  tag 'cci_item'
  
  attribute :id, String, tag: 'id'
  element :status, String, tag: 'status'
  element :publishdate, String, tag: 'publishdate'
  element :contributor, String, tag: 'contributor'
  element :definition, String, tag: 'definition'
  element :type, String, tag: 'type'
  has_one :references, References, tag: 'references'
end

class CCI_Items
  include HappyMapper
  tag 'cci_items'
  
  has_many :cci_item, CCI_Item, tag: 'cci_item'
end

class Metadata
  include HappyMapper
  tag 'metadata'
  
  element :version, String, tag: 'version'
  element :publishdate, String, tag: 'publishdate'
end

class CCI_List
  include HappyMapper
  tag 'cci_list'
  
  attribute :xsi, String, :tag => 'xsi', :namespace => 'xmlns'
  attribute :schemaLocation, String, :tag => 'schemaLocation', :namespace => 'xmlns' 
  has_one :metadata, Metadata, :tag => 'metadata'
  has_many :cci_items, CCI_Items, :tag => 'cci_items'
  
  def fetch_nists(ccis)
    ccis = [ccis] unless ccis.kind_of?(Array)
    nists = []
    nist_ver = cci_items[0].cci_item[0].references.references.max_by(&:version).version
    ccis.each do |cci| 
      nists << cci_items[0].cci_item.select{ |item| item.id == cci }.first.references.references.max_by(&:version).index
    end
    nists << ('Rev_' + nist_ver)
  end
end
