#!/bin/bash
# Name: Harden_ISKLM_coordinator.sh
# Author: Carl Moore
# Modified 2016-06-14
# Description: Runs security hardening scripts for IBM security key lifecycle manager
# Usage: /Harden_ISKLM_coordinator.sh [environment properties file full path]
envprops=$1
source $envprops
logfile=$logs_location/Harden_ISKLM_coordinator.log
#set expected defaults, unless otherwise specified

if [ -z "$logs_location" ]; then logs_location="/var/log/hardening/"; fi
if [ -z "$logfile" ]; then logfile="$logs_location/Harden_ISKLM_coordinator.log"; fi
mkdir -p $logs_location
exec > $logfile 2>&1


if [ -z "$envprops" ]; then echo "Properties file is not specified, please specify by running Harden_ISKLM_coordinator.sh /path/to/properties/file.properties"; exit; fi
if [ ! -f "$envprops" ]; then echo "Specified properties file $envprops not found, please specify a valid properties file"; exit; fi

echo "Checking properties file integrity in file $envprops"

while IFS='' read -r line || [[ -n "$line" ]]
do
	prop=$(echo $line | cut -f1 -d\=)
	val=$(echo $line | cut -f2 -d\=)

	if [ $prop == "\#*" ]; then
	echo "Warning, $prop is commented out in $envprops. Please uncomment this value and set appropriately to continue"
	exit

	elif [ -z "$val" ]; then
	echo "The value of $prop found in $envprops is not set, please populate this value appropriately and re-run."
	exit

	else echo "Found property $prop, with value $val"
	fi
done < "$envprops"

echo "Checking system users passwords"
/bin/bash $scripts_home/Harden_passwd_verification.sh $envprops
## need to check log for errors here
echo "Password check completed"

echo "Checking SKLM server status"
/bin/bash $scripts_home/Harden_SKLM_server.sh $envprops 2
## need to check log for errors here
echo "SKLM server hardening completed"

echo "Checking Websphere User roles..."
/bin/bash $scripts_home/Harden_ISKLM_checkWASUserRoles.sh $envprops
if [ grep "WARNING" $logs_location/Harden_ISKLM_checkWASUserRoles.log ]; then
echo "Warnings found in $logs_location/Harden_ISKLM_checkWASUserRoles.log, please review the log file and check WAS user roles"
fi
echo "User roles check done"

echo "Hardening WebSphere security"
/bin/bash $scripts_home/Harden_WAS_security.sh $envprops
## need to check log for errors here
echo "WAS transport security completed"

echo "Hardening SKLM Properties"
/bin/bash $scripts_home/Harden_ISKLM_secureProps.sh
if [ grep "error" $logs_location/Harden_ISKLM_secureProps.log ]; then
echo "An error has occurred with hardening the SKLM properties, check the log file at $logs_location/Harden_ISKLM_secureProps.log and manually restore backed up properties file at $isklm_props_location "
fi
echo "Hardening SKLM Properties complete"

echo "Hardening WebSphere Security"
/bin/bash $scripts_home/Harden_WAS_protocols.sh $envprops
## need to check log for errors here
echo "WebSphere security hardening completed"

echo "Setting WebSphere logs retention"
## WAS Log script here
## Check log for errors here
echo "WebSphere logs retention has been set."

