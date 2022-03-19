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

if [[ ! -f ${HOME_PROP} ]];
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

is_appl_security_enabled=$(${WAS} "print AdminTask.isAppSecurityEnabled()" | /usr/bin/tail -1)
is_glob_security_enabled=$(${WAS} "print AdminTask.isGlobalSecurityEnabled()" | /usr/bin/tail -1 )

/bin/echo ''
/bin/echo 'Verifing Global and Application security setting is enabled or disabled'
/bin/echo ''

if [[ ${is_glob_security_enabled} == 'true' ]];
then
	/bin/echo "Global security is enabled"
fi

if [[ ${is_glob_security_enabled} == 'false' ]];
then
	/bin/echo "Global security is disabled"
	if [[ ${CHECK_ONLY} -eq 0 ]];
	then
		/bin/echo 'Enabling Global Security'
		${WAS} "AdminTask.setGlobalSecurity ('[-enabled true]')"
		/bin/echo 'Enabling Administrative Security'
		${WAS} "AdminTask.setAdminActiveSecuritySettings('-enforceJava2Security true')"
		${WAS} "AdminTask.setAdminActiveSecuritySettings('-dynUpdateSSLConfig true')"
		${WAS} "AdminTask.setAdminActiveSecuritySettings('-activeAuthMechanism LTPA')"	
		${WAS} "AdminTask.setAdminActiveSecuritySettings('-adminPreferredAuthMech RSAToken')"	
		${WAS} "AdminTask.setAdminActiveSecuritySettings('-useDomainQualifiedUserNames false')"	
		${WAS} "AdminTask.setAdminActiveSecuritySettings('-cacheTimeout 600')"	
		${WAS} "AdminTask.setAdminActiveSecuritySettings('-issuePermissionWarning true')"	
		${WAS} "AdminTask.setAdminActiveSecuritySettings('-appSecurityEnabled true')"	
		${WAS} "AdminTask.setAdminActiveSecuritySettings('-enforceFineGrainedJCASecurity false')"	
		${WAS} "AdminTask.setAdminActiveSecuritySettings('-activeUserRegistry WIMUserRegistry')"	
		${WAS} "AdminConfig.save()"	
	else
		/bin/echo "Global security: [${is_glob_security_enabled}]"
		/bin/echo 'Administrative Security Settings should be set to:'
		/bin/echo "enforceJava2Security true"
		/bin/echo "dynUpdateSSLConfig true"
		/bin/echo "activeAuthMechanism LTPA"	
		/bin/echo "adminPreferredAuthMech RSAToken"	
		/bin/echo "useDomainQualifiedUserNames false"	
		/bin/echo "cacheTimeout 600"	
		/bin/echo "issuePermissionWarning true"	
		/bin/echo "appSecurityEnabled true"	
		/bin/echo "enforceFineGrainedJCASecurity false"	
		/bin/echo "activeUserRegistry WIMUserRegistry"	
	fi
fi

if [[ ${is_appl_security_enabled} == 'true' ]];
then
	/bin/echo "Application security is enabled"
fi

if [[ ${is_appl_security_enabled} == 'false' ]];
then
	/bin/echo "Application security is disabled"
	if [[ ${CHECK_ONLY} -eq 0 ]];
	then
		/bin/echo 'Enabling Application Security'
		${WAS} "sec_conf_id = AdminConfig.getid('/Security:/'); AdminConfig.modify(sec_conf_id, [['appEnabled','true']])"
		${WAS} "AdminConfig.save()"	
		app_enabled=$(${WAS} "print AdminTask.isGlobalSecurityEnabled()")
		/bin/echo "Application security: [${app_enabled}]"
	else
		/bin/echo "Application security: [${is_appl_security_enabled}]"
		/bin/echo "Security Configuration ID: [$(${WAS} \"print AdminConfig.getid('/Security:/')\")"
	fi
fi

exit 0
