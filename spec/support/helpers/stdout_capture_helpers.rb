# frozen_string_literal: true

require 'active_support/testing/stream'

# Shared $stdout capture for specs that exercise rake tasks / CLI code that
# writes progress to stdout. Without it, that output (the full DISA guide from
# docs:guide:convert, ADNM run summaries, provider-rename counts) floods the
# suite log and buries real failures.
#
# Delegates to Rails' ActiveSupport::Testing::Stream, which reopens the stream
# at the file-descriptor level — so it captures both Ruby `puts`/`$stdout.puts`
# and any subprocess output on FD 1.
module StdoutCaptureHelpers
  include ActiveSupport::Testing::Stream

  # Run the block with $stdout captured; returns everything written as a String.
  def capture_stdout(&)
    capture(:stdout, &)
  end
end

RSpec.configure do |config|
  config.include StdoutCaptureHelpers
end
