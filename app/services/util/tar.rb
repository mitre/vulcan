# Copyright (C) 2011 by Colin MacKenzie IV
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'zlib'
require 'fileutils'

module Util
  module Tar
    # Creates a tar file in memory recursively
    # from the given path.
    #
    # Returns a StringIO whose underlying String
    # is the contents of the tar file.
    def tar(path)
      tarfile = StringIO.new("")
      Gem::Package::TarWriter.new(tarfile) do |tar|
        Dir[File.join(path, "**/*")].each do |file|
          mode = File.stat(file).mode
          relative_file = file.sub /^#{Regexp::escape path}\/?/, ''
          
          if File.directory?(file)
            tar.mkdir relative_file, mode
          else
            tar.add_file relative_file, mode do |tf|
              File.open(file, "rb") { |f| tf.write f.read }
            end
          end
        end
      end
      
      tarfile.rewind
      tarfile
    end
    
    # gzips the underlying string in the given StringIO,
    # returning a new StringIO representing the 
    # compressed file.
    def gzip(tarfile)
      gz = StringIO.new("")
      z = Zlib::GzipWriter.new(gz)
      z.write tarfile.string
      z.close # this is necessary!
      
      # z was closed to write the gzip footer, so
      # now we need a new StringIO
      StringIO.new gz.string
    end
    
    # un-gzips the given IO, returning the
    # decompressed version as a StringIO
    def ungzip(tarfile)
      z = Zlib::GzipReader.new(tarfile)
      unzipped = StringIO.new(z.read)
      z.close
      unzipped
    end
    
    # untars the given IO into the specified
    # directory
    def untar(path, destination)
      Gem::Package::TarReader.new( Zlib::GzipReader.open path ) do |tar|
        tar.each do |tarfile|
          destination_file = File.join destination, tarfile.full_name
          
          if tarfile.directory?
            FileUtils.mkdir_p destination_file
          else
            destination_directory = File.dirname(destination_file)
            FileUtils.mkdir_p destination_directory unless File.directory?(destination_directory)
            File.open destination_file, "wb" do |f|
              f.print tarfile.read
            end
          end
        end
      end
    end
  end
end


### Usage Example: ###
#
# include Util::Tar
# 
# io = tar("./Desktop")   # io is a TAR of files
# gz = gzip(io)           # gz is a TGZ
# 
# io = ungzip(gz)         # io is a TAR
# untar(io, "./untarred") # files are untarred
#