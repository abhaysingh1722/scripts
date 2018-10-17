#!/bin/bash
# © Copyright IBM Corporation 2017, 2018.
# LICENSE: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)

set -e

PACKAGE_NAME="grafana"
PACKAGE_VERSION="5.2.4"
CURDIR="$(pwd)"
GO_DEFAULT="$HOME/go"
# Update URL with master repo
GO_INSTALL_URL="https://raw.githubusercontent.com/sid226/scripts/master/Go/build.sh"
# Update URL with master repo
PHANTOMJS_INSTALL_URL="https://raw.githubusercontent.com/imdurgadas/scripts/master/PhantomJS/build.sh"
FORCE="false"
LOG_FILE="${CURDIR}/logs/${PACKAGE_NAME}-${PACKAGE_VERSION}-$(date +"%F-%T").log"
BUILD_DIR="/usr/local"
# Update URL with master repo
GRAFANA_CONFIG_URL="https://raw.githubusercontent.com/sid226/scripts/master/Grafana/conf/grafana.ini"

trap cleanup 0 1 2 ERR

mkdir -p "$CURDIR/logs/"

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
		printf -- 'Sudo : Yes\n' >>"$LOG_FILE"
	else
		printf -- 'Sudo : No \n' >>"$LOG_FILE"
		printf -- 'You can install the same from installing sudo from repository using apt, yum or zypper based on your distro. \n'
		exit 1
	fi

	if [[ "$FORCE" == "true" ]]; then
		printf -- 'Force attribute provided hence continuing with install without confirmation message' | tee -a "$LOG_FILE"
	else
		# Ask user for prerequisite installation
		printf -- "\\n\\nAs part of the installation , Go 1.10.1 and PhantomJS 2.1.1 will be installed, \\n"
		while true; do
			read -r -p "Do you want to continue (y/n) ? :  " yn
			case $yn in
			[Yy]*)
				printf -- 'User responded with Yes. \n' | tee -a "$LOG_FILE"
				break
				;;
			[Nn]*) exit ;;
			*) echo "Please provide confirmation to proceed." ;;
			esac
		done
	fi
}

function cleanup() {

	#Check if Grafana directory exists
	if [ -d "$GOPATH/src/github.com/grafana" ]; then
		rm -rf "$GOPATH/src/github.com/grafana"
	fi

	if [ -f /opt/yarn-v1.3.2.tar.gz ]; then
		rm /opt/yarn-v1.3.2.tar.gz
	fi

	if [ -f "$BUILD_DIR/node-v8.11.3-linux-s390x.tar.xz" ]; then
		"$BUILD_DIR/node-v8.11.3-linux-s390x.tar.xz"
	fi

	printf -- 'Cleaned up the artifacts\n' >>"$LOG_FILE"
}

