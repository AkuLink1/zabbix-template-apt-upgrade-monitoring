#!/bin/sh
# Author:       AkuLink1
# Website       https://github.com/AkuLink1
# Description:  APT updates Monitor using Zabbix via command `apt-get -s upgrade`
# 2023-05-31 updated to support Zabbix server ports

# Server configuration file route
AGENTD_CONF_FILE=/etc/zabbix/zabbix_agentd.conf
USE_ENCRYPTION=0

# Route for tmp file to store yum output
TEMP_ZBX_FILE=/tmp/zabbix_apt_check_output.tmp
echo -n "" > $TEMP_ZBX_FILE

if [ ! -f "$AGENTD_CONF_FILE" ]; then
  echo "Error: File '$AGENTD_CONF_FILE' does not exist."
  exit 1
fi
# Check if Server IP/name is set in configuration file
ZBX_SERVERACTIVEITEM=$(egrep ^ServerActive $AGENTD_CONF_FILE | cut -d = -f 2)

# Check if ServerActive is available
if [ -z "$ZBX_SERVERACTIVEITEM" ]; then
   echo "Agent is not running on active mode"
   exit 1
fi

# Extract the hostname and port using pattern matching
line=$(grep "^ServerActive=" $AGENTD_CONF_FILE)
if echo "$line" | grep -Eq "ServerActive=([a-zA-Z0-9.-]+)(:([0-9]+))?$"; then

  # Store the hostname
  ZBX_SERVERACTIVEITEM=$(echo "$line" | sed -E 's/ServerActive=([a-zA-Z0-9.-]+)(:([0-9]+))?/\1/')

  # Store the port
  ZBX_SERVERACTIVEITEM_PORT=$(echo "$line" | sed -E 's/ServerActive=([a-zA-Z0-9.-]+)(:([0-9]+))?/\3/')
  if [ -z "$ZBX_SERVERACTIVEITEM_PORT" ]; then
    ZBX_SERVERACTIVEITEM_PORT="10051"
  fi

else
  echo "Error: Unable to find the ServerActive line"
  exit -1
fi

# Get hostname
ZBX_HOSTNAMEITEM_PRESENT=$(egrep ^HostnameItem $AGENTD_CONF_FILE -c)
if [ "$ZBX_HOSTNAMEITEM_PRESENT" -ge "1" ]; then
        ZBX_HOSTNAME=$(hostname)
else
        ZBX_HOSTNAME=$(egrep ^Hostname $AGENTD_CONF_FILE | cut -d = -f 2)
fi


# Read the PSK identity and file from zabbix_agentd.conf
if [ "$USE_ENCRYPTION" -ge "1" ]; then
	psk_identity=$(sed -n 's/^TLSPSKIdentity[[:space:]]*=[[:space:]]*//p' $AGENTD_CONF_FILE | tr -d ' ')
	psk_file=$(sed -n 's/^TLSPSKFile[[:space:]]*=[[:space:]]*//p' $AGENTD_CONF_FILE | tr -d ' ')
	tls_connect=$(sed -n 's/^TLSConnect[[:space:]]*=[[:space:]]*//p' $AGENTD_CONF_FILE | tr -d ' ')
	
	if [[ -n $psk_identity ]]; then
	        psk_identity="--tls-psk-identity $psk_identity"
	fi
	
	if [[ -n $psk_file ]]; then
	        psk_file="--tls-psk-file $psk_file"
	fi
	
	if [[ -n $tls_connect ]]; then
	        tls_connect="--tls-connect $tls_connect"
	fi
fi



#######
# APT Update + Upgrade info
#######
UPDATE_PACKAGES=$(apt-get update)
APT_UPGRADE_SIMULATION=$(apt-get -s upgrade)

# Kept Back Packages: An already installed package now needs to install more new package as dependency. When you manually and individually update these packages, you see what new packages are going to be installed and the error is not shown anymore.
PACKAGES_KEPT_BACK_COUNT=$(echo $APT_UPGRADE_SIMULATION | grep -o "[[:digit:]]\+ not upgraded" | grep -o "[[:digit:]]\+")
PACKAGES_KEPT_BACK_DESCRIPTION=$(echo $APT_UPGRADE_SIMULATION | grep -A1 "packages have been kept back:" || echo "No packages were kept back")

# Ready to Upgrade Packages: Packages will be installed
PACKAGES_READY_TO_UPDATE_COUNT=$(echo $APT_UPGRADE_SIMULATION | grep -o "[[:digit:]]\+ upgraded" | grep -o "[[:digit:]]\+")
PACKAGES_READY_TO_UPDATE_DESCRIPTION=$(echo $APT_UPGRADE_SIMULATION | grep -A1 "will be upgraded:" || echo "No packages to upgrade")

# Newly installed
PACKAGES_NEWLY_INSTALLED_COUNT=$(echo $APT_UPGRADE_SIMULATION | grep -o "[[:digit:]]\+ newly installed" | grep -o "[[:digit:]]\+")
PACKAGES_NEWLY_INSTALLED_DESCRIPTION=$(echo $APT_UPGRADE_SIMULATION | grep -A1 "NEW packages will be installed" || echo "No new packages to install")

# To remove
PACKAGES_TO_REMOVE_COUNT=$(echo $APT_UPGRADE_SIMULATION | grep -o "[[:digit:]]\+ to remove" | grep -o "[[:digit:]]\+")
PACKAGES_TO_REMOVE_DESCRIPTION=$(echo $APT_UPGRADE_SIMULATION | grep -A1 "are no longer required" || echo "No packages to remove")

# Total count summed up
TOTAL_PACKAGES_COUNT=`expr $PACKAGES_KEPT_BACK_COUNT + $PACKAGES_READY_TO_UPDATE_COUNT + $PACKAGES_NEWLY_INSTALLED_COUNT + $PACKAGES_TO_REMOVE_COUNT`
# APT Upgrade Summary
APT_UPGRADE_SUMMARY=$(echo "$APT_UPGRADE_SIMULATION" | grep "[[:digit:]]\+ upgraded")

########
# Add to tmp file and send to Zabbix Server
########
# Apt Upgrade Full Summary
echo -n "\"$ZBX_HOSTNAME\" apt.packagesupgradesummary.count $TOTAL_PACKAGES_COUNT\n" >> $TEMP_ZBX_FILE
echo -n "\"$ZBX_HOSTNAME\" apt.packagesupgradesummary.description $APT_UPGRADE_SUMMARY\n" >> $TEMP_ZBX_FILE

# Kept Back Packages
echo -n "\"$ZBX_HOSTNAME\" apt.keptbackupdates.description $PACKAGES_KEPT_BACK_DESCRIPTION\n" >> $TEMP_ZBX_FILE

# Kept Back Packages
echo -n "\"$ZBX_HOSTNAME\" apt.newlyinstalled.description $PACKAGES_NEWLY_INSTALLED_DESCRIPTION\n" >> $TEMP_ZBX_FILE

# Ready to Upgrade Packages
echo -n "\"$ZBX_HOSTNAME\" apt.readytoupgrade.description $PACKAGES_READY_TO_UPDATE_DESCRIPTION\n" >> $TEMP_ZBX_FILE

# Ready to Upgrade Packages
echo -n "\"$ZBX_HOSTNAME\" apt.toremove.description $PACKAGES_TO_REMOVE_DESCRIPTION\n" >> $TEMP_ZBX_FILE

# OS Release Number


zabbix_sender -z $ZBX_SERVERACTIVEITEM -p $ZBX_SERVERACTIVEITEM_PORT $psk_identity $psk_file $tls_connect -i $TEMP_ZBX_FILE -vv

