# frozen_string_literal: true

namespace :disa_guide do
  desc 'Convert a DISA Vendor STIG Process Guide .docx to cleaned markdown (stdout)'
  task :convert, %i[docx_path] => :environment do |_t, args|
    unless system('which', 'pandoc', out: File::NULL)
      warn 'pandoc not found. Install: brew install pandoc (macOS) or apt install pandoc (Linux)'
      exit 1
    end

    docx_path = args[:docx_path]
    if docx_path.blank?
      warn 'Usage: rake disa_guide:convert[path/to/file.docx]'
      exit 1
    end

    unless File.exist?(docx_path)
      warn "File not found: #{docx_path}"
      exit 1
    end

    unless docx_path.end_with?('.docx')
      warn "Expected a .docx file, got: #{File.extname(docx_path)}"
      exit 1
    end

    markdown = convert_docx_to_markdown(docx_path)
    $stdout.puts markdown
  end

  desc 'Full pipeline: convert .docx, write .md, copy .docx to attachment dirs'
  task :update, %i[docx_path md_output public_attachments_dir] => :environment do |_t, args|
    docx_path = args[:docx_path]
    md_output = args[:md_output] || Rails.root.join('docs/disa-process/vendor-stig-process-guide.md').to_s
    public_attachments = args[:public_attachments_dir] || Rails.root.join('docs/public/attachments').to_s

    Rake::Task['disa_guide:convert'].invoke(docx_path)
    Rake::Task['disa_guide:convert'].reenable

    markdown = convert_docx_to_markdown(docx_path)
    File.write(md_output, markdown)

    FileUtils.mkdir_p(public_attachments)
    FileUtils.cp(docx_path, public_attachments)

    puts "Wrote: #{md_output}"
    puts "Copied .docx to: #{public_attachments}"
  end
end

def convert_docx_to_markdown(docx_path)
  raw = IO.popen(
    [
      'pandoc',
      docx_path,
      '-f', 'docx',
      '-t', 'markdown',
      '--wrap=none',
      '--markdown-headings=atx',
      '--shift-heading-level-by=1'
    ],
    err: File::NULL,
    &:read
  )

  lines = raw.lines
  version_line, date_line = extract_version_and_date(lines)
  filename = File.basename(docx_path)

  header = build_header(version_line, date_line, filename)
  body = strip_front_matter(lines)
  body = strip_toc(body)
  body = strip_revision_history(body)
  body = clean_pandoc_artifacts(body)

  "#{header}#{body}"
end

def extract_version_and_date(lines)
  version_line = nil
  date_line = nil

  lines.each do |line|
    plain = line.strip.gsub('**', '')
    next if plain.empty?

    if plain.match?(/\AVersion\s+\d+,\s+Release\s+\d+\z/i)
      version_line = plain
    elsif plain.match?(/\A\d{1,2}\s+\w+\s+\d{4}\z/)
      date_line = plain
    end

    break if version_line && date_line
  end

  [version_line, date_line]
end

def build_header(version_line, date_line, filename)
  parts = []
  parts << "---\n"
  parts << "title: Vendor STIG Process Guide\n"
  parts << "description: \"DISA #{version_line} — full process lifecycle, field requirements, and review stages.\"\n" if version_line
  parts << "---\n\n"
  parts << "# Vendor STIG Process Guide\n\n"
  parts << "**DISA — #{version_line} — #{date_line}**\n\n" if version_line && date_line
  parts << "[Download original document (DOCX)](/attachments/#{filename})\n\n"
  parts << "---\n\n"
  parts.join
end

def strip_front_matter(lines)
  in_body = false
  result = []

  lines.each do |line|
    in_body = true if !in_body && line.strip.match?(/\A[#]{1,2}\s+(Introduction|Planning|Development)\b/)

    result << line if in_body
  end

  result.join
end

def strip_toc(text)
  text.gsub(/^\*\*TABLE OF CONTENTS\*\*.*?(?=^[#]{1,2}\s)/m, '')
end

def strip_revision_history(text)
  text.gsub(/^\*\*REVISION HISTORY\*\*.*?(?=^[#]{1,2}\s)/m, '')
end

def clean_pandoc_artifacts(text)
  result = text
  result = remove_html_comments(result)
  result = convert_grid_tables(result)
  result = remove_table_captions(result)
  result = remove_pandoc_attrs(result)
  result = compact_list_spacing(result)
  "#{result.gsub(/\n{3,}/, "\n\n").rstrip}\n"
end

def remove_html_comments(text)
  text.gsub(/^<!-- -->\n/, '')
end

def convert_grid_tables(text)
  text.gsub(/^  -[-]+\n(.*?)^  -[-]+$/m) do |match|
    rows = Regexp.last_match(1)
    lines = rows.lines.map(&:strip).reject(&:empty?)
    header_line = lines.shift
    next match unless header_line

    cols = header_line.split(/\s{2,}/)
    pipe_header = "| #{cols.join(' | ')} |"
    pipe_sep = "| #{cols.map { '---' }.join(' | ')} |"
    pipe_rows = lines.map do |line|
      cells = line.split(/\s{2,}/, cols.length)
      "| #{cells.join(' | ')} |"
    end

    [pipe_header, pipe_sep, *pipe_rows].join("\n")
  end
end

def remove_table_captions(text)
  text.gsub(/^\s*: \[\]Table[^\n]*\n/, '')
end

def remove_pandoc_attrs(text)
  text.gsub(/\{[^}]*\.anchor[^}]*\}/, '')
      .gsub(/\[?\]\{[^}]*\}/, '')
      .gsub(/\{width="[^"]*"\s*height="[^"]*"\}/, '')
end

def compact_list_spacing(text)
  text.gsub(/^(- [^\n]+)\n\n(?=- )/m, "\\1\n")
      .gsub(/^(  - [^\n]+)\n\n(?=  - )/m, "\\1\n")
end
