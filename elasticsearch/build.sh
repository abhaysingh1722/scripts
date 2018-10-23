#!/bin/bash
# © Copyright IBM Corporation 2018.
# LICENSE: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)

set -e

PACKAGE_NAME="elasticsearch"
PACKAGE_VERSION="6.4.2"
CURDIR="$(pwd)"
REPO_URL="https://raw.githubusercontent.com/imdurgadas/scripts/master/elasticsearch/patch"
ES_REPO_URL="https://github.com/elastic/elasticsearch"
LOG_FILE="$CURDIR/logs/${PACKAGE_NAME}-${PACKAGE_VERSION}-$(date +"%F-%T").log"
TEST_USER="$(whoami)"
FORCE="false"

trap cleanup 0 1 2 ERR

#Check if directory exsists
if [ ! -d "$CURDIR/logs/" ]; then
   mkdir -p "$CURDIR/logs/"
fi

# Need handling for RHEL 6.10 as it doesn't have os-release file
if [ -f "/etc/os-release" ]; then
	source "/etc/os-release"
else
	cat /etc/redhat-release | tee -a "$LOG_FILE"
	export ID="rhel"
	export VERSION_ID="6.x"
	export PRETTY_NAME="Red Hat Enterprise Linux 6.x"
fi
function prepare() {

	if [[ "${TEST_USER}" == "root" ]]; then
		printf -- 'Cannot run Elasticsearch as root. Please use a standard user\n\n' | tee -a "$LOG_FILE"
		exit 1
	fi

	if command -v "sudo" >/dev/null; then
		printf -- 'Sudo : Yes\n' >>"$LOG_FILE"
	else
		printf -- 'Sudo : No \n' >>"$LOG_FILE"
		printf -- 'You can install sudo from repository using apt, yum or zypper based on your distro. \n'
		exit 1
	fi

	if [[ "$FORCE" == "true" ]]; then
		printf -- 'Force attribute provided hence continuing with install without confirmation message\n' | tee -a "$LOG_FILE"
	else
		printf -- 'Following packages are needed before going ahead\n' | tee -a "$LOG_FILE"
		printf -- 'AdoptOpenJDK 10\t\tVersion: jdk-10.0.2+13\n\n' | tee -a "$LOG_FILE"
		printf -- 'Build might take some time.Sit back and relax\n' | tee -a "$LOG_FILE"
		while true; do
			read -r -p "Do you want to continue (y/n) ? :  " yn
			case $yn in
			[Yy]*)

				break
				;;
			[Nn]*) exit ;;
			*) echo "Please provide Correct input to proceed." ;;
			esac
		done
	fi
}

function cleanup() {
	rm -rf "${CURDIR}/patch1.diff"
	rm -rf "${CURDIR}/patch2.diff"
	rm -rf "${CURDIR}/elasticsearch"
	rm -rf "${CURDIR}/OpenJDK10_s390x_Linux_jdk-10.0.2.13.tar.gz"

	printf -- '\nCleaned up the artifacts\n' >>"$LOG_FILE"
}

