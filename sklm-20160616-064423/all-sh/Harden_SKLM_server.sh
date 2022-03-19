#!/bin/bash

## author: Augustyn Chmiel
## e-mail: augustyc@ie.ibm.com

HOME_PROP=${1:-"/root/isklm_hardening/isklm_script_properties.properties"}
if [[ ! -f ${HOME_PROP} ]];
then
	/bin/echo "ISKLM scripts property doesnt exist: ${HOME_PROP}"
	exit 1
fi
. ${HOME_PROP}

USER=${was_admin}
WAS_PWD=${was_password}

if [[ ! -f ${HOME_PROP} ]];
then
	/usr/bin/mkdir -p ${logs_location:-"/var/log/hardening"}
fi
temp=${0##*/}
LOGFILE="${logs_location}/${temp%.*}.log"

ACTION=${1:-2}      ### 0 - stop server; 1 - start server ; 2 - restart server ; 3 was status

/usr/bin/touch ${LOGFILE}
exec > >( /bin/sed "s/^/$(/bin/date '+[%F %T]'): /" | /usr/bin/tee -a ${LOGFILE}) 2>&1

/bin/echo ''                                              
/bin/echo "Starting: "$(/bin/date "+%Y%m%d-%H%M%S")

if [[ ! -f "${was_profile}/bin/serverStatus.sh" ]];
then
	/bin/echo "Looks like WebSphere Server Application it is not configured on that server, EXITING !!!"
	exit 0
fi

WAS_PROFILE_DIR="${was_profile}"

WAS_BIN="${WAS_PROFILE_DIR}/bin"
WAS_CMD="wsadmin.sh -lang jython -user ${USER} -password ${WAS_PWD} -c"
WAS="${WAS_BIN}/${WAS_CMD}"

/bin/echo ''
cmd_access="-user ${USER} -password ${WAS_PWD}"

regex='^-?[0-9]+([.][0-9]+)?$'
if ! [[ ${ACTION} =~ ${regex} ]] ; then
	echo "error: Not a number: [${ACTION}]"

	/bin/echo -e "Usage: ./harden_sklm_server [option]\n       ./harden_sklm_server 4"
	/bin/echo -e " 0 - stop server\n 1 - start server\n 2 - [default] restart server\n 3 - status server\n 4 - print basic conf"

	exit 1
fi

if [[ ${ACTION} -eq 0 ]];
then
        /bin/echo "Stopping - IBM SKLM ..."
	app_name=$(${WAS}/serverStatus.sh -all ${cmd_access} | /usr/bin/awk -F': ' '/Server name/ {print $3}')

	/bin/sleep 3
	
	## stop server
	for x in ${app_name}
	do
		${WAS}/stopServer.sh ${x} ${cmd_access} | /usr/bin/awk -F': ' '/Server .* stop completed./ {print $2}'
	done

elif [[ ${ACTION} -eq 1 ]];
then
	/bin/echo "Starting - IBM SKLM ..."
	app_name=$(${WAS}/serverStatus.sh -all ${cmd_access} | /usr/bin/awk -F': ' '/Server name/ {print $3}')

	/bin/sleep 3

	## start server
	for x in ${app_name}
	do
		${WAS}/startServer.sh ${x} | /usr/bin/awk -F': ' '/Server .* open for e-business; process id is [0-9]*/ {print $2}'
	done

elif [[ ${ACTION} -eq 2 ]];
then
        /bin/echo "Restarting - IBM SKLM ..."
	app_name=$(${WAS}/serverStatus.sh -all ${cmd_access} | /usr/bin/awk -F': ' '/Server name/ {print $3}')

	/bin/sleep 3
	
	## stop server
	for x in ${app_name}
	do
		${WAS}/stopServer.sh ${x} ${cmd_access} | /usr/bin/awk -F': ' '/Server .* stop completed./ {print $2}'
	done

	/bin/sleep 5
	/bin/echo ''

	## start server
	for x in ${app_name}
	do
		${WAS}/startServer.sh ${x} | /usr/bin/awk -F': ' '/Server .* open for e-business; process id is [0-9]*/ {print $2}'
	done

elif [[ ${ACTION} -eq 3 ]];
then
        /bin/echo "Application Status - IBM SKLM ..."
	${WAS}/serverStatus.sh -all ${cmd_access} | /usr/bin/awk -F': ' '/The Application Server/ {print $2}'
	/bin/sleep 1

elif [[ ${ACTION} -eq 4 ]];
then
	/bin/echo '[Basic Configuration Info]'
	/usr/bin/awk -F': ' '{ printf "%-45s: %+s\n", $1, $2 }' ${was_log}/AboutThisProfile.txt

else
	/bin/echo -e "Usage: ./harden_sklm_server [option]\n       ./harden_sklm_server 4"
	/bin/echo -e " 0 - stop server\n 1 - start server\n 2 - [default] restart server\n 3 - status server\n 4 - print basic conf"
fi

/bin/echo ''
WAS_LOG="${was_server_log}/SystemOut.log"

/usr/bin/tail ${WAS_LOG}

### uncomment below to see errors and warnings
# /bin/echo ''
# /bin/grep -E ' E | W ' ${WAS_LOG} | /usr/bin/uniq

/bin/echo ''
/bin/echo "Number of Errors: $(/bin/grep -c ' E ' ${WAS_LOG})" | /usr/bin/awk -F': ' '{ printf "%-30s: [%+6s]\n", $1, $2 }'
/bin/echo "Number of Warnings: $(/bin/grep -c ' W ' ${WAS_LOG})" | /usr/bin/awk -F': ' '{ printf "%-30s: [%+6s]\n", $1, $2 }'

/bin/echo "Done."
exit 0
