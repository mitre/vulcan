# Be sure to restart your server when you modify this file.

# Add new mime types for use in respond_to blocks:
# Mime::Type.register "text/richtext", :rtf
Mime::Type.register "application/xls", :xls
Mime::Type.register "application/xccdf", :xccdf
Mime::Type.register "application/ckl", :ckl
Mime::Type.register "application/xlsx", :xlsx
Mime::Type.register "application/octet-stream", :plist_binary, [], ["binary.plist"]
Mime::Type.register "application/x-gzip", :targz, [], ["tar.gz"]

