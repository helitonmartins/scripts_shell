#!/bin/bash
#-------------------------------------------------------------------------
# install-zabbix-client-3.2.sh
#
# Site  : http://wiki.douglasqsantos.com.br
# Author : Douglas Q. dos Santos <douglas.q.santos@gmail.com>
# Management: Douglas Q. dos Santos <douglas.q.santos@gmail.com>
#
#-------------------------------------------------------------------------
# Note: This Shell Script set up the initial configuration to Zabbix client
#-------------------------------------------------------------------------
# History:
#
# Version 1:
# Data: 04/04/2017
# Description: Set up the initial configuration of Zabbix client and will 
# generate the psk to be configured into Zabbix Server
#
#--------------------------------------------------------------------------
#License: http://creativecommons.org/licenses/by-sa/3.0/legalcode
#
#--------------------------------------------------------------------------
clear

## COMMANDS
CP="/bin/cp"
CD="cd"
CAT="/bin/cat"
WGET="/usr/bin/wget"
SED="/bin/sed"
DPKG="/usr/bin/dpkg"
TR="/usr/bin/tr"
APTITUDE="/usr/bin/aptitude"
IFCONFIG="/sbin/ifconfig"
GREP="/bin/grep"
AWK="/usr/bin/awk"
OPENSSL="/usr/bin/openssl"

## CONFIGURATION THAT WILL BE USED TO SET UP THE NEW CLIENT
IF_TUN="eth0"
ZABBIX_SERVER="10.0.0.1"

## URL TO FETCH THE ZABBIX RELEASE PACKAGE 
ZABBIX_REPO="http://repo.zabbix.com/zabbix/3.2/debian/pool/main/z/zabbix-release/zabbix-release_3.2-1+wheezy_all.deb"
ZABBIX_REL=$(echo ${ZABBIX_REPO} | ${GREP} -o '[^/]*$')

## GET THE CLIENT IP ADDRESS
CLI_IP=$(${IFCONFIG} ${IF_TUN} | ${GREP} -i "inet end.:" | ${AWK} '{ print $3 }')

## CHANGE THE VARAIABLE ABOVE TO BE COMPATIBLE WITH THE CLIENT NAME.  CLI_NAME="Client_name"
PSK_NAME="$(${TR} '[:lower:]' '[:upper:]' <<< ${CLI_NAME:0:1})${CLI_NAME:1}"

## PATH OF ZABBIX CLIENT CONFIGURATION FILE
ZABBIX_CLI="/etc/zabbix/zabbix_agentd.conf"

## COMMENT THE ZABBIX REPOSITORY LINES ADDED MANUALLY INTO THE SOURCES.LIST
${SED} -i 's,deb http://repo.zabbix,#deb http://repo.zabbix,g' /etc/apt/sources.list

## BACK UP THE OLD ZABBIX CLIENT CONFIGURATION IF IT EXISTS
if [ -e ${ZABBIX_CLI} ]; then
  ${CP} -Rfa ${ZABBIX_CLI} ${ZABBIX_CLI}.bkp
fi

## INSTALLING THE ZABBIX RELASE PACKAGE
${CD} /tmp
${WGET} -c ${ZABBIX_REPO}
${DPKG} -i ${ZABBIX_REL}
${APTITUDE} update

## INSTALLING THE ZABBIX CLIENT
${APTITUDE} install zabbix-agent zabbix-get zabbix-sender -o Dpkg::Options::="--force-confold" -y
${APTITUDE} install libcurl3-gnutls -y

## CREATING THE PSK THAT WILL BE USED BY THE CLIENT
${OPENSSL} rand -hex 32 > /etc/zabbix/zabbix_agentd.psk

## ZABBIX CLIENT CONFIGURATION
${CAT} << EOF > ${ZABBIX_CLI}
#/etc/zabbix/zabbix_agentd.conf
PidFile=/var/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=0
Server=${ZABBIX_SERVER}
ListenIP=${CLI_IP}
ServerActive=${ZABBIX_SERVER}
Hostname=${CLI_NAME}
Include=/etc/zabbix/zabbix_agentd.d/*.conf
## Configuração de PSK ##
TLSConnect=psk
TLSAccept=psk
TLSPSKIdentity=PSK_${PSK_NAME}
TLSPSKFile=/etc/zabbix/zabbix_agentd.psk
EOF


## SHOWING THE INFORMATION ABOUT THE CLIENT TO BE USED INTO THE ZABBIX SERVER 
PSK_NAME=$(cat /etc/zabbix/zabbix_agentd.conf | grep -i "TLSPSKIdentity" | cut -d "=" -f 2)
echo "PSK: ${PSK_NAME}"
PSK_KEY=$(cat /etc/zabbix/zabbix_agentd.psk)
echo "PSK_KEY: ${PSK_KEY}"
echo "VPN IP: ${CLI_IP}"

## RESTARTING THE ZABBIX AGENT
/etc/init.d/zabbix-agent restart
