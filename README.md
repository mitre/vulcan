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

## Deploy Vulcan
[Configuration](docs/config.md)

## Deployment Dependencies:
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


## Enable SMTP:
### SMTP Setup:
To enable SMTP you will need to add your configuration file to `config/vulcan.yml` or pass in the specifications as environment variables. When SMTP is set up you should enable `local_login: email_confirmation` so users must confirm their email to continue.

## Enable Local login:
### Local Login Setup:
Allows for users to to register and login not using external services.

## Enable LDAP:
### LDAP Setup:
To enable LDAP you will need to add your configuration file to `config/vulcan.yml` or pass in the specifications as environment variables.

## Enable Providers
### Providers Setup

## Usage

A demo instance can be accessed at inspec-dev.mitre.org

## Configuration

See `docker-compose.yml` for all container configuration options.
