#!/bin/bash

## author: Augustyn Chmiel
## e-mail: augustyc@ie.ibm.com

USER='wasadm'
WAS_PWD='Just4Now'

CHECK_ONLY=${1:-1}      ### 0 disabled - do all ; 1 enabled preform only checks

LOGFILE='/var/log/harden_was_protocals.log'

/usr/bin/touch ${LOGFILE}
exec > >( /bin/sed "s/^/$(/bin/date '+[%F %T]'): /" | /usr/bin/tee -a ${LOGFILE}) 2>&1

regex='^-?[0-9]+([.][0-9]+)?$'
if ! [[ ${CHECK_ONLY} =~ ${regex} ]] ; then
        echo "error: Not a number: [${CHECK_ONLY}]"
        /bin/echo -e "Usage: ./harden_was_protocals [option]\n       ./harden_was_protocals 0"
        /bin/echo -e "0 - check mode disabled - do all [checks and changes]\n1 - checks enabled, preforming only checks"
        exit 1
fi

/bin/echo ''                                              
/bin/echo "Starting checks: "$(/bin/date "+%Y%m%d-%H%M%S")

if [[ ! -f '/opt/IBM/WebSphere/AppServer/bin/wsadmin.sh' ]];
then
	/bin/echo "Looks like WebSphere Server Application it is not configured on that server, EXITING !!!"
	exit 0
fi

if [[ -f '/usr/local/bin/harden_sklm_server' ]];
then
	SKLM_RESTART='/usr/local/bin/harden_sklm_server'
fi

WAS_PROFILE_DIR='/opt/IBM/WebSphere/AppServer/profiles/KLMProfile'

WAS_BIN="${WAS_PROFILE_DIR}/bin"
WAS_CMD="wsadmin.sh -lang jython -user ${USER} -password ${WAS_PWD} -c"
WAS="${WAS_BIN}/${WAS_CMD}"

WAS_PROP_DIR="${WAS_PROFILE_DIR}/properties"
WAS_PROP_FILE1='ssl.client.props'
SSL_CLI_PROPS="${WAS_PROP_DIR}/${WAS_PROP_FILE1}"

WAS_PROP_FILE2='wsadmin.properties'
WAS_PROP="${WAS_PROP_DIR}/${WAS_PROP_FILE2}"

if [[ ${CHECK_ONLY} -eq 0 ]];
then
        /bin/echo "Script will apply changes to meeet ITCS104 standards [changing the OS configuration]"
else
        /bin/echo "Script will run verification for settings only [no changes to the system]"
fi

/bin/echo ''
/bin/echo 'Checking IPv4 and IPv6 java custom properties'
/bin/echo ''

ip4=$(${WAS} "print AdminTask.showJVMSystemProperties('-propertyName java.net.preferIPv4Stack')" | /usr/bin/tail -1)
ip6=$(${WAS} "print AdminTask.showJVMSystemProperties('-propertyName java.net.preferIPv6Addresses')" | /usr/bin/tail -1)

if [[ ${ip4} == 'true' ]];
then
	/bin/echo "JVM property to force WebSphere Application Server to use an IPv4 socket to communicate is set."
	/bin/echo "[java.net.preferIPv4Stack = true] for using IPv4"
else
	/bin/echo "[java.net.preferIPv4Stack] for using IPv4 not set"
	if [[ ${CHECK_ONLY} -eq 0 ]];
	then
		/bin/echo 'Setting IPv4 JVM property'
		${WAS} "AdminTask.setJVMSystemProperties('[-propertyName java.net.preferIPv4Stack -propertyValue true]')"
		${WAS} "AdminConfig.save()"	
	else
		/bin/echo "To force IPv4 [java.net.preferIPv4Stack = true] should be set"
	fi
fi

if [[ ${ip6} == 'true' ]];
then
	/bin/echo "JVM property to force WebSphere Application Server to use an IPv6 socket to communicate is set."
	/bin/echo "[java.net.preferIPv6Addresses = true] for using IPv6"
