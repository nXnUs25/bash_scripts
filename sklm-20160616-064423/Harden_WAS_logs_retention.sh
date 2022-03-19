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

CHECK_ONLY=${2:-1}      ### 0 disabled - do all ; 1 enabled preform only checks

if [[ ! -f ${logs_location} ]];
then
	/usr/bin/mkdir -p ${logs_location:-"/var/log/hardening"}
fi
temp=${0##*/}
LOGFILE="${logs_location}/${temp%.*}.log"

/usr/bin/touch ${LOGFILE}
exec > >( /bin/sed "s/^/$(/bin/date '+[%F %T]'): /" | /usr/bin/tee -a ${LOGFILE}) 2>&1

regex='^-?[0-9]+([.][0-9]+)?$'
if ! [[ ${CHECK_ONLY} =~ ${regex} ]] ; then
        echo "error: Not a number: [${CHECK_ONLY}]"
        /bin/echo -e "Usage: ./harden_was_security [option]\n       ./harden_was_security 0"
        /bin/echo -e "0 - check mode disabled - do all [checks and changes]\n1 - checks enabled, preforming only checks"
        exit 1
fi

/bin/echo ''                                              
/bin/echo "Starting checks: "$(/bin/date "+%Y%m%d-%H%M%S")

if [[ ! -f "${was_home:-'/opt/IBM/WebSphere/AppServer'}/bin/wsadmin.sh" ]];
then
	/bin/echo "Looks like WebSphere Server Application it is not configured on that server, EXITING !!!"
	exit 0
fi

WAS_PROFILE_DIR="${was_profile}"

WAS_BIN="${WAS_PROFILE_DIR}/bin"
WAS_CMD="wsadmin.sh -lang jython -user ${USER} -password ${WAS_PWD} -c"
WAS="${WAS_BIN}/${WAS_CMD}"

if [[ ${CHECK_ONLY} -eq 0 ]];
then
        /bin/echo "Script will apply changes to meeet ITCS104 standards [changing the OS configuration]"
else
        /bin/echo "Script will run verification for settings only [no changes to the system]"
fi

/bin/echo "WAS: Checking server name"
sname=$(${WAS} "print AdminConfig.list('Server')" | /usr/bin/grep -v 'Connected to process' | /usr/bin/awk -F'(' '{print $1}')

/bin/echo "WAS: Server name: [${sname}]"
/bin/echo "WAS: Determine the configuration ID of the application server [${sname}]"

server_id=$(${WAS} "print AdminConfig.getid('/Server:${sname}/')" | /usr/bin/grep -v 'Connected to process')

/bin/echo "WAS: Identifying the output stream log for ID: [${server_id}]"

out_log=$(${WAS} "print AdminConfig.showAttribute('${server_id}', 'outputStreamRedirect')" | /usr/bin/grep -v 'Connected to process')
err_log=$(${WAS} "print AdminConfig.showAttribute('${server_id}', 'errorStreamRedirect')" | /usr/bin/grep -v 'Connected to process')

/bin/echo "WAS: Server Error  log: [${err_log}]"
/bin/echo "WAS: Server Output log: [${out_log}]"


/bin/echo "WAS: Current Logs configuration for server: [${sname}]"

err_log_conf=$(${WAS} "print AdminConfig.show('${err_log}')" | /usr/bin/grep -v 'Connected to process')
out_log_conf=$(${WAS} "print AdminConfig.show('${out_log}')" | /usr/bin/grep -v 'Connected to process')

/bin/echo ${err_log_conf} | /usr/bin/grep -iq 'TIME'
err_is_time=${?}

if [[ ${err_is_time} -eq 1 ]];
then
	if [[ ${CHECK_ONLY} -eq 0 ]];
	then
		/bin/echo "WAS: Changing rollover method for LOGS to TIME"
		${WAS} "AdminConfig.modify('${err_log}', '[[rolloverType TIME] [rolloverPeriod 24] [maxNumberOfBackupFiles 90]]')"
		${WAS} "AdminConfig.save()"
		/bin/echo "WAS: Server Error logs configuration:"
		err_log_conf=$(${WAS} "print AdminConfig.show('${err_log}')" | /usr/bin/grep -v 'Connected to process')
		/bin/echo "${err_log_conf}" | /usr/bin/sed -e 's/[][]//g' | awk '{printf "%-45s: %+s\n", $1, $2}'
		/bin/echo
	else
		/bin/echo "WAS: Server Error logs configuration:"
		/bin/echo "${err_log_conf}" | /usr/bin/sed -e 's/[][]//g' | awk '{printf "%-45s: %+s\n", $1, $2}'
		/bin/echo "WAS: It is recommended to set rollover method for LOGS to TIME"
		/bin/echo
	fi
else
	/bin/echo "WAS: Server Error logs configuration:"
	/bin/echo "${err_log_conf}" | /usr/bin/sed -e 's/[][]//g' | awk '{printf "%-45s: %+s\n", $1, $2}'
	/bin/echo
fi

/bin/echo ${out_log_conf} | /usr/bin/grep -iq 'TIME'
out_is_time=${?}

if [[ ${out_is_time} -eq 1 ]];
then
	if [[ ${CHECK_ONLY} -eq 0 ]];
	then
		/bin/echo "WAS: Changing rollover method for LOGS to TIME"
		${WAS} "AdminConfig.modify('${out_log}', '[[rolloverType TIME] [rolloverPeriod 24] [maxNumberOfBackupFiles 90]]')"
		${WAS} "AdminConfig.save()"
		/bin/echo "WAS: Server Output logs configuration:"
		out_log_conf=$(${WAS} "print AdminConfig.show('${out_log}')" | /usr/bin/grep -v 'Connected to process')
		/bin/echo "${out_log_conf}" | /usr/bin/sed -e 's/[][]//g' | awk '{printf "%-45s: %+s\n", $1, $2}'
	else
		/bin/echo "WAS: Server Output logs configuration:"
		/bin/echo "${out_log_conf}" | /usr/bin/sed -e 's/[][]//g' | awk '{printf "%-45s: %+s\n", $1, $2}'	
		/bin/echo "WAS: It is recommended to set rollover method for LOGS to TIME"
	fi
else
	/bin/echo
	/bin/echo "WAS: Server Output logs configuration:"
	/bin/echo "${out_log_conf}" | /usr/bin/sed -e 's/[][]//g' | awk '{printf "%-45s: %+s\n", $1, $2}'	
fi

/bin/echo 'Done'


