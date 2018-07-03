require 'inspec/objects'
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
  belongs_to :vendor
  belongs_to :sponsor_agency
  serialize :srg_ids
  accepts_nested_attributes_for :project_controls
  
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
  
  def to_prof
    @controls = []
    @random = rand(1000..100000)
    generate_controls
    create_skeleton
    write_controls
    create_json
    compress_profile
    File.read("tmp/#{@random}/#{self.name}.zip")
  end
  
  private
  
  def compress_profile
    Dir.chdir "tmp/#{@random}"
    system("zip -r #{Rails.root}/tmp/#{@random}/#{self.name}.zip #{self.name}")
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
    self.project_controls.select {|control| control.status == 'Applicable - Configurable'}.each do |contr|
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
    system("inspec init profile #{Rails.root}/tmp/#{@random}/#{self.name}")
    system("rm #{Rails.root}/temp/#{@random}/#{self.name}/controls/example.rb")
  end

  def create_json
    system("inspec json #{Rails.root}/tmp/#{@random}/#{self.name} | jq . | tee #{Rails.root}/tmp/#{@random}/#{self.name}-overview.json")
  end
  
  # Writes InSpec controls to file
  def write_controls
    @controls.each do |control, code|
      file_name = control.id.to_s
      myfile = File.new("#{Rails.root}/tmp/#{@random}/#{self.name}/controls/#{file_name}.rb", 'w')
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