else
	/bin/echo "[java.net.preferIPv6Addresses] for using IPv6 not set"
	if [[ ${CHECK_ONLY} -eq 0 ]];
	then
		/bin/echo "Setting IPv6 JVM property"
		${WAS} "AdminTask.setJVMSystemProperties('[-propertyName java.net.preferIPv6Addresses -propertyValue true]')"
		${WAS} "AdminConfig.save()"	
	else
		/bin/echo "To force IPv6 [java.net.preferIPv6Addresses = true] should be set"
	fi
fi

/bin/echo ''
/bin/echo 'SSL: configuring SSL protocal to use TSLv1.2'
/bin/echo ''

alias_scope=$(${WAS} "print AdminTask.listSSLConfigs('-all')" | /usr/bin/awk 'NR >= 2 {print "-"substr($1,1,length($1)-1)" "$2" -scopeName "$4}')
ssl_conf=$(${WAS} "print AdminTask.getSSLConfig('[${alias_scope}]')" | /bin/grep -oE 'securityLevel [a-Z]*|clientAuthentication [a-Z]*|sslProtocol [a-Z0-9_.]*|clientAuthenticationSupported [a-Z]*' | /usr/bin/tr '\n' ',' | /usr/bin/awk -F, '{print "-"$1" -"$2" -"$3" -"$4}' )

read _client_auth client_auth _lvl_sec lvl_sec _client_auth_support client_auth_support _ssl_prot ssl_prot <<<$(/bin/echo ${ssl_conf})

/bin/echo ''
/bin/echo 'SSL: checking security level for cipher group'
if [[ ${lvl_sec} == 'HIGH' ]];
then
	/bin/echo "SSL: [${_lvl_sec}] property is set to [${lvl_sec}] for the cipher group"
else
	/bin/echo "SSL: [${_lvl_sec}] property is set to [${lvl_sec}] for the cipher group"
	if [[ ${CHECK_ONLY} -eq 0 ]];
	then
		/bin/echo "SSL: Reconfiguring [${_lvl_sec}] property from [${lvl_sec}] to [HIGH]"
		${WAS} "AdminTask.modifySSLConfig('[${alias_scope} ${_lvl_sec} HIGH]')" 		
		${WAS} "AdminConfig.save()"	
		/bin/echo "SSL: Configured Cliphers for [${_lvl_sec}: HIGH] policy are:"
		/bin/echo ''
		${WAS} "AdminTask.listSSLCiphers('[${_lvl_sec} HIGH]')" | /usr/bin/tail -1 | echo -e "$(/usr/bin/sed s/\'//g )"
		
	else
		/bin/echo "SSL: Configured Cliphers for [${_lvl_sec}: ${lvl_sec}] policy are:"
		/bin/echo ''
		${WAS} "AdminTask.listSSLCiphers('[${_lvl_sec} ${lvl_sec}]')" | /usr/bin/tail -1 | echo -e "$(/usr/bin/sed s/\'//g )"
		/bin/echo ''
		/bin/echo "SSL: It is recommended to use best key exchange algorithm and strongest encryption." 
		/bin/echo "SSL: The most secure ciphers supported in WAS are with security level policy set to HIGH" 
	fi
fi

/bin/echo ''
/bin/echo 'SSL: checking client authentication request is enabled'
if [[ ${client_auth} == 'true' ]];
then
        /bin/echo "SSL: [Request Enabled] - [${_client_auth}] property is set to [${client_auth}]"
else
        /bin/echo "SSL: [Request Disabled] - [${_client_auth}] property is set to [${client_auth}]"
        if [[ ${CHECK_ONLY} -eq 0 ]];
        then
                /bin/echo "SSL: Reconfiguring [${_client_auth}] property from [${client_auth}] to [true]"
                ${WAS} "AdminTask.modifySSLConfig('[${alias_scope} ${_client_auth} true]')"
                ${WAS} "AdminConfig.save()"
        else
                /bin/echo "SSL: It is recommended to configure the request client authentication"
                /bin/echo "SSL: By setting the value of this parameter [${_client_auth}] to [true]"
        fi
fi

/bin/echo ''
/bin/echo 'SSL: checking client authentication support is enabled'
if [[ ${client_auth_support} == 'true' ]];
then
        /bin/echo "SSL: [Support Enabled] - [${_client_auth_support}] property is set to [${client_auth_support}]"
