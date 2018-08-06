require 'happymapper'
require 'CCIAttributes'
require 'StigAttributes'

class SrgsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_srg, only: [:show, :edit, :update, :destroy]

  # GET /srgs
  # GET /srgs.json
  def index
    @srgs = Srg.all
  end

  # GET /srgs/1
  # GET /srgs/1.json
  def show
  end

  # GET /srgs/new
  def new
    @srg = Srg.new
  end

  # GET /srgs/1/edit
  def edit
  end

  # POST /srgs
  # POST /srgs.json
  def create
    @srg = Srg.new(srg_params)

    respond_to do |format|
      if @srg.save
        format.html { redirect_to @srg, notice: 'Srg was successfully created.' }
        format.json { render :show, status: :created, location: @srg }
      else
        format.html { render :new }
        format.json { render json: @srg.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /srgs/1
  # PATCH/PUT /srgs/1.json
  def update
    respond_to do |format|
      if @srg.update(srg_params)
        format.html { redirect_to @srg, notice: 'Srg was successfully updated.' }
        format.json { render :show, status: :ok, location: @srg }
      else
        format.html { render :edit }
        format.json { render json: @srg.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /srgs/1
  # DELETE /srgs/1.json
  def destroy
    @srg.destroy
    respond_to do |format|
      format.html { redirect_to srgs_url, notice: 'Srg was successfully destroyed.' }
      format.json { head :no_content }
    end
  end
  
  def upload
    srg_controls, srg_hash = parse_xccdf(params[:file].path)
    
    # authorize! :create, Srg
    srg_controls, srg_hash = parse_xccdf(params[:file].path)
    
    @srg = Srg.create(srg_hash)
    srg_controls.each do |srg_control|
      @srg_control = @srg.srg_controls.create(srg_control[:control_params])
      @srg_control.nist_controls << srg_control[:nist_params]
    end
    redirect_to srgs_path, notice: 'Srg uploaded.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_srg
      @srg = Srg.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def srg_params
      params.require(:srg).permit(:title, :description, :publisher, :published)
    end
    
    def parse_xccdf(srg_path)
      controls = []
      srg_hash = {}
      xccdf_xml = File.read(srg_path)
      cci_xml = File.read('data/U_CCI_List.xml')
      cci_items = Services::CCI_List.parse(cci_xml)
      xccdf = Services::Benchmark.parse(xccdf_xml)
      srg_hash[:title] = xccdf.title
      srg_hash[:description] = xccdf.description
      srg_hash[:publisher] = xccdf.reference.publisher
      srg_hash[:published] = xccdf.release_date.release_date

      xccdf.group.each do |group|
        control = {
          control_params: {},
          nist_params: {}
        }
        control[:control_params][:control_id]     = group.id
        control[:control_params][:srg_title_id]  = group.title
        control[:control_params][:title]         = group.rule.title
        control[:control_params][:description]   = group.rule.description.gsub(/<\w?*>|<\/\w?*>/, '')
        control[:control_params][:severity]      = get_impact(group.rule.severity)
        control[:control_params][:checktext]     = group.rule.check.check_content
        control[:control_params][:fixtext]       = group.rule.fixtext
        control[:control_params][:fixid]         = group.rule.fix.id
        nist_family_from_cci = cci_items.fetch_nists(group.rule.idents)
        puts nist_family_from_cci
        nist_family = NistFamily.find_by(short_title: nist_family_from_cci[0].split('-')[0])
        index = nist_family_from_cci[0].split('-')[1].strip.sub(' ', '').sub(' ', '.') + '.'
        index = nist_family_from_cci[0].split('-')[1].strip.gsub(') (', ')(') if nist_family_from_cci[0].include?('(')
        index = nist_family_from_cci[0].split('-')[1].strip if nist_family_from_cci[0].split('-')[1].strip.match(/\A\d{1,2}\z/)
        control[:nist_params] = NistControl.find_by(index: index, nist_families_id: nist_family.id)

        controls << control
      end
      [controls, srg_hash]
    end
    
    def import_ccis(cci_items)
      
    end
    
    # @!method get_impact(severity)
    #   Takes in the STIG severity tag and converts it to the InSpec #{impact}
    #   control tag.
    #   At the moment the mapping is static, so that:
    #     high => 0.7
    #     medium => 0.5
    #     low => 0.3
    # @param severity [String] the string value you want to map to an InSpec
    # 'impact' level.
    #
    # @return impact [Float] the impact level level mapped to the XCCDF severity
    # mapped to a float between 0.0 - 1.0.
    #
    # @todo Allow for the user to pass in a hash for the desired mapping of text
    # values to numbers or to override our hard coded values.
    #
    def get_impact(severity)
      impact = case severity
               when 'low' then 0.3
               when 'medium' then 0.5
               else 0.7
               end
      impact
    end
end
