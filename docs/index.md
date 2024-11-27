# Vulcan Installation

Vulcan can be set up in a few different ways. It can be done by having a vulcan.yml file that has settings for many different configurations. If there is no vulcan.yml file then the configurations will be read in from vulcan.default.yml that has default configuration as well as the ability for the configurations to be set by environment variables.

[**Installation**](index.md) | [**Configuration**](config.md)

## Index
* [Dependencies](#dependencies)
* [Run with Docker](#run-with-docker)
* [Tasks](#tasks)
* [Environment Variables](#environment-variables)

## Installation

### Dependencies

For Docker:
  * Docker
  * docker-compose

### Run With Docker

Given that Vulcan requires at least a database service, we use Docker Compose.

#### Setup Docker Container (Clean Install)

1. Install Docker
2. Download vulcan by running `git clone https://github.com/mitre/vulcan.git`.
3. Navigate to the base folder where `docker-compose.yml` is located
4. Run the following commands in a terminal window from the vulcan source directory:
   1. `./setup-docker-secrets.sh`
      ([environment variables](#environment-variables) should be set beforehand)
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

#### Updating Docker Container

A new version of the docker container can be retrieved by running:

```
docker-compose pull
docker-compose up -d
docker-compose run web rake db:migrate
```

This will fetch the latest version of the container, redeploy if a newer version exists, and then apply any database migrations if applicable. No data should be lost by this operation.

#### Stopping the Container

`docker-compose down` # From the source directory you started from.

## Tasks

### STIG/SRG Puller Task

This application includes a rake task that pulls published Security Requirements Guides (SRGs) and Security Technical Implementation Guides (STIGs) from public.cyber.mil and saves them locally. This task can be executed manually or set up to run on a schedule in a production environment.

#### Manual Execution

You can manually execute the STIG/SRG puller task by running the following command in your terminal:

```shell
bundle exec rails stig_and_srg_puller:pull
```

#### Scheduling the Task in Production

If you wish to automate the execution of this task in a production environment, you can set up a task scheduler on your hosting platform.
The configuration will depend on your specific hosting service.

Generally, you will need to create a job that runs the following command:

```shell
bundle exec rails stig_and_srg_puller:pull
```

You can set the frequency of this task according to your preference or needs. However, it's important to consider the volume of data being pulled
and the impact on the application's performance when deciding on the frequency.

Please refer to your hosting platform's documentation or support services for specific instructions on how to set up scheduled tasks or cron jobs.

## Environment Variables

