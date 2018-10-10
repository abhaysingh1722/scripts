#!/bin/bash
# © Copyright IBM Corporation 2017, 2018.
# LICENSE: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)

set -e

PACKAGE_NAME="cadvisor"
PACKAGE_VERSION="0.27.4"
CURDIR="$(pwd)"
GO_DEFAULT="$HOME/go"

LOG_FILE="${CURDIR}/${PACKAGE_NAME}-${PACKAGE_VERSION}-$(date +"%F-%T").log"
OVERRIDE=false

trap cleanup 0 1 2 ERR

# Need handling for RHEL 6.10 as it doesn't have os-release file
if [ -f "/etc/os-release" ]; then
	source "/etc/os-release"
else
  cat /etc/redhat-release >> "${LOG_FILE}"
	export ID="rhel"
  export VERSION_ID="6.x"
  export PRETTY_NAME="Red Hat Enterprise Linux 6.x"
fi

function checkPrequisites() {
 if ( [[ "$(command -v sudo)" ]] )
        then
                 printf -- 'Sudo : Yes\n';
        else
                 printf -- 'Sudo : No \n';
                 printf -- 'You can install the same from installing sudo from repository using apt, yum or zypper based on your distro. \n';
    exit 1;
  fi;


	# Ask user for prerequisite installation
printf -- "\n\n Installation requires GO:1.10.1 as Prequisite\n";
while true; do
    read -p "Do you wish to continue installing GO 1.10.1?" yn
    case $yn in
        [Yy]* ) printf -- 'Selected Yes for prerequisite installation \n\n' | tee -a "$LOG_FILE"; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

}

function cleanup() {
	# Remove artifacts
	rm -rf ${GOPATH}/src/github.com/google/cadvisor
	printf -- 'Cleaned up the artifacts\n' >>"$LOG_FILE"
}

function configureAndInstall() {
	printf -- 'Configuration and Installation started \n'

	if [[ "${OVERRIDE}" == "true" ]]; then
		printf -- 'cAdvisor exists on the system. Override flag is set to true hence updating the same\n ' | tee -a "$LOG_FILE"
	fi

	    # Install go
		printf -- "Installing Go... \n" | tee -a "$LOG_FILE"
        curl https://raw.githubusercontent.com/imdurgadas/scripts/master/Go/install.sh | bash

	  
       
		# Install cAdvisor
		printf -- 'Installing cAdvisor..... \n'
        
		# Set GOPATH if not already set
		if [[ -z "${GOPATH}" ]]; then
		printf -- "Setting default value for GOPATH \n" >>"$LOG_FILE"
			
        #Check if go directory exists
         if [ ! -d $HOME/go ]; then
               mkdir $HOME/go
         fi

        #mkdir $HOME/go
        export GOPATH="${GO_DEFAULT}"

		export PATH=$PATH:$GOPATH/bin
		else
		printf -- "GOPATH already set \n" >>"$LOG_FILE"
		fi
		
		printenv 
		
		#  Install godep tool
		cd ${GOPATH}
		go get github.com/tools/godep
		printf -- 'Installed godep tool at GOPATH \n' >>"$LOG_FILE"

		# Checkout the code from repository
		mkdir -p ${GOPATH}/src/github.com/google
		cd ${GOPATH}/src/github.com/google
		git clone https://github.com/google/cadvisor.git
		cd cadvisor
		git checkout "v${PACKAGE_VERSION}"
		printf -- 'Cloned the cadvisor code \n' >>"$LOG_FILE"

        cd "${CURDIR}"
		# get config file (NEED TO REPLACE WITH LINK OF ORIGINAL REPO)
		wget https://raw.githubusercontent.com/sid226/scripts/master/CAdvisor/files/crc32.go

		# Replace the crc32.go file
		cp crc32.go ${GOPATH}/src/github.com/google/cadvisor/vendor/github.com/klauspost/crc32/

		# Build cAdvisor
		cd ${GOPATH}/src/github.com/google/cadvisor
		godep go build .
		
		# Add cadvisor to /usr/bin
		 cp ${GOPATH}/src/github.com/google/cadvisor/cadvisor  /usr/bin/
	
		printf -- 'Build cAdvisor successfully \n' >>"$LOG_FILE"
		
		#Verify cadvisor installation
		
	    if ( [[ "$(command -v $PACKAGE_NAME)" ]]); then
		
         printf -- " %s Installation verified... continue with cadvisor installation...\n" "$PACKAGE_NAME" | tee -a "$LOG_FILE"
      
         else
			printf -- "Error while installing %s, exiting with 127 \n" "$PACKAGE_NAME";
			exit 127;
		fi
}

function logDetails() {
	printf -- '**************************** SYSTEM DETAILS *************************************************************\n' >"$LOG_FILE"
	cat "/etc/os-release" >>"$LOG_FILE"
	cat /proc/version >>"$LOG_FILE"
	printf -- '*********************************************************************************************************\n' >>"$LOG_FILE"

	printf -- "Detected %s \n" "$PRETTY_NAME"
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

while getopts "h?sdopv:" opt; do
	case "$opt" in
	h | \?)
		printHelp
		exit 0
		;;
	s)
		stty -echo
		trap error_handle INT
		trap error_handle TERM
		trap error_handle EXIT
		;;
	d)
		set -x
		;;
	v)
		PACKAGE_VERSION="$OPTARG"
		;;
	o)
		OVERRIDE=true
		;;
	p)
		checkPrequisites
		;;
	esac
done

function printSummary() {
	printf 'Execute command : '
	# tips
	printf -- "\n\nTips: \n"
	printf -- "\nRunning Cadvisor: \n"
	printf -- "\n cadvisor  \n"
	printf -- "\n\nAccess cAdvisor web user interface from browser \n"
	printf -- "\nhttp://<host-ip>:8080/ \n"
	printf -- '\n'
}

###############################################################################################################

logDetails
checkPrequisites #Check Prequisites

DISTRO="$ID-$VERSION_ID"
case "$DISTRO" in
"ubuntu-16.04" | "ubuntu-18.04")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	sudo apt-get update
	sudo apt-get install -y wget git libseccomp-dev curl
	configureAndInstall
	;;

"rhel-7.3" | "rhel-7.4" | "rhel-7.5")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	sudo yum install -y wget git libseccomp-devel
	configureAndInstall
	;;

"sles-12.3" | "sles-15")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	sudo zypper install -y git libseccomp-devel wget tar curl gcc
	configureAndInstall
	;;

*)
	printf -- "%s not supported \n" "$DISTRO" | tee -a "$LOG_FILE"
	exit 1
	;;
esac

# Print Summary
printSummary