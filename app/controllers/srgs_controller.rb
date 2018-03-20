require 'happymapper'
require 'services/CCIAttributes'
require 'services/StigAttributes'

class SrgsController < ApplicationController
  before_action :set_srg, only: [:show, :edit, :update, :destroy]

  # GET /srgs
  # GET /srgs.json
  def index
    @srgs = Srg.all
  end

  # GET /srgs/1
  # GET /srgs/1.json
  def show
    puts @srg.srg_controls.inspect
    puts "here"
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
      @srg.srg_controls.create(srg_control)
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
      srg_hash[:publisher] = xccdf.release_date
      srg_hash[:published] = xccdf.title

      xccdf.group.each do |group|
        control = {}
        control[:controlId]   = group.id
        control[:title]       = group.rule.title
        control[:description] = group.rule.description 
        control[:severity]    = get_impact(group.rule.severity)
        control[:checktext]   = group.rule.check.check_content
        control[:fixtext]     = group.rule.fixtext
        control[:fixid]       = group.rule.fix.id
        # control[:stig_id]     = group.rule.version
        # control[:ccis    = group.rule.indents
        # control[:nists   = cci_items.fetch_nists(group.rule.idents)
        
        controls << control
      end
      [controls, srg_hash]
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