function configureAndInstall() {
	printf -- '\nConfiguration and Installation started \n' | tee -a "$LOG_FILE"

	#Installing dependencies
	printf -- 'User responded with Yes. \n' | tee -a "$LOG_FILE"
	printf -- 'Downloading openjdk\n' | tee -a "$LOG_FILE"
	wget -q 'https://github.com/AdoptOpenJDK/openjdk10-releases/releases/download/jdk-10.0.2%2B13/OpenJDK10_s390x_Linux_jdk-10.0.2.13.tar.gz'
	sudo tar -C /usr/local -xzf OpenJDK10_s390x_Linux_jdk-10.0.2.13.tar.gz
	export PATH=/usr/local/jdk-10.0.2+13/bin:$PATH
	java -version | tee -a "$LOG_FILE"
	printf -- 'Adopt JDK 10 installed\n' | tee -a "$LOG_FILE"

	cd "${CURDIR}"
	#Setting environment variable needed for building
	unset JAVA_TOOL_OPTIONS
	export LANG="en_US.UTF-8"
	export JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF8"
	export JAVA_HOME=/usr/local/jdk-10.0.2+13/
	export _JAVA_OPTIONS="-Xmx10g"

	#Added symlink for PATH
	sudo ln -sf /usr/local/jdk-10.0.2+13/bin/java /usr/bin/
	printf -- 'Adding JAVA_HOME to bashrc \n' | tee -a "$LOG_FILE"
	#add JAVA_HOME to .bashrc
	cd "${HOME}"
	if [[ "$(grep JAVA_HOME .bashrc)" ]]; then
		printf -- '\nChanging JAVA_HOME\n' | tee -a "$LOG_FILE"
		sed -n 's/^.*\bJAVA_HOME\b.*$/export JAVA_HOME=\/usr\/local\/jdk-9.0.4+11\//p' .bashrc | tee -a "$LOG_FILE"

	else
		echo "export JAVA_HOME=/usr/local/jdk-10.0.2+13/" >>.bashrc
	fi

	if [[ "${ID}" == "sles" ]]; then
		export ANT_HOME=/usr/share/ant/ #  for SLES
		export PATH=$ANT_HOME/bin:$PATH #  for SLES
	fi

	printenv >>"$LOG_FILE"
	cd "${CURDIR}"
	# Download and configure ElasticSearch
	printf -- 'Downloading Elasticsearch. Please wait.\n' | tee -a "$LOG_FILE"
	git clone -q -b v$PACKAGE_VERSION $ES_REPO_URL
	sleep 2

	#Patch Applied for known errors
	cd "${CURDIR}"
	# patch config file 
	wget -q $REPO_URL/patch1.diff
	patch "${CURDIR}/elasticsearch/distribution/src/config/jvm.options" patch1.diff

	wget -q $REPO_URL/patch2.diff
	patch "${CURDIR}/elasticsearch/distribution/src/config/elasticsearch.yml" patch2.diff

	printf -- 'Patch applied for files elasticsearch.yml and  jvm.options\n' | tee -a "$LOG_FILE"

	#Build elasticsearch
	printf -- 'Building Elasticsearch \n' | tee -a "$LOG_FILE"
	printf -- 'Build might take some time.Sit back and relax\n' | tee -a "$LOG_FILE"
	cd "${CURDIR}/elasticsearch"
	./gradlew -q assemble
	printf -- 'Built Elasticsearch successfully \n\n' | tee -a "$LOG_FILE"

}
function startService() {
	printf -- "\n\nstarting service\n" | tee -a "$LOG_FILE"
	cd "${CURDIR}/elasticsearch"
	sudo tar -C /usr/share/ -xf distribution/archives/tar/build/distributions/elasticsearch-6.4.2-SNAPSHOT.tar.gz
	sudo mv /usr/share/elasticsearch-6.4.2-SNAPSHOT /usr/share/elasticsearch

	if ([[ -z "$(cut -d: -f1 /etc/group | grep elastic)" ]]); then
		printf -- '\nCreating group elastic\n' | tee -a "$LOG_FILE"
		sudo /usr/sbin/groupadd elastic # If group is not already created

	fi
	sudo chown "$TEST_USER:elastic" -R /usr/share/elasticsearch

	#To access elastic search from anywhere
	sudo ln -sf /usr/share/elasticsearch/bin/elasticsearch /usr/bin/

	# elasticsearch calls this file internally
	sudo ln -sf /usr/share/elasticsearch/bin/elasticsearch-env /usr/bin/

	#Verify elasticsearch installation
	if command -V "$PACKAGE_NAME" >/dev/null; then
		printf -- "%s installation completed.\n" "$PACKAGE_NAME" | tee -a "$LOG_FILE"
	else
		printf -- "Error while installing %s, exiting with 127 \n" "$PACKAGE_NAME"
		exit 127
	fi

	printf -- 'Service started\n' | tee -a "$LOG_FILE"
}