function configureAndInstall() {
	printf -- 'Configuration and Installation started \n'

	# Install grafana
	printf -- "\\nInstalling %s..... \\n" "$PACKAGE_NAME"

	# Grafana installation

	#Install NodeJS
	cd "$BUILD_DIR"
	wget -q https://nodejs.org/dist/v8.11.3/node-v8.11.3-linux-s390x.tar.xz
	chmod ugo+r node-v8.11.3-linux-s390x.tar.xz
	sudo tar -C "$BUILD_DIR" -xf node-v8.11.3-linux-s390x.tar.xz
	export PATH=$PATH:/usr/local/node-v8.11.3-linux-s390x/bin

	printf -- 'Install NodeJS success \\n' >>"$LOG_FILE"

	cd "${CURDIR}"

	# Install go
	printf -- "Installing Go... \\n" | tee -a "$LOG_FILE"
	curl -s $GO_INSTALL_URL | bash

	# Set GOPATH if not already set
	if [[ -z "${GOPATH}" ]]; then
		printf -- "Setting default value for GOPATH \\n" >>"$LOG_FILE"

		#Check if go directory exists
		if [ ! -d "$HOME/go" ]; then
			mkdir "$HOME/go"
		fi
		export GOPATH="${GO_DEFAULT}"
		export PATH=$PATH:$GOPATH/bin
	else
		printf -- "GOPATH already set : Value : %s \\n" "$GOPATH" >>"$LOG_FILE"
	fi
	printenv >>"$LOG_FILE"

	#Build Grafana
	printf -- "Building Grafana... \\n" | tee -a "$LOG_FILE"
	#Check if Grafana directory exists
	if [ ! -d "$GOPATH/src/github.com/grafana" ]; then
		printf -- "Created grafana Directory at GOPATH"
		mkdir -p "$GOPATH/src/github.com/grafana"
	fi

	cd "$GOPATH/src/github.com/grafana"
	if [ -d "$GOPATH/src/github.com/grafana/grafana" ]; then
		printf -- "Removing Existing grafana Directory at GOPATH"
		rm -rf "$GOPATH/src/github.com/grafana/grafana"
	fi
	git clone -q -b v5.2.4 https://github.com/grafana/grafana.git

	printf -- "Created grafana Directory at 1"
	cd grafana
	printf -- "Created grafana Directory at 2"
	make deps-go
	make build-go
	printf -- 'Build Grafana success \n' >>"$LOG_FILE"

	#Add grafana to /usr/bin
	cp "$GOPATH/src/github.com/grafana/grafana/bin/linux-s390x/grafana-server" /usr/bin/
	cp "$GOPATH/src/github.com/grafana/grafana/bin/linux-s390x/grafana-cli" /usr/bin/

	printf -- 'Add grafana to /usr/bin success \n' >>"$LOG_FILE"

	cd "${CURDIR}"

	# Build Grafana frontend assets

	# Install PhantomJS
	printf -- "Installing PhantomJS... \\n" | tee -a "$LOG_FILE"
	bash -c "$(curl -s $PHANTOMJS_INSTALL_URL)"

	printf -- 'PhantomJS install success \n' >>"$LOG_FILE"

	# export  QT_QPA_PLATFORM on Ubuntu
	if [[ "$ID" == "ubuntu" ]]; then
		export QT_QPA_PLATFORM=offscreen
	fi

	# Install gperf on RHEL
	if [[ "$ID" == "rhel" ]]; then
		wget -q http://archives.fedoraproject.org/pub/archive/fedora-secondary/releases/23/Everything/s390x/os/Packages/g/gperf-3.0.4-11.fc23.s390x.rpm
		sudo rpm --quiet -Uvh gperf-3.0.4-11.fc23.s390x.rpm
		printf -- 'gperf install success \n' >>"$LOG_FILE"
	fi

	# Install yarn
	cd /opt
	sudo wget -q https://github.com/yarnpkg/yarn/releases/download/v1.3.2/yarn-v1.3.2.tar.gz
	sudo tar zxf yarn-v1.3.2.tar.gz
	export PATH=$PATH:/opt/yarn-v1.3.2/bin
	printf -- 'yarn install success \n' >>"$LOG_FILE"

	# Install grunt
	cd "$GOPATH/src/github.com/grafana/grafana"
	npm install grunt
	printf -- 'grunt install success \n' >>"$LOG_FILE"

	# Build Grafana frontend assets
	make deps-js
	make build-js

	printf -- 'Grafana frontend assets build success \n' >>"$LOG_FILE"

	cd "${CURDIR}"

	# Move build artifacts to default directory
	if [ ! -d "/usr/local/share/grafana" ]; then
		printf -- "Created grafana Directory at /usr/local/share" >>"$LOG_FILE"
		mkdir /usr/local/share/grafana
	fi

	cp -r "$GOPATH/src/github.com/grafana/grafana/*" /usr/local/share/grafana
	printf -- 'Move build artifacts success \n' >>"$LOG_FILE"

	#Add grafana config
	if [ ! -d "/etc/grafana" ]; then
		printf -- "Created grafana config Directory at /etc" >>"$LOG_FILE"
		mkdir /etc/grafana/
	fi
	wget -q $GRAFANA_CONFIG_URL
	cp grafana.ini /etc/grafana/
	printf -- 'Add grafana config success \n' >>"$LOG_FILE"

	#Cleanup
	cleanup

	#Verify grafana installation
	if command -v "$PACKAGE_NAME-server" >/dev/null; then
		printf -- "%s installation completed. Please check the Usage to start the service.\\n" "$PACKAGE_NAME" | tee -a "$LOG_FILE"
	else
		printf -- "Error while installing %s, exiting with 127 \\n" "$PACKAGE_NAME"
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

	printf -- "Detected %s \\n" "$PRETTY_NAME"
	printf -- "Request details : PACKAGE NAME= %s , VERSION= %s \\n" "$PACKAGE_NAME" "$PACKAGE_VERSION" | tee -a "$LOG_FILE"
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
	printf -- '\\n***************************************************************************************\n'
	printf -- "Getting Started: \\n"
	printf -- "To run grafana , run the following command : \\n"
	printf -- "    grafana-server -homepath /usr/local/share/grafana -config /etc/grafana/grafana.ini &   (Run in background)  \\n"
	printf -- "\\nAccess grafana UI using the below link : "
	printf -- "http://<host-ip>:<port>/    [Default port = 3000] \\n"
	printf -- '***************************************************************************************\n'
	printf -- '\\n'
}

###############################################################################################################

logDetails
prepare #Check Prequisites

DISTRO="$ID-$VERSION_ID"
case "$DISTRO" in
"ubuntu-16.04" | "ubuntu-18.04")
	printf -- "Installing %s %s for %s \\n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	sudo apt-get -qq update
	sudo apt-get install -y -qq python build-essential gcc tar wget git make unzip curl >/dev/null
	configureAndInstall
	;;

"rhel-7.3" | "rhel-7.4" | "rhel-7.5")
	printf -- "Installing %s %s for %s \\n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	sudo yum install -y -q make gcc tar wget git unzip curl >/dev/null
	configureAndInstall
	;;

"sles-12.3" | "sles-15")
	printf -- "Installing %s %s for %s \\n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	sudo zypper -q install -y make gcc wget tar git unzip curl >/dev/null
	configureAndInstall
	;;

*)
	printf -- "%s not supported \\n" "$DISTRO" | tee -a "$LOG_FILE"
	exit 1
	;;
esac

printSummary
