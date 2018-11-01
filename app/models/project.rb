require 'inspec/objects'
require 'fileutils'
require 'date'
require 'pathname'
require 'shellwords'

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
    @name = name.gsub(/\s/, '_')
    generate_controls
    create_skeleton
    write_controls
    create_json
    compress_profile
    File.read("tmp/#{@random}/#{@name}.zip")
  end

  def applicable_counts
    counts_ary = Project.labels.map { |label| JSON.parse({ label: label, value: controls[label].nil? ? 0 : controls[label].count }.to_json) }
    counts_ary << JSON.parse({ label: 'Not Yet Set', value: controls[nil].nil? ? 0 : controls[nil].count }.to_json)
    { 'results' => counts_ary }.to_json
  end

  def self.labels
    ['Applicable - Configurable', 'Applicable - Does Not Meet', 'Applicable - Inherently Meets', 'Not Applicable']
  end

  def self.options
    labels.map { |label| [label, label] }
  end

  def self.build(project_json, srg_ids, vendor_id, sponsor_agency_id)
    return nil if srg_ids.nil?

    begin
      project = Project.new(project_json)
      project.srgs << Srg.where(title: srg_ids.reject { |srg_id| srg_id == '0' }.drop(1))
      project.vendor = Vendor.find(vendor_id)
      project.sponsor_agency = SponsorAgency.find(sponsor_agency_id)
      project.users << project.vendor.users
      project.users << project.sponsor_agency.users
    rescue ActiveRecord::RecordNotFound
      nil
    rescue StandardError => e
      logger.debug e
      nil
    end
    project
  end

  private

  def benchmark_attributes(params)
    attributes = {}
    attributes['benchmark.id'] = params['benchmark_id']
    attributes['benchmark.title'] = title
    attributes['benchmark.description'] = summary
    attributes['benchmark.version'] = version
    attributes['benchmark.status'] = params['benchmark_status']
    attributes['benchmark.status.date'] = Date.today.to_s
    attributes['benchmark.notice'] = params['benchmark_notice']
    attributes['benchmark.plaintext'] = params['benchmark_plaintext']
    attributes['benchmark.plaintext.id'] = params['benchmark_plaintext_id']
    attributes['reference.href'] = params['reference_href']
    attributes['reference.dc.source'] = params['reference_dc_source']
    attributes
  end

  def insert_profile_data(inspec_json)
    inspec_json['name'] = name
    inspec_json['title'] = title
    inspec_json['maintainer'] = maintainer
    inspec_json['copyright'] = copyright
    inspec_json['copyright_email'] = copyright_email
    inspec_json['license'] = license
    inspec_json['summary'] = summary
    inspec_json['version'] = version
    inspec_json
  end

  def insert_controls
    controls = []
    project_controls.each do |project_control|
      control = {}
      control['tags'] = {}
      control['id'] = project_control.control_id
      control['title'] = project_control.title
      control['desc'] = project_control.description
      control['impact'] = project_control.impact
      control['tags']['check'] = project_control.checktext
      control['tags']['fix'] = project_control.fixtext
      control['tags']['nist'] = project_control.nist_controls.collect { |nist| nist.family + '-' + nist.index }.push('Rev_4')
      control['tags']['gtitle'] = project_control.srg_title_id
      control['tags']['gid'] = project_control.control_id
      control['code'] = project_control.code
      controls << control
    end
    controls
  end

  def compress_profile
    Dir.chdir "tmp/#{@random}"
    filename = Pathname.new("#{Rails.root}/tmp/#{@random}/#{@name}.zip")
    system('zip', '-r', filename.to_s, @name)
    cmd = "zip -r #{filename} #{@name.shellescape}"
    logger.debug "cmd #{cmd}"
    Open3.capture3(%w{cmd})
    Dir.chdir Rails.root.to_s
  end

  # sets max length of a line before line break
  def wrap(line, width = WIDTH)
    line.gsub!("desc  \"\n    ", 'desc  "')
    line.gsub!(/\\r/, "\n")
    line.gsub!(/\\n/, "\n")

    WordWrap.ww(line.to_s, width)
  end

  def inspec_tag(control, name, value)
    control.add_tag(Inspec::Tag.new(name, value)) unless value.nil?
  end

  # converts passed in data into InSpec format
  def generate_controls
    project_controls.select { |control| control.applicability == 'Applicable - Configurable' }.each do |contr|
      control = Inspec::Control.new
      control.id = contr.control_id
      control.title = contr.title
      control.desc = contr.description
      control.impact = control.impact
      control.add_tag(Inspec::Tag.new('nist', contr.nist_controls.collect { |nist| nist.family + '-' + nist.index })) unless contr.nist_controls.nil? # tag nist: [AC-3, 4]  ##4 is the version
      inspec_tag(control, 'audit text', contr.checktext)
      inspec_tag(control, 'fix', contr.fixtext)
      inspec_tag(control, 'Related SRG', contr.srg_title_id)
      @controls << [control, contr.code]
    end
  end

  def create_skeleton
    Dir.mkdir("#{Rails.root}/tmp/#{@random}")
    Dir.chdir "tmp/#{@random}"
    Open3.capture3('inspec', 'init', 'profile', @name)
    filename = "#{Rails.root}/tmp/#{@random}/#{@name}/controls/example.rb"
    FileUtils.rm(filename)
    # Open3.capture3('rm', filename)
    Dir.chdir Rails.root.to_s
  end

  def create_json
    Dir.chdir "#{Rails.root}/tmp/#{@random}"
    cmd = "inspec json #{@name.shellescape} | jq . | tee #{@name.shellescape}-overview.json"
    logger.debug "cmd #{cmd}"
    # Open3.capture3('inspec', 'json', @name.shellescape, '|', 'jq', '.', '|', 'tee', "#{@name.shellescape}-overview.json")
    Open3.capture3(%w{cmd})
    Dir.chdir Rails.root.to_s
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
    project_controls.destroy_all
  end
end