function installClient() {
	printf -- '\nInstalling curator client\n' | tee -a "$LOG_FILE"
	if [[ "${ID}" == "sles" ]]; then
		sudo zypper -q install -y python-pip python-devel > /dev/null
	fi

	if [[ "${ID}" == "ubuntu" ]]; then
		sudo apt-get update > /dev/null
		sudo apt-get install -y -qq python-pip > /dev/null
	fi

	if [[ "${ID}" == "rhel" ]]; then
		sudo yum install -y -q python-setuptools > /dev/null
		sudo easy_install pip > /dev/null
	fi

	sudo -H pip install elasticsearch-curator > /dev/null
	printf -- "\nInstalled Elasticsearch Curator client successfully" | tee -a "$LOG_FILE"

	#Cleanup
	cleanup


}

function logDetails() {
	printf -- 'SYSTEM DETAILS\n' >"$LOG_FILE"
	if [ -f "/etc/os-release" ]; then
		cat "/etc/os-release" >>"$LOG_FILE"
	fi

	cat /proc/version >>"$LOG_FILE"
	printf -- "\nDetected %s \n" "$PRETTY_NAME"
	printf -- "Request details : PACKAGE NAME= %s , VERSION= %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" | tee -a "$LOG_FILE"
}

# Print the usage message
function printHelp() {
	echo
	echo "Usage: "
	echo "  install.sh [-s <silent>] [-d <debug>] [-v package-version] [-o override] [-p check-prequisite]"
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
	printf -- '\n********************************************************************************************************\n'
    printf -- "\n* Getting Started * \n" 
	printf -- '\n\n Set JAVA_HOME to start using elasticsearch right away.' | tee -a "$LOG_FILE"
	printf -- '\n    export JAVA_HOME=/usr/local/jdk-10.0.2+13/\n' | tee -a "$LOG_FILE"
	printf -- '\n Restarting the session will apply changes automatically' | tee -a "$LOG_FILE"
	printf -- '\n\n Start Elasticsearch using the following command :   elasticsearch ' | tee -a "$LOG_FILE"
	printf -- '\nFor more information on curator client visit https://www.elastic.co/guide/en/elasticsearch/client/curator/current/index.html \n\n' | tee -a "$LOG_FILE"
	printf -- '**********************************************************************************************************\n'

}

logDetails
prepare

DISTRO="$ID-$VERSION_ID"
case "$DISTRO" in
"ubuntu-16.04" | "ubuntu-18.04")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	printf -- "Installing dependencies... it may take some time.\n"
	sudo apt-get update > /dev/null
	sudo apt-get install -y -qq tar patch wget unzip curl maven git make automake autoconf libtool patch libx11-dev libxt-dev pkg-config texinfo locales-all ant hostname > /dev/null 
	configureAndInstall
	startService
	installClient
	;;

"rhel-7.3" | "rhel-7.4" | "rhel-7.5")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	printf -- "Installing dependencies... it may take some time.\n"
	sudo yum install -y -q unzip patch curl which git gcc-c++ make automake autoconf libtool libstdc++-static tar wget patch libXt-devel libX11-devel texinfo ant ant-junit.noarch hostname > /dev/null
	configureAndInstall
	startService
	installClient
	;;

"sles-12.3" | "sles-15")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	printf -- "Installing dependencies... it may take some time.\n"
	sudo zypper -q --non-interactive install tar patch wget unzip curl which git gcc-c++ patch libtool automake autoconf ccache xorg-x11-proto-devel xorg-x11-devel alsa-devel cups-devel libstdc++6-locale glibc-locale libstdc++-devel libXt-devel libX11-devel texinfo ant ant-junit.noarch make net-tools > /dev/null
	configureAndInstall
	startService
	installClient
	;;

*)
	printf -- "%s not supported \n" "$DISTRO" | tee -a "$LOG_FILE"
	exit 1
	;;
esac

printSummary
