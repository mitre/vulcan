# frozen_string_literal: true

# Streaming zip-entry read with a hard cap at the entry's declared size.
#
# rubyzip validates entry sizes only on file extraction — streaming reads
# inflate without limit, so an archive whose central directory
# under-declares sizes can expand far past any accounting done from
# declared values. Capping each read at its declaration makes the central
# directory's numbers trustworthy for callers that budget against them,
# and turns a lying archive into a loud Zip::EntrySizeError instead of
# unbounded memory growth.
module ZipEntryReader
  CHUNK_SIZE = 16_384

  def self.read_capped(entry)
    declared = entry.size
    data = +''
    entry.get_input_stream do |is|
      while (chunk = is.sysread(CHUNK_SIZE))
        data << chunk
        raise Zip::EntrySizeError, entry if data.bytesize > declared
      end
    end
    data
  end
end
