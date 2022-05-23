#!/bin/sh
# Author:       Moluss
# Website       https://github.com/Moluss
# Description:  APT updates Monitor using Zabbix via command `apt-get -s upgrade`
#

# Route for tmp file to store yum output
TEMP_ZBX_FILE=/tmp/zabbix_apt_check_output.tmp
echo -n "" > $TEMP_ZBX_FILE

# Check if ServerActive is available
ZBX_SERVERACTIVEITEM=$(egrep ^Server /etc/zabbix/zabbix_agentd.conf | cut -d = -f 2)
if [ -z "$ZBX_SERVERACTIVEITEM" ]; then
   echo "Agent is not running on active mode"
   exit -1
fi

# Get hostname
ZBX_HOSTNAMEITEM_PRESENT=$(egrep ^HostnameItem /etc/zabbix/zabbix_agentd.conf -c)
if [ "$ZBX_HOSTNAMEITEM_PRESENT" -ge "1" ]; then
        ZBX_HOSTNAME=$(hostname)
else
        ZBX_HOSTNAME=$(egrep ^Hostname /etc/zabbix/zabbix_agentd.conf | cut -d = -f 2)
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
zabbix_sender -z $ZBX_SERVERACTIVEITEM -i $TEMP_ZBX_FILE