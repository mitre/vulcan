# Vulcan

## Description

Vulcan is a tool to help streamline the process of creating STIGs and InSpec security compliance profiles. It models the STIG intent form and
the process of aligning security controls from SRG items into actual STIG security controls.  Vulcan also gives the option while aligning the security controls to
insert inspec code and test across any type of system supported by InSpec.

## Versioning and State of Development
This project uses the [Semantic Versioning Policy](https://semver.org/).

### Branches
The master branch contains the latest version of the software leading up to a new release.

Other branches contain feature-specific updates.

### Tags
Tags indicate official releases of the project.

Please note 0.x releases are works in progress (WIP) and may change at any time.

## Features

* Model the STIG creation process between the creator(vendor) and the approver(sponsor)
* Write and test InSpec code on a local system, or across SSH, AWS, and Docker
* Easily view the progress on what the status is of each control
* Communicate through the application to make the best decisions on controls
* Confidential data in the database is encrypted using symmetric encryption
* Authenticate via the local server, through github, and through configuring an LDAP server.

## Installation

### Dependencies

For Docker:
  * Docker
  * docker-compose

For Ruby (on Ubuntu):
  * Ruby 2.4.4
  * `build-essentials`
  * Bundler
  * `libq-dev`
  * nodejs

## Run with Ruby

  1. Install dependencies
  1. `bundle install`
  1. `bundle exec rake db:create db:schema:load db:migrate db:seed`
  1. `bundle exec rails server`
  1. Navigate to `localhost:3030`

## Run with Docker

### Building Docker Containers

_These steps need to be performed the first time you build the docker containers.
You will need to run `docker-compose run web rake db:migrate` anytime changes are made
to the database._

  1. Install dependencies
  2. `docker-compose build`
  3. `docker-compose run web rake db:create db:schema:load db:migrate db:seed`
  4. Generate keys

### Running Docker Containers

  1. `docker-compose up`
  2. Navigate to `localhost:3030`

### Container Troubleshooting

If migrating the db doesn't work (#2 in _Building Docker Containers_), then run:
  * `docker run -itv vulcan_sqlite-data:/srv/dat busybox /bin/sh`
  * `docker container ls -a    # Note the most recent container ID`
  * `docker cp db/* container_id:/var/www/vulcan/db/`

### Stopping the Containers

`docker-compose down`

## Usage

A demo instance can be accessed at inspec-dev.mitre.org

## Configuration

See `docker-compose.yml` for all container configuration options.

##### Host Container on Relative URL

Edit RAILS\_RELATIVE\_URL\_ROOT in `docker-compose.yml`

##### Host Container in Development/Production Mode

Edit RAILS\_ENV in `docker-compose.yml`

## Licensing and Authors

### Authors
- Matthew Dromazos
- Rob Thew
- Aaron Lippold

### NOTICE

© 2018 The MITRE Corporation.

Approved for Public Release; Distribution Unlimited. Case Number 18-3678.

### NOTICE
MITRE hereby grants express written permission to use, reproduce, distribute, modify, and otherwise leverage this software to the extent permitted by the licensed terms provided in the LICENSE.md file included with this project.

### NOTICE

This software was produced for the U. S. Government under Contract Number HHSM-500-2012-00008I, and is subject to Federal Acquisition Regulation Clause 52.227-14, Rights in Data-General.

No other use other than that granted to the U. S. Government, or to those acting on behalf of the U. S. Government under that Clause is authorized without the express written permission of The MITRE Corporation.

For further information, please contact The MITRE Corporation, Contracts Management Office, 7515 Colshire Drive, McLean, VA  22102-7539, (703) 983-6000.
