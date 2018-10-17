#!/bin/bash
# © Copyright IBM Corporation 2017, 2018.
# LICENSE: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)

set -e

PACKAGE_NAME="logstash"
PACKAGE_VERSION="6.4.2"
FORCE=false
WORKDIR="/usr/local"
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

function prepare() {
	if command -v "sudo" >/dev/null; then
		printf -- 'Sudo : Yes\n'
	else
		printf -- 'Sudo : No \n'
		printf -- 'You can install the same from installing sudo from repository using apt, yum or zypper based on your distro. \n'
		exit 1
	fi

	if [[ "$FORCE" == "true" ]]; then
		printf -- 'Force attribute provided hence continuing with install without confirmation message' | tee -a "${LOG_FILE}"
	else
		# Ask user for prerequisite installation
		printf -- "\n\nAs part of the installation , IBMSDK 8 will be installed, \n"
		while true; do
			read -r -p "Do you want to continue (y/n) ? :  " yn
			case $yn in
			[Yy]*)
				printf -- 'User responded with Yes. \n' | tee -a "${LOG_FILE}"
				break
				;;
			[Nn]*) exit ;;
			*) echo "Please provide confirmation to proceed." ;;
			esac
		done
	fi
}

function cleanup() {
	rm -rf "${WORKDIR}/apache-ant-1.9.10"
	rm -rf "${WORKDIR}/ibm-java-s390x-sdk-8.0-5.17.bin"
	rm -rf "${WORKDIR}/installer.properties"
	rm -rf "${WORKDIR}/jffi-jffi-1.2.16/"
	printf -- 'Cleaned up the artifacts\n' >>"${LOG_FILE}"
}

function configureAndInstall() {
	#cleanup
	printf -- 'Configuration and Installation started \n' | tee -a "${LOG_FILE}"

	# Install IBMSDK
	printf -- 'Configuring IBMSDK \n' | tee -a "${LOG_FILE}"
	cd "${WORKDIR}"

	wget http://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java/8.0.5.17/linux/s390x/ibm-java-s390x-sdk-8.0-5.17.bin >>"${LOG_FILE}"
	wget https://raw.githubusercontent.com/zos-spark/scala-workbench/master/files/installer.properties.java >>"${LOG_FILE}"
	
	tail -n +3 installer.properties.java | tee installer.properties
	cat installer.properties >>"${LOG_FILE}"
	chmod +x ibm-java-s390x-sdk-8.0-5.17.bin
	sudo ./ibm-java-s390x-sdk-8.0-5.17.bin -r installer.properties | tee -a "${LOG_FILE}"
	
	export JAVA_HOME=/opt/ibm/java
	export PATH="${JAVA_HOME}/bin:$PATH"
	java -version

	# Install Ant (for RHEL 6.10)
	if [[ "${VERSION_ID}" == "6.x" ]]; then
		wget http://archive.apache.org/dist/ant/binaries/apache-ant-1.9.10-bin.tar.gz >>"${LOG_FILE}"
		tar -zxvf apache-ant-1.9.10-bin.tar.gz >>"${LOG_FILE}"
		export ANT_HOME="${WORKDIR}/apache-ant-1.9.10"
		export PATH="${ANT_HOME}/bin:${PATH}"
		printf -- 'Installed Ant successfully for Rhel 6.10 \n' >>"${LOG_FILE}"
	fi

	#Install Logstash
	printf -- 'Installing Logstash..... \n' | tee -a "${LOG_FILE}"
	printf -- 'Download source code of Logstash\n' | tee -a "${LOG_FILE}"
	cd "${WORKDIR}"
	wget https://artifacts.elastic.co/downloads/logstash/logstash-6.4.2.zip >>"${LOG_FILE}"
	unzip -u logstash-6.4.2.zip >>"${LOG_FILE}"

	printf -- 'Jruby runs on JVM and needs a native library (libjffi-1.2.so: java foreign language interface). Get jffi source code and build with ant.\n' | tee -a "${LOG_FILE}"
	cd "${WORKDIR}"
	wget https://github.com/jnr/jffi/archive/jffi-1.2.16.zip >>"${LOG_FILE}"
	unzip -u jffi-1.2.16.zip >>"${LOG_FILE}"
	cd jffi-jffi-1.2.16
	ant >>"${LOG_FILE}"

	printf -- 'Add libjffi-1.2.so to LD_LIBRARY_PATH \n' >>"${LOG_FILE}"
	export LD_LIBRARY_PATH="${WORKDIR}/jffi-jffi-1.2.16/build/jni/:${LD_LIBRARY_PATH}"

	# Link Logstash to /usr/bin
	sudo ln -s "${WORKDIR}/logstash-6.4.2/bin/logstash" /usr/bin/
	printf -- 'Installed logstash successfully \n' >>"${LOG_FILE}"

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
	printf -- "Run Logstash: \n"
	printf -- "    logstash -V (To Check the version) \n"
	printf -- '***************************************************************************************\n'
	printf -- '\n'
}

###############################################################################################################

logDetails
prepare

DISTRO="$ID-$VERSION_ID"
case "$DISTRO" in
"ubuntu-16.04" | "ubuntu-18.04")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "${LOG_FILE}"
	sudo apt-get update
	sudo apt-get install -qq ant make wget unzip tar gcc >/dev/null
	configureAndInstall
	;;

"rhel-6.x")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "${LOG_FILE}"
	sudo yum install -y -q wget unzip tar gcc make >/dev/null
	configureAndInstall
	;;

"rhel-7.3" | "rhel-7.4" | "rhel-7.5")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "${LOG_FILE}"
	sudo yum install -y -q ant wget unzip make gcc tar >/dev/null
	configureAndInstall
	;;

"sles-12.3")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "${LOG_FILE}"
	sudo zypper install -y --type pattern Basis-Devel
	sudo zypper -q install -y ant wget unzip make gcc tar >/dev/null
	configureAndInstall
	;;

"sles-15")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "${LOG_FILE}"
	sudo zypper -q install -y ant wget unzip make gcc tar >/dev/null
	configureAndInstall
	;;

*)
	printf -- "%s not supported \n" "$DISTRO" | tee -a "${LOG_FILE}"
	exit 1
	;;
esac

printSummary
