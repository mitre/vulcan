# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'disa_guide rake tasks' do
  before(:all) do
    Rails.application.load_tasks
  end

  let(:v4r3_docx) { Rails.root.join('docs/disa-process/attachments/U_Vendor_STIG_Process_Guide_V4R3.docx') }

  describe 'disa_guide:convert' do
    after { Rake::Task['disa_guide:convert'].reenable }

    it 'requires pandoc to be installed' do
      allow_any_instance_of(Object).to receive(:system).with('which', 'pandoc', out: File::NULL).and_return(false)

      expect { Rake::Task['disa_guide:convert'].invoke(v4r3_docx.to_s) }
        .to raise_error(SystemExit)
        .and output(/pandoc not found/).to_stderr
    end

    context 'with pandoc available', if: system('which', 'pandoc', out: File::NULL) do
      it 'rejects missing file argument' do
        expect { Rake::Task['disa_guide:convert'].invoke }
          .to raise_error(SystemExit)
          .and output(/Usage:/).to_stderr
      end

      it 'rejects non-existent file' do
        expect { Rake::Task['disa_guide:convert'].invoke('/tmp/nonexistent.docx') }
          .to raise_error(SystemExit)
          .and output(/not found/).to_stderr
      end

      it 'rejects non-docx file' do
        Tempfile.create(['test', '.txt']) do |f|
          expect { Rake::Task['disa_guide:convert'].invoke(f.path) }
            .to raise_error(SystemExit)
            .and output(/\.docx/).to_stderr
        end
      end

      it 'converts docx to markdown and writes to stdout' do
        output = capture_stdout { Rake::Task['disa_guide:convert'].invoke(v4r3_docx.to_s) }

        expect(output).to start_with("---\ntitle: Vendor STIG Process Guide")
        expect(output).to include('# Vendor STIG Process Guide')
        expect(output).to include('[Download original document (DOCX)]')
        expect(output).to include('## Introduction')
        expect(output).to include('## Planning')
        expect(output).to include('### STIG Template Field Descriptions')
      end

      it 'shifts headings so top-level sections are ##' do
        output = capture_stdout { Rake::Task['disa_guide:convert'].invoke(v4r3_docx.to_s) }

        headings = output.lines.select { |l| l.start_with?('#') }
        expect(headings.first).to start_with('# ')
        section_headings = headings.select { |l| l.start_with?('## ') && !l.start_with?('### ') }
        expect(section_headings.map(&:strip)).to include(
          '## Introduction',
          '## Planning',
          '## Development',
          '## Writing the STIG',
          '## Validation'
        )
      end

      it 'strips the table of contents block' do
        output = capture_stdout { Rake::Task['disa_guide:convert'].invoke(v4r3_docx.to_s) }

        expect(output).not_to include('TABLE OF CONTENTS')
        expect(output).not_to match(/\[.*\]\(#.*\).*\]\(#/)
      end

      it 'strips the revision history table' do
        output = capture_stdout { Rake::Task['disa_guide:convert'].invoke(v4r3_docx.to_s) }

        expect(output).not_to include('REVISION HISTORY')
      end

      it 'extracts version and date from document content' do
        output = capture_stdout { Rake::Task['disa_guide:convert'].invoke(v4r3_docx.to_s) }

        expect(output).to include('Version 4, Release 3')
        expect(output).to match(/\d{1,2}\s+\w+\s+\d{4}/)
      end
    end
  end

  describe 'disa_guide:update' do
    after { Rake::Task['disa_guide:update'].reenable }

    context 'with pandoc available', if: system('which', 'pandoc', out: File::NULL) do
      let(:output_dir) { Dir.mktmpdir('disa_guide_test') }
      let(:guide_dir) { Rails.root.join('docs/disa-process') }

      after { FileUtils.rm_rf(output_dir) }

      it 'writes markdown file and copies docx to both attachment directories' do
        md_path = File.join(output_dir, 'vendor-stig-process-guide.md')
        public_attachments = File.join(output_dir, 'public_attachments')
        FileUtils.mkdir_p(public_attachments)

        Rake::Task['disa_guide:update'].invoke(
          v4r3_docx.to_s, md_path, public_attachments
        )

        expect(File.exist?(md_path)).to be true
        content = File.read(md_path)
        expect(content).to start_with("---\ntitle: Vendor STIG Process Guide")
        expect(content).to include('[Download original document (DOCX)]')

        docx_in_public = Dir.glob(File.join(public_attachments, '*.docx'))
        expect(docx_in_public.length).to eq(1)
      end

      it 'is idempotent — running twice produces same output' do
        md_path = File.join(output_dir, 'vendor-stig-process-guide.md')
        public_attachments = File.join(output_dir, 'public_attachments')
        FileUtils.mkdir_p(public_attachments)

        Rake::Task['disa_guide:update'].invoke(
          v4r3_docx.to_s, md_path, public_attachments
        )
        first_content = File.read(md_path)

        Rake::Task['disa_guide:update'].reenable
        Rake::Task['disa_guide:convert'].reenable

        Rake::Task['disa_guide:update'].invoke(
          v4r3_docx.to_s, md_path, public_attachments
        )
        second_content = File.read(md_path)

        expect(first_content).to eq(second_content)
      end
    end
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
