#!/bin/bash
# Name: Harden_ISKLM_checkWASUserRoles.sh
# Author: Carl Moore
# Modified 2016-06-13
# Description: Checks WebSphere users (except the designated admin) for access to administrative functions and outputs warnings if found to log
# Usage: /Harden_ISKLM_checkWASUserRoles.sh [environment properties file full path]
envprops=$1
source $envprops
logfile=$logs_location/Harden_ISKLM_checkWASUserRoles.log
#set expected defaults, unless otherwise specified
if [ -z "$was_home" ]; then was_home="/opt/IBM/WebSphere/AppServer"; fi
if [ -z "$was_admin" ]; then was_admin="wasadm"; fi
if [ -z "$was_password" ]; then was_password="Just4Now"; fi
if [ -z "$logfile" ]; then logfile="/var/log/hardening/Harden_ISKLM_checkWASUserRoles.log"; fi

mkdir -p $logs_location
exec > $logfile 2>&1
echo "Checking WAS user roles, executed on $(date)"
#Get groups

#groupslist=$($was_home/bin/wsadmin.sh -lang jython -user $was_admin -password $was_password -c "AdminTask.searchGroups ('[-cn *]')" | sed '1d' | tr -d \' )
#echo "Groups are:"
#printf $groupslist
#echo -e "\n\n"

## Get users

userlist=$($was_home/bin/wsadmin.sh -lang jython -user $was_admin -password $was_password -c "AdminTask.searchUsers ('[-uid *]')" | sed '1d' | tr -d \' )
echo "Users are:"
printf $userlist
echo -e "\n\n"

## Check role membership, warn if users are mapped to Administrative roles

userstring=$(echo -e $userlist | tr '\n' '@')
IFS='@'

for user in $userstring; do

# Don't check the Wasadmin user
if ! [[ "$user" == *"$was_admin"* ]]; then

echo "$user is authorised for the following roles"
roles=$($was_home/bin/wsadmin.sh -lang jython -user $was_admin -password $was_password -c "AdminTask.listResourcesForUserID('[-userid $user]')" | sed '1d' | tr -d \')
echo $roles

if echo $roles | grep -v "administrator=\[\]"
then
echo "WARNING user $user is mapped to the Administrator role, access to this user should be strictly limited and monitored"
fi

if echo $roles | grep -v "operator=\[\]" 
then
echo "WARNING user $user is mapped to the Operator role, access to this user should be strictly limited and monitored"
fi

if echo $roles | grep -v "adminsecuritymanager=\[\]"
then
echo "WARNING user $user is mapped to the Admin Security Manager role, access to this user should be strictly limited and monitored"
fi

if echo $roles | grep -q 'administrator=\[\]\|operator=\[\]\|adminsecuritymanager=\[\]'
then
echo "$user is not mapped to any administrator or operational roles"
fi 

else
echo "$user is the Websphere administrator, skipping"
fi

done

