#!/bin/bash

#############################################################################################
# Script to change WAS Liberty log retention period to 270 days                             #
# Gareth Burke 14/6/16                                                                      #
# Uses and enables binary logging by adding line to bootstrap.properties file if it         #
# doesnt already co-exist with server.xml file. Then the program removes the end of the     #
# server.xml file and replaces the content with some XML content to change the log retention#
# to 270 days.                                                                              #
#                                                                                           #
# Usage: ./Harden_WAS_Liberty_LogRetention.sh [environment properties file full path]       #
#############################################################################################

if [ -z "$1" ]
then
	echo "Usage: ./`basename $0` [environment properties file full path]"
	echo "Exiting"
	exit -1 
fi
#run program with argument of properties file

envprops=$1
source $envprops
logfile=$logs_location/Harden_Liberty_ExtendRetention.log
mkdir -p $logs_location

exec > $logfile 2>&1
echo "Extending WAS Liberty log retention to 270 days, executed on $(date)"

if [ -z "$WAS_ENV_VAR" ]; then WAS_ENV_VAR="/opt/WebSphereLibertyProfile_v8558/wlp/templates/servers/defaultServer"; fi
cd $WAS_ENV_VAR

if [[ $? -ne 0 ]] ;
then
        echo "cd to required directory $WAS_ENV_VAR failed. Exiting!"
        exit -1
fi

cp server.xml server.xml.backupversion
touch bootstrap.properties
echo "websphere.log.provider = binaryLogging-1.0" >> bootstrap.properties
#To enable binary logging, edit the bootstrap.properties file by adding line
#Need to add this file in the same folder as server.xml if it doesnt exist

sed -e s/"<""\/"server">"//g server.xml > serverbkp.xml

if [[ $? -ne 0 ]] ;
then
	echo "sed operation failed. Exiting!"
	exit -1
fi
# replace </server> at end of server.xml file, send to serverbkp.xml
echo "" >> serverbkp.xml
echo "<logging>" >> serverbkp.xml
# add logging line to serverbkp.xml
echo  -e '\t' "<binaryLog purgeMinTime="6480"/>" >> serverbkp.xml
# 6480 is 270 * 24 (hours in 270 days)
echo "</logging>" >> serverbkp.xml
# add line to serverbkp.xml
echo "" >> serverbkp.xml
echo "</server>" >> serverbkp.xml

mv serverbkp.xml server.xml
#replace the server.xml with serverbkp.xml edited file

#dont forget to comment this back in

server stop
server start

#stop WAS Liberty application
#start WAS Liberty application

#The WAS stop and start after changing server.xml is VERY IMPORTANT
