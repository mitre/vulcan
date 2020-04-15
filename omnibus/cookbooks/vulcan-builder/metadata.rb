name             'vulcan-builder'
maintainer       'Robert Clark'
maintainer_email 'rbclark@mitre.org'
license          'Apache-2.0'
description      'Builds a Vulcan omnibus package for development/testing'
version          '1.0.0'

depends          'yum-epel'
depends          'omnibus'
depends          'mingw'

chef_version     '>= 13.0'