else
        /bin/echo "SSL: [Support Disabled] - [${_client_auth_support}] property is set to [${client_auth_support}]"
        if [[ ${CHECK_ONLY} -eq 0 ]];
        then
                /bin/echo "SSL: Reconfiguring [${_client_auth_support}] property from [${client_auth_support}] to [true]"
                ${WAS} "AdminTask.modifySSLConfig('[${alias_scope} ${_client_auth_support} true]')"
                ${WAS} "AdminConfig.save()"
        else
                /bin/echo "SSL: It is recommended to configure the support client authentication"
                /bin/echo "SSL: By setting the value of this parameter [${_client_auth_support}] to [true]"
        fi
fi

/bin/echo ''
/bin/echo 'SSL: checking the protocol type for the SSL handshake'
if [[ ${ssl_prot} == 'TLSv1.2' ]];
then
	/bin/echo "SSL: [${_ssl_prot}] property is set to [${ssl_prot}]"
else
	/bin/echo "SSL: [${_ssl_prot}] property is set to [${ssl_prot}]"
	if [[ ${CHECK_ONLY} -eq 0 ]];
	then
		/bin/echo "SSL: Reconfiguring [${_ssl_prot}] property from [${ssl_prot}] to [TLSv1.2]"

		ssl_client_val1='com.ibm.security.useFIPS=true'
		ssl_client_val2='com.ibm.websphere.security.FIPSLevel=SP800-131'
		ssl_client_val3='com.ibm.ssl.protocol=TLSv1.2'
		
		/bin/cp -av ${SSL_CLI_PROPS} ${SSL_CLI_PROPS}_$(/bin/date "+%Y%m%d-%H%M%S")~
		
		/bin/sed -i "s/^com.ibm.security.useFIPS=.*/${ssl_client_val1}/g" ${SSL_CLI_PROPS}		
		/usr/bin/grep -q "${ssl_client_val1}" ${SSL_CLI_PROPS} || /bin/echo "${ssl_client_val1}" >> ${SSL_CLI_PROPS}		

		/bin/sed -i "s/^com.ibm.websphere.security.FIPSLevel=.*/${ssl_client_val2}/g" ${SSL_CLI_PROPS}		
		/usr/bin/grep -q "${ssl_client_val2}" ${SSL_CLI_PROPS} || /bin/echo "${ssl_client_val2}" >> ${SSL_CLI_PROPS}		

		/bin/sed -i "s/^com.ibm.ssl.protocol=.*/${ssl_client_val3}/g" ${SSL_CLI_PROPS}		
		/usr/bin/grep -q "${ssl_client_val3}" ${SSL_CLI_PROPS} || /bin/echo "${ssl_client_val3}" >> ${SSL_CLI_PROPS}		

		${WAS} "AdminTask.setJVMSystemProperties('[-propertyName com.ibm.team.repository.transport.client.protocol -propertyValue TLSv1.2]')"
		${WAS} "AdminTask.setJVMSystemProperties('[-propertyName com.ibm.jsse2.sp800-131 -propertyValue strict]')"
		${WAS} "AdminTask.setJVMSystemProperties('[-propertyName com.ibm.rational.rpe.tls12only -propertyValue true]')"

		${WAS} "AdminTask.modifySSLConfig('[${alias_scope} ${_ssl_prot} TLSv1.2]')" 		
		${WAS} "AdminConfig.save()"	
		${SKLM_RESTART}
	else
		/bin/echo "SSL: It is recommended to use protocol [TLSv1.2] type for the SSL handshake." 
	fi
fi
/bin/echo ""
/bin/echo "SSL: Server SSL Certificate check"
/bin/echo "SSL: Brief information about SSL certification are going to be displayed:"

soap_port=$(/usr/bin/awk -F= '/com.ibm.ws.scripting.port=/ {print $2}' ${WAS_PROP})

/usr/bin/openssl s_client -connect $(/usr/bin/hostname -f):${soap_port} 2>/dev/null | /usr/bin/sed -n -e '/subject=/,$p'

/bin/echo ""
/bin/echo "SSL: if you see this message in return code: "
/bin/echo "SSL: Verify return code: 19 (self signed certificate in certificate chain)"
/bin/echo "SSL: Its mean the certificate it is not compliant."

/bin/echo "Done."
exit 0
