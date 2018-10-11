#!/bin/bash
# © Copyright IBM Corporation 2017, 2018.
# LICENSE: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)

set -e

PACKAGE_NAME="kibana"
PACKAGE_VERSION="6.4.2"
#OVERRIDE=false
WORKDIR="$(pwd)"
LOG_FILE="${WORKDIR}/${PACKAGE_NAME}-${PACKAGE_VERSION}-$(date +"%F-%T").log"

trap "" 1 2 ERR

# Need handling for RHEL 6.10 as it doesn't have os-release file
if [ -f "/etc/os-release" ]; then
	source "/etc/os-release"
else
	cat /etc/redhat-release >>"${LOG_FILE}"
	export ID="rhel"
	export VERSION_ID="6.x"
	export PRETTY_NAME="Red Hat Enterprise Linux 6.x"
fi

function checkPrequisites() {
	if command -v "sudo" >/dev/null; then
		printf -- 'Sudo : Yes\n'
	else
		printf -- 'Sudo : No \n'
		printf -- 'You can install the same from installing sudo from repository using apt, yum or zypper based on your distro. \n'
		exit 1
	fi
}

function cleanup() {
	rm -rf "${WORKDIR}/kibana-6.4.2-linux-x86_64"
	rm -rf "${WORKDIR}/nodejs"
	rm -rf "${WORKDIR}/kibana-6.4.2-linux-x86_64.tar.gz" "${WORKDIR}/node-v8.11.4-linux-s390x.tar.gz"
	printf -- 'Cleaned up the artifacts\n' >>"${LOG_FILE}"
}

function configureAndInstall() {
	#cleanup
	printf -- 'Configuration and Installation started \n'

	# Install Nodejs
	printf -- 'Downloading nodejs binaries \n'
	cd "${WORKDIR}"
	wget https://nodejs.org/dist/v8.11.4/node-v8.11.4-linux-s390x.tar.gz
	tar xvf node-v8.11.4-linux-s390x.tar.gz
	mv node-v8.11.4-linux-s390x nodejs
	export PATH=$PATH:$PWD/nodejs/bin
	node -v

	#Install Kibana
	printf -- '\nInstalling Kibana..... \n'
	printf -- '\nGet Kibana release package and extract\n'
	cd "${WORKDIR}"
	wget https://artifacts.elastic.co/downloads/kibana/kibana-6.4.2-linux-x86_64.tar.gz
	tar xvf kibana-6.4.2-linux-x86_64.tar.gz

	printf -- '\nReplace Node.js in the package with the installed Node.js.\n'
	cd "${WORKDIR}/kibana-6.4.2-linux-x86_64"
	mv node node_old # rename the node
	ln -s "${WORKDIR}"/nodejs node

	# Add kibana to /usr/bin
	sudo cp -Rf "${WORKDIR}/kibana-6.4.2-linux-x86_64/bin/kibana" /usr/bin/
	printf -- 'Installed kibana successfully \n' >>"${LOG_FILE}"

	#Cleanup
	cleanup

	#Verify kibana installation
	if command -v "$PACKAGE_NAME" >/dev/null; then
		printf -- "%s installation completed. Please check the Usage to start the service.\n" "$PACKAGE_NAME" | tee -a "$LOG_FILE"
	else
		printf -- "Error while installing %s, exiting with 127 \n" "$PACKAGE_NAME"
		exit 127
	fi
}

function logDetails() {
	printf -- '**************************** SYSTEM DETAILS *************************************************************\n' >"$LOG_FILE"
	if [ -f "/etc/os-release" ]; then
		cat "/etc/os-release" >>"$LOG_FILE"
	fi

	cat /proc/version >>"$LOG_FILE"
	printf -- '*********************************************************************************************************\n' >>"$LOG_FILE"

	printf -- "Detected %s \n" "$PRETTY_NAME"
	printf -- "Request details : PACKAGE NAME= %s , VERSION= %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" | tee -a "$LOG_FILE"
}

# Print the usage message
function printHelp() {
	echo
	echo "Usage: "
	echo "  install.sh  [-d <debug>] [-v package-version] [-y install-without-confirmation]"
	echo "       default: If no -v specified, latest version will be installed"
	echo
}

while getopts "h?dyv:" opt; do
	case "$opt" in
	h | \?)
		printHelp
		exit 0
		;;
	d)
		set -x
		;;
	v)
		PACKAGE_VERSION="$OPTARG"
		;;
	y)
		FORCE="true"
		;;
	esac
done

function printSummary() {
	printf -- '\n***************************************************************************************\n'
	printf -- "Start Kibana: \n"
	printf -- "Now Kibana is ready to execute, make sure an Elasticsearch instance is running, and update the Kibana configuration file config/kibana.yml to set elasticsearch.url to the Elasticsearch host. \n"
	printf -- "    cd ${WORKDIR}/kibana-6.4.2-linux-x86_64  \n"
	printf -- "    bin/kibana  & (Run in background) \n"
	printf -- "\nAccess kibana UI using the below link : "
	printf -- "http://<host-ip>:<port>/    [Default port = 5601] \n"
	printf -- '***************************************************************************************\n'
	printf -- '\n'
}

###############################################################################################################

logDetails
checkPrequisites

DISTRO="$ID-$VERSION_ID"
case "$DISTRO" in
"ubuntu-16.04" | "ubuntu-18.04")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "${LOG_FILE}"
	sudo apt-get update
	sudo apt-get install wget tar >/dev/null
	configureAndInstall
	;;

"rhel-7.3" | "rhel-7.4" | "rhel-7.5")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "${LOG_FILE}"
	sudo yum install wget tar >/dev/null
	configureAndInstall
	;;

"sles-12.3" | "sles-15")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "${LOG_FILE}"
	sudo zypper install wget tar >/dev/null
	configureAndInstall
	;;

*)
	printf -- "%s not supported \n" "$DISTRO" | tee -a "${LOG_FILE}"
	exit 1
	;;
esac

printSummary

