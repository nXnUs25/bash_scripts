#!/bin/bash

## author: Augustyn Chmiel
## e-mail: augustyc@ie.ibm.com

## usage: ./harden_passwd_verification 0 -> applying changes to the OS configuration
## usage: ./harden_passwd_verification 1 -> preform checks to the OS configuration

HOME_PROP=${1:-"/root/isklm_hardening/isklm_script_properties.properties"}
if [[ ! -f ${HOME_PROP} ]];
then
	/bin/echo "ISKLM scripts property doesnt exist: ${HOME_PROP}"
	exit 1
fi
. ${HOME_PROP}

CHECK_ONLY=${2:-1}      ### 0 disabled - do all ; 1 enabled preform only checks

if [[ ! -f ${HOME_PROP} ]];
then
	/usr/bin/mkdir -p ${logs_location:-"/var/log/hardening"}
fi
temp=${0##*/}
LOGFILE="${logs_location}/${temp%.*}.log"

exec > >( /bin/sed "s/^/$(/bin/date '+[%F %T]'): /" | /usr/bin/tee -a ${LOGFILE}) 2>&1

regex='^-?[0-9]+([.][0-9]+)?$'
if ! [[ ${ACTION} =~ ${regex} ]] ; then
        echo "error: Not a number: [${ACTION}]"
        /bin/echo -e "Usage: ./harden_passwd_verification [option]\n       ./harden_passwd_verification 0"
        /bin/echo -e "0 - check mode disabled - do all [checks and changes]\n1 - checks enabled, preforming only checks"
        exit 1
fi

echo ''
echo "Starting checks: "$(/bin/date "+%Y%m%d-%H%M%S")
min_value=8		### min lenght for password

if [[ ${CHECK_ONLY} -eq 0 ]];
then
	/bin/echo "Script will apply changes to meeet ITCS104 standards [changing the OS configuration]"
else
	/bin/echo "Script will run verification for settings only [no changes to the system]"
fi

RH=$(/bin/cat /etc/redhat-release | /bin/cut -d" " -f7 | /bin/cut -d "." -f1)

/bin/echo ''
/bin/echo 'Check: min password lenght.'
/bin/echo ''

## redhat 6

if [[ ${RH} -eq 6 ]];
then
	if /bin/grep -q 'pam_cracklib.so' /etc/pam.d/system-auth-ac 
	then
		/bin/echo "PASSWORD MIN LENGTH ITCS 104 NOT COMPLIANT"
		/bin/echo "pam_cracklib.so is configured instead of pam_passwdqc.so"
	
		if /bin/rpm -q --quiet 'pam_passwdqc' 
		then
			/bin/echo "pam_passwdqc.so it is installed but not configured"
			/bin/echo "password    requisite      pam_passwdqc.so min=disabled,${min_value},8,8,8 passphrase=0 random=0 enforce=everyone"
			crack_minlen=$(/bin/grep -Eo 'minlen=[0-9]+' /etc/pam.d/system-auth-ac | /usr/bin/awk -F= '{print $NF}')
			if [[ ${crack_minlen} -eq ${min_value} ]];
			then
				/bin/echo "pam_cracklib MIN LEN set to: [${crack_minlen}]"
				/bin/echo "pam_cracklib need to be replaced with pam_pwquality for better security"
			else
				/bin/echo "NO PASS MIN LEN ENTRY."
				if [[ ${CHECK_ONLY} -eq 0 ]];
				then
					/bin/cp -av /etc/pam.d/system-auth-ac /etc/pam.d/system-auth-ac-$(/bin/date "+%Y%m%d-%H%M%S")~~
					/bin/sed -i "s/password    required      pam_cracklib.so.*/password    required      pam_cracklib.so retry=3 minlen=${min_value} dcredit=-1 ucredit=0 lcredit=-1 ocredit=0 type= reject_username/" /etc/pam.d/system-auth-ac
				else
					 /bin/echo "You should use pam_pwquality module, not pam_passwdqc"
				fi
			fi

			if [[ ${CHECK_ONLY} -eq 0 ]];
			then
				/bin/echo "CREATING ONE"
			/bin/cp -av /etc/pam.d/system-auth-ac /etc/pam.d/system-auth-ac-$(/bin/date "+%Y%m%d-%H%M%S")~
			/bin/sed -i  "s/password    requisite     pam_cracklib.so.*/password    requisite      pam_passwdqc.so min=disabled,${min_value},8,8,8 passphrase=0 random=0 enforce=everyone/" /etc/pam.d/system-auth-ac
			else
				/bin/grep 'pam_cracklib.so' /etc/pam.d/system-auth-ac
			fi
		else
			/bin/echo "pam_passwdqc.so it is not installed"	
		fi
	else 
		if /bin/grep -q 'pam_passwdqc.so' /etc/pam.d/system-auth-ac
		then
			/bin/echo "PASS MIN LENGTH ENTRY FOUND"
			minlengthStr=$(/usr/bin/awk -F" " '{print $3":"$4}' /etc/pam.d/system-auth-ac | /bin/grep pam_passwdqc.so)
			minlength=$(/bin/echo ${minlengthStr} | /bin/cut -c30-30)
			/bin/echo "DEFINED MIN LEN : [${minlength}]"
			if [[ ${minlength} -eq ${min_value} ]]; 
			then
				/bin/echo "PASSWORD MIN LENGTH ITCS 104 COMPLIANT"
			else
				/bin/echo "PASSWORD MIN LENGTH ITCS 104 NOT COMPLIANT"
				if [[ ${CHECK_ONLY} -eq 0 ]];
				then
					/bin/cp -av /etc/pam.d/system-auth-ac /etc/pam.d/system-auth-ac-$(/bin/date "+%Y%m%d-%H%M%S")~
					/bin/sed -i "s/^password    requisite     pam_passwdqc.so.*/password    requisite      pam_passwdqc.so min=disabled,${min_value},8,8,8 passphrase=0 random=0 enforce=everyone/" /etc/pam.d/system-auth-ac
				else
					/bin/grep 'pam_passwdqc.so' /etc/pam.d/system-auth-ac
				fi
			fi
		else 
			/bin/echo "unknow configuration for /etc/pam.d/system-auth-ac, Please verify it manually"
		fi	
	fi
fi

## redhat 7
if [[ ${RH} -eq 7 ]];
then
	if /bin/grep -q 'pam_cracklib.so' /etc/pam.d/system-auth-ac
	then
                /bin/echo "PASSWORD MIN LENGTH ITCS 104 NOT COMPLIANT" 
		/bin/echo "pam_cracklib.so is configured instead of pam_pwquality.so"
		/bin/echo "password    requisite      pam_pwquality.so minlen=${min_value} try_first_pass local_users_only retry=3 authtok_type="
		crack_minlen=$(/bin/grep -Eo 'minlen=[0-9]+' /etc/pam.d/system-auth-ac | /usr/bin/awk -F= '{print $NF}')
		if [[ ${crack_minlen} -eq ${min_value} ]];
		then
			/bin/echo "pam_cracklib MIN LEN set to: [${crack_minlen}]"
			/bin/echo "pam_cracklib need to be replaced with pam_pwquality for better security"
		else
			/bin/echo "NO PASS MIN LEN ENTRY."
			if [[ ${CHECK_ONLY} -eq 0 ]];
			then
				/bin/cp -av /etc/pam.d/system-auth-ac /etc/pam.d/system-auth-ac-$(/bin/date "+%Y%m%d-%H%M%S")~~
				/bin/sed -i "s/password    required      pam_cracklib.so.*/password    required      pam_cracklib.so retry=3 minlen=${min_value} dcredit=-1 ucredit=0 lcredit=-1 ocredit=0 type= reject_username/" /etc/pam.d/system-auth-ac
			else
				/bin/echo "You should use pam_pwquality module, not pam_cracklib"
			fi
		fi
		if [[ ${CHECK_ONLY} -eq 0 ]];
		then
			/bin/echo "CREATING ONE"
			/bin/cp -av /etc/pam.d/system-auth-ac /etc/pam.d/system-auth-ac-$(/bin/date "+%Y%m%d-%H%M%S")~
			/bin/sed -i  "s/password    requisite     pam_cracklib.so.*/password    requisite      pam_pwquality.so minlen=${min_value} try_first_pass local_users_only retry=3 authtok_type=/" /etc/pam.d/system-auth-ac
		else
			/bin/grep  'pam_cracklib.so' /etc/pam.d/system-auth-ac	
		fi
	else
		if /bin/grep -q 'pam_pwquality.so' /etc/pam.d/system-auth-ac
		then
			/bin/echo "PASS MIN LENGTH ENTRY FOUND"
			minlengthStr=$(/usr/bin/awk -F" " '{print $3":"$4}' /etc/pam.d/system-auth-ac | /bin/grep pam_pwquality.so)
			minlength=$(/bin/echo ${minlengthStr} | /bin/cut -c25-25)
			/bin/echo "DEFINED MIN LEN : [${minlength}]"
			if [[ ${minlength} -eq ${min_value} ]]; 
			then
				/bin/echo "PASSWORD MIN LENGTH ITCS 104 COMPLIANT"
			else
				/bin/echo "PASSWORD MIN LENGTH ITCS 104 NOT COMPLIANT"
				if [[ ${CHECK_ONLY} -eq 0 ]];
				then
					/bin/echo "CREATING ONE"
					/bin/cp -av /etc/pam.d/system-auth-ac /etc/pam.d/system-auth-ac-$(/bin/date "+%Y%m%d-%H%M%S")~
					/bin/sed -i "s/^password    requisite     pam_pwquality.so.*/password    requisite      pam_pwquality.so minlen=${min_value} try_first_pass local_users_only retry=3 authtok_type=/" /etc/pam.d/system-auth-ac
				else
					/bin/grep 'pam_pwquality.so' /etc/pam.d/system-auth-ac
				fi
			fi
		fi	
	fi
fi


/bin/echo ''
/bin/echo 'Check: Users password max age'

users=$(/usr/bin/awk -F: '!/\/sbin\/nologin/ {if ($4 > 199) {print $1}}' /etc/passwd)

for x in ${users}
do
	/bin/echo ''
	pwd_age=$(/bin/grep ${x} /etc/shadow | /bin/cut -d: -f5) 
	/bin/echo "For User: [${x}]"
	/bin/echo "Password Maximum Age: [${pwd_age}]"
	if [[ ${pwd_age} -gt 90 || -z ${pwd_age} ]];
	then
		/bin/echo "PASSWORD MAX AGE ITCS 104 NOT COMPLIANT"
		if [[ ${CHECK_ONLY} -eq 0 ]];
		then
			/bin/echo "Changing Max Age for user: [${x}]"
			/usr/bin/chage -m 1 -M 90 ${x}
		else
			/usr/bin/chage -l ${x}	
		fi
	else
		/bin/echo "PASSWORD MAX AGE ITCS 104 COMPLIANT"
	fi	
done

/bin/echo "Verify compliant unique passwords"

users=$(/usr/bin/awk -F: '$NF ~ /\/bin\/bash/ {print $1}' /etc/passwd)
for x in ${users}
do
	/bin/echo ''
	pwd=$(/bin/grep ${x} /etc/shadow | /bin/cut -d: -f2 | /bin/cut -d$ -f4)
	if [[ ${pwd} == '!!' ]];
	then
		/bin/echo "No Password assigned for User: [$x]"
	else
		/bin/echo "For User: [${x}]"
		not_uniq_pwd=$(/bin/sed -e "/${x}/d" /etc/shadow | /bin/grep "${pwd}" | /usr/bin/awk -F: '{print $1}' | /usr/bin/tr '\n' ' ')	
		if [[ -z ${not_uniq_pwd} ]];
		then
			/bin/echo "Password it is unique"
		else
			/bin/echo "non-uniq password, same password for: ${not_uniq_pwd}"
		fi
	fi
done


exit 0
