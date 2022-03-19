#!/bin/bash
# Name: Harden_ISKLM_checkWASUserRoles.sh
# Description: Checks WebSphere users (except the designated admin) for access to administrative functions and outputs warnings if found to log
# Usage: [wasadmin=FOO waspass=BAR logfile=FOO] /Harden_ISKLM_checkWASUserRoles.sh

cd /opt/IBM/WebSphere/AppServer/bin

#set expected defaults, unless otherwise specified
if [ -z "$wasadmin"]; then wasadmin="wasadm"; fi
if [ -z "$waspass"]; then waspass="Just4Now"; fi
if [ -z "$logfile"]; then logfile="/var/log/Harden_ISKLM_checkWASUserRoles.log"; fi

exec > $logfile 2>&1
echo "Checking WAS user roles, executed on $(date)"
#Get groups

#groupslist=$(./wsadmin.sh -lang jython -user $wasadmin -password $waspass -c "AdminTask.searchGroups ('[-cn *]')" | sed '1d' | tr -d \' )
#echo "Groups are:"
#printf $groupslist
#echo -e "\n\n"

## Get users

userlist=$(./wsadmin.sh -lang jython -user $wasadmin -password $waspass -c "AdminTask.searchUsers ('[-uid *]')" | sed '1d' | tr -d \' )
echo "Users are:"
printf $userlist
echo -e "\n\n"

## Check role membership, warn if users are mapped to Administrative roles

userstring=$(echo -e $userlist | tr '\n' '@')
IFS='@'

for user in $userstring; do

# Don't check the Wasadmin user
if ! [[ "$user" == *"$wasadmin"* ]]; then

echo "$user is authorised for the following roles"
roles=$(./wsadmin.sh -lang jython -user $wasadmin -password $waspass -c "AdminTask.listResourcesForUserID('[-userid $user]')" | sed '1d' | tr -d \')
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

