# Vulcan

## Description

Vulcan supports the creation and editing of InSpec profiles **add more here**

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
  2. `bundle install`
  3. `bundle exec rake db:create`
  4. `bundle exec rake db:migrate`
  5. `bundle exec rails server`

## Run with Docker

### Building Docker Containers

_These steps need to be performed the first time you build the docker containers,
and whenever you edit the code base._

  1. Install dependencies
  2. `docker-compose build`
  3. `docker-compose run web rake db:migrate`
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

### License
  * This project is dual-licensed under the terms of the Apache license 2.0 (apache-2.0)
  * This project is dual-licensed under the terms of the Creative Commons Attribution Share Alike 4.0 (cc-by-sa-4.0)
