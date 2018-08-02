# README

##Get Started

### Run with Docker

1. Install Docker, and docker-compose 

In Bash:

2. `docker-compose build`
3. `docker-compose run web rake db:migrate`
4. `docker-compose up -d   #This deploys the server on http://localhost:3030 `

If #2 in the above only printed a couple lines, maybe 2/3 insert statements
then the db didnt build, you'll have to do the following to fix the named volume.

`docker run -itv vulcan_sqlite-data:/srv/dat busybox /bin/sh`
`docker container ls -a    # note the container id of the most recent` 
`docker cp db/* container_id_from_before:/var/www/vulcan/db/`




This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
