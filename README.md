# Zabbix Template to monitor available package upgrades in hosts
Zabbix template that monitors hosts for available package upgrades in Debian / Ubuntu / "apt" package manager distros. 

The script runs `apt-get update` to update source lists and then runs `apt-get upgrade -s` in simulation mode (no upgrade is executed). Data is then send to Zabbix server in various formats. A problem will be shown in the dashboard in case there is > 1 packages to update. 

## Overview
Zabbix Server version: 6.0

Sample output of `apt-get upgrade -s` from which we extract the info for the template:

    The following packages have been kept back:
      zabbix-frontend-php
    The following packages will be upgraded:
      zabbix-agent zabbix-apache-conf zabbix-server-mysql zabbix-sql-scripts
    4 upgraded, 0 newly installed, 0 to remove and 1 not upgraded.

# Versions 
This template was tested on:

- Zabbix Server 6.0 (LTS)
- Zabbix Agent (daemon) 5.0.21
- Debian 11

# Setup

## On Zabbix frontend server:
- Download and import either `server_template_check_apt_updates_templates.xml`, `server_template_check_apt_updates_templates.json` or `server_template_check_apt_updates_templates.yml` to Zabbix frontend.

- Assign the Template Debian APT Updates to the host(s) you want to monitor

## On all hosts you want to monitor:
- Install packages zabbix-agent and zabbix-sender:

     `apt-get install zabbix-agent zabbix-sender`

- Copy content or download `apt_upgrade_agent_script.sh` script and move into host folder (Example): /etc/zabbix/custom_scripts

	 `sudo wget https://raw.githubusercontent.com/AkuLink1/zabbix-template-apt-upgrade-monitoring/main/agent_scripts/apt_upgrade_agent_script.sh` 
 
- Grant exec permissions 

     `sudo chmod +x /etc/zabbix/custom_scripts/apt_upgrade_agent_script.sh`

- Add entry to crontab (`sudo crontab -e`) to execute the script periodically to check for updates and then check for possible upgrades and send data to Zabbix Server. This cron will run every 12 hours:

     `0 */12 * * * sh /etc/zabbix/custom_scripts/apt_upgrade_agent_script.sh 
