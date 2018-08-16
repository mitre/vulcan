require 'inspec/objects'
require 'date'
###
# TODO: FORM VALIDATION
###
class Project < ApplicationRecord
  resourcify
  before_destroy :destroy_project_controls
  

  has_many  :project_controls
  has_many  :project_histories
  has_and_belongs_to_many :srgs
  has_and_belongs_to_many :users
  belongs_to :vendor, optional: true
  belongs_to :sponsor_agency, optional: true
  serialize :srg_ids
  accepts_nested_attributes_for :project_controls
  
  
  attribute :name
  attribute :title
  attribute :maintainer
  attribute :copyright 
  attribute :copyright_email
  attribute :license
  attribute :summary
  attribute :version
  attribute :status
  
  attr_encrypted :name, key: Rails.application.secrets.db
  attr_encrypted :title, key: Rails.application.secrets.db
  attr_encrypted :maintainer, key: Rails.application.secrets.db
  attr_encrypted :copyright, key: Rails.application.secrets.db
  attr_encrypted :copyright_email, key: Rails.application.secrets.db
  attr_encrypted :license, key: Rails.application.secrets.db
  attr_encrypted :summary, key: Rails.application.secrets.db
  attr_encrypted :version, key: Rails.application.secrets.db
  attr_encrypted :status, key: Rails.application.secrets.db

  
  # def to_csv
  #   attributes = %w{name title maintainer copyright copyright_email license summary version srg_ids}
  # 
  #   CSV.generate(headers: true) do |csv|
  #     csv << attributes
  # 
  #     csv << attributes.map{ |attr| self.send(attr) }
  #   end
  # end
  
  def to_xccdf(params)
    inspec_profile = to_inspec_profile
    InspecTools::Inspec.new(inspec_profile.to_json).to_xccdf(benchmark_attributes(params))
  end
  
  def to_csv
    inspec_profile = to_inspec_profile
    InspecTools::Inspec.new(inspec_profile.to_json).to_csv
  end
  
  def to_inspec_profile
    inspec_json = {}
    inspec_json = insert_profile_data(inspec_json)
    inspec_json['controls'] = insert_controls
    inspec_json
  end
  
  def to_prof
    @controls = []
    @random = rand(1000..100000)
    @name = self.name.gsub(/\s/, '_')
    generate_controls
    create_skeleton
    write_controls
    create_json
    compress_profile
    File.read("tmp/#{@random}/#{@name}.zip")
  end
  
  private
  
  def benchmark_attributes(params)
    attributes = {}
    attributes["benchmark.id"] = params["benchmark_id"]
    attributes["benchmark.title"] = self.title
    attributes["benchmark.description"] = self.summary
    attributes["benchmark.version"] = self.version
    attributes["benchmark.status"] = params["benchmark_status"]
    attributes["benchmark.status.date"] = Date.today.to_s
    attributes["benchmark.notice"] = params["benchmark_notice"]
    attributes["benchmark.plaintext"] = params["benchmark_plaintext"]
    attributes["benchmark.plaintext.id"] = params["benchmark_plaintext_id"]
    attributes["reference.href"] = params["reference_href"]
    attributes["reference.dc.source"] = params["reference_dc_source"]
    attributes
  end
  
  def insert_profile_data(inspec_json)
    inspec_json['name'] = self.name
    inspec_json['title'] = self.title
    inspec_json['maintainer'] = self.maintainer
    inspec_json['copyright'] = self.copyright
    inspec_json['copyright_email'] = self.copyright_email
    inspec_json['license'] = self.license
    inspec_json['summary'] = self.summary
    inspec_json['version'] = self.version
    inspec_json
  end
  
  def insert_controls
    controls = []
    self.project_controls.each do |project_control|
      control = {}
      control['tags'] = {}
      control['id'] = project_control.control_id
      control['title'] = project_control.title
      control['desc'] = project_control.description
      control['impact'] = project_control.impact
      control['tags']['check'] = project_control.checktext
      control['tags']['fix'] = project_control.fixtext
      control['tags']['nist'] = project_control.nist_controls.collect {|nist| nist.family + '-' + nist.index }.push('Rev_4')
      control['tags']['gtitle'] = project_control.srg_title_id
      control['tags']['gid'] = project_control.control_id
      control['code'] = project_control.code    
      controls << control  
    end
    controls
  end
  
  def compress_profile
    Dir.chdir "tmp/#{@random}"
    system("zip -r #{Rails.root}/tmp/#{@random}/#{@name}.zip #{@name}")
    stdout, stderr, status = Open3.capture3("zip -r #{Rails.root}/tmp/#{@random}/#{@name}.zip #{@name}")
    Dir.chdir "#{Rails.root}"
  end
  
  # sets max length of a line before line break
  def wrap(s, width = WIDTH)
    s.gsub!("desc  \"\n    ", 'desc  "')
    s.gsub!(/\\r/, "\n")
    s.gsub!(/\\n/, "\n")

    WordWrap.ww(s.to_s, width)
  end

  
  # converts passed in data into InSpec format
  def generate_controls
    self.project_controls.select {|control| control.applicability == 'Applicable - Configurable'}.each do |contr|
      print '.'
      control = Inspec::Control.new
      control.id = contr.control_id
      control.title = contr.title
      control.desc = contr.description
      control.impact = control.impact
      control.add_tag(Inspec::Tag.new('nist', contr.nist_controls.collect{|nist| nist.family + '-' + nist.index})) unless contr.nist_controls.nil?  # tag nist: [AC-3, 4]  ##4 is the version
      control.add_tag(Inspec::Tag.new('audit text', contr.checktext)) unless contr.checktext.nil?
      control.add_tag(Inspec::Tag.new('fix', contr.fixtext)) unless contr.fixtext.nil?
      control.add_tag(Inspec::Tag.new('Related SRG', contr.srg_title_id)) unless contr.srg_title_id.nil?
      @controls << [control, contr.code]
    end
  end
  
  def create_skeleton
    Dir.mkdir("#{Rails.root}/tmp/#{@random}")
    Dir.chdir "tmp/#{@random}"
    stdout, stderr, status = Open3.capture3("inspec init profile #{@name}")
    stdout, stderr, status = Open3.capture3("rm #{Rails.root}/tmp/#{@random}/#{@name}/controls/example.rb")
    Dir.chdir "#{Rails.root}"
  end

  def create_json
    Dir.chdir "#{Rails.root}/tmp/#{@random}"
    stdout, stderr, status = Open3.capture3("inspec json #{@name} | jq . | tee #{@name}-overview.json")
    Dir.chdir "#{Rails.root}"
  end
  
  # Writes InSpec controls to file
  def write_controls
    @controls.each do |control, code|
      file_name = control.id.to_s
      myfile = File.new("#{Rails.root}/tmp/#{@random}/#{@name}/controls/#{file_name}.rb", 'w')
      width = 80

      content = control.to_ruby.gsub(/\nend/, "\n\n" + code + "\nend\n")
      myfile.puts wrap(content, width)
      
      myfile.close
    end
  end

  def destroy_project_controls
    self.project_controls.destroy_all   
  end
end
