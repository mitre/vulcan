# Vulcan

## Description

Vulcan is a tool to help streamline the process of creating STIGs and InSpec security compliance profiles. It models the STIG intent form and
the process of aligning security controls from SRG items into actual STIG security controls.  Vulcan also gives the option while aligning the security controls to insert inspec code and test across any type of system supported by InSpec.

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
  * Ruby 
  * `build-essentials`
  * Bundler
  * `libq-dev`
  * nodejs

### Run With Ruby

#### Setup Ruby

1. Install the version of Ruby specified in `.ruby-version`
2. Install postgres and rbenv
3. gem install foreman
4. rbenv install
5. bin/setup

#### Running with Ruby

Make sure you have run the setup steps at least once before following these steps!

1. ensure postgres is running
2. foreman start -f Procfile.dev
3. Navigate to `http://127.0.0.1:3000`

#### Stopping Vulcan

1. Stop Vulcan by doing `ctrl + c`
2. Stop the postgres server

### Run With Docker

Given that Vulcan requires at least a database service, we use Docker Compose.

#### Setup Docker Container (Clean Install)

1. Install Docker
2. Download vulcan by running `git clone https://github.com/mitre/vulcan.git`.
3. Navigate to the base folder where `docker-compose.yml` is located
4. Run the following commands in a terminal window from the vulcan source directory:
   1. `./setup-docker-secrets.sh`
   2. `docker-compose up -d`
   3. `docker-compose run --rm web rake db:create db:schema:load db:migrate`
   4. `docker-compose run --rm web rake db:create_admin`
5. Navigate to `http://127.0.0.1:3000`

#### Managing Docker Container

The following commands are useful for managing the data in your docker container:

- `docker-compose run --rm web rake db:reset` **This destroys and rebuilds the db**
- `docker-compose run --rm web rake db:migrate` **This updates the db**

#### Running Docker Container

Make sure you have run the setup steps at least once before following these steps!

1. Run the following command in a terminal window:
   - `docker-compose up -d`
2. Go to `127.0.0.1:3000` in a web browser

##### Updating Docker Container

A new version of the docker container can be retrieved by running:

```
docker-compose pull
docker-compose up -d
docker-compose run web rake db:migrate
```

This will fetch the latest version of the container, redeploy if a newer version exists, and then apply any database migrations if applicable. No data should be lost by this operation.

##### Stopping the Container

`docker-compose down` # From the source directory you started from

## Usage

A demo instance can be accessed at inspec-dev.mitre.org

## Configuration

See `docker-compose.yml` for all container configuration options.

