#
# Copyright 2020 The MITRE Corporation
#
# All Rights Reserved.
#

name "vulcan"
maintainer "Robert Clark <rbclark@mitre.org>"
homepage "https://github.com/mitre/vulcan"

# Defaults to C:/vulcan on Windows
# and /opt/vulcan on all other platforms
install_dir "#{default_root}/#{name}"

build_version Omnibus::BuildVersion.semver
build_iteration 1

override :ruby, version: "2.6.6"
override :rubygems, version: "3.1.2" # rubygems ships its own bundler which may differ from bundler defined below and then we get double bundler which makes the omnibus environment unhappy. Make sure these versions match before bumping either.
override :bundler, version: "2.1.2" # this must match the BUNDLED WITH in all the repo's Gemfile.locks
override :nokogiri, version: "1.10.9"
override :'omnibus-ctl', version: 'master'
override :'openssl', version: '1.1.1f'
override :'chef-gem', version: '14.14.29'

dependency "preparation"

# vulcan dependencies/components
dependency "vulcan"
dependency "vulcan-cookbooks"
dependency "vulcan-ctl"

dependency "ruby-cleanup"

exclude "**/.git"
exclude "**/bundler/git"

package :deb do
  compression_level 1
  compression_type :xz
end
