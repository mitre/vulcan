# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stig and SRG Blueprints' do
  let_it_be(:srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read
    parsed = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed)
    srg.xml = srg_xml
    srg.save!
    srg
  end
  let_it_be(:stig) do
    s = create(:stig)
    s.update_columns(xml: '<?xml version="1.0"?><Benchmark id="test"/>')
    s
  end

  describe StigBlueprint do
    describe ':index view' do
      let(:json) { StigBlueprint.render_as_hash(stig, view: :index) }

      it 'includes listing fields' do
        %i[id stig_id name title version benchmark_date].each do |f|
          expect(json).to have_key(f), "Missing :index field: #{f}"
        end
      end

      it 'includes severity_counts' do
        expect(json).to have_key(:severity_counts)
        expect(json[:severity_counts]).to have_key(:high)
        expect(json[:severity_counts]).to have_key(:medium)
        expect(json[:severity_counts]).to have_key(:low)
      end

      it 'excludes xml from index view' do
        expect(json).not_to have_key(:xml)
      end

      it 'does NOT include description (not needed on index)' do
        expect(json).not_to have_key(:description)
      end
    end

    describe ':show view' do
      let(:json) { StigBlueprint.render_as_hash(stig, view: :show) }

      it 'includes detail fields' do
        %i[id stig_id name title version benchmark_date description].each do |f|
          expect(json).to have_key(f), "Missing :show field: #{f}"
        end
      end

      it 'excludes xml from show view' do
        expect(json).not_to have_key(:xml)
      end

      it 'includes stig_rules array' do
        expect(json).to have_key(:stig_rules)
        expect(json[:stig_rules]).to be_an(Array)
      end
    end
  end

  describe SrgBlueprint do
    describe ':index view' do
      let(:json) { SrgBlueprint.render_as_hash(srg, view: :index) }

      it 'includes listing fields' do
        %i[id srg_id name title version].each do |f|
          expect(json).to have_key(f), "Missing :index field: #{f}"
        end
      end

      it 'includes severity_counts' do
        expect(json).to have_key(:severity_counts)
      end

      it 'excludes xml from SRG index view' do
        expect(json).not_to have_key(:xml)
      end
    end

    describe ':show view' do
      let(:json) { SrgBlueprint.render_as_hash(srg, view: :show) }

      it 'excludes xml from SRG show view' do
        expect(json).not_to have_key(:xml)
      end

      it 'includes srg_rules array' do
        expect(json).to have_key(:srg_rules)
        expect(json[:srg_rules]).to be_an(Array)
        expect(json[:srg_rules].length).to be > 0
      end
    end
  end

  describe 'collection rendering' do
    it 'renders a collection of STIGs without xml' do
      stigs = Stig.with_severity_counts.limit(3).to_a
      result = StigBlueprint.render_as_hash(stigs, view: :index)

      expect(result).to be_an(Array)
      result.each do |item|
        expect(item).not_to have_key(:xml)
        expect(item).to have_key(:severity_counts)
      end
    end
  end
end
