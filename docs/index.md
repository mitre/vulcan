# Vulcan

## Vulcan Setup

Vulcan can be set up in a few different ways. It can be done by having a vulcan.yml file that has settings for many different configurations. If there is no vulcan.yml file then the configurations will be read in from vulcan.default.yml that has default configuration as well as the ability for the configurations to be set by environment variables.

### Vulcan Default

* welcome_text: 
* contact_email: Is the default email for ApplicationMailer to use.
* smtp: Sets up the smtp mailing server
* local_login: Enables user to log in as well as turn email confirmation on and off
* ldap: 
* providers:
