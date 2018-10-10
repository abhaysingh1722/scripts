#!/bin/bash
# © Copyright IBM Corporation 2017, 2018.
# LICENSE: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)

set -e

PACKAGE_NAME="etcd"
PACKAGE_VERSION="3.3.8"
CURDIR="$(pwd)"
LOG_FILE="$CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-$(date +"%F-%T").log"

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
                 printf -- 'You can install the same from repository using apt, yum or zypper based on your distro. \n';
    exit 1;
  fi;
  
  if ( [[ "$(command -v go)" ]])
        then
            printf -- "Go : Yes \n";
        else
            printf -- "Go : No \n";
            printf -- "This setup includes installation of Go.\n";
    fi

	if ( [[ "$(command -v $PACKAGE_NAME)" ]])
         then
		printf -- "%s : Yes \n" "$PACKAGE_NAME" | tee -a  "$LOG_FILE"
    printf -- "\nYou already have the package installed on ur system.\n"

	 else
     printf -- "%s : No \n" "$PACKAGE_NAME" ;
     printf -- 'Package not present on system \n\n'

  fi;
}

function cleanup() {
	# Remove artifacts
	rm -rf ${GOPATH}/src/github.com/coreos/etcd
	printf -- 'Cleaned up the artifacts\n' >>$LOG_FILE
}

function configureAndInstall() {
	printf -- 'Configuration and Installation started \n'

	# Check if Go installed
	if ( [[ "$(command -v go)" ]])
         then
		
         printf -- "GO Installation verified... continue with etcd installation...\n" | tee -a "$LOG_FILE"
      
        else
	    # Install go
        printf -- "\n\n\n Installing go \n\n"
        curl https://raw.githubusercontent.com/imdurgadas/scripts/master/Go/install.sh | bash
	 fi
	  
       
		# Install etcd
		printf -- 'Installing etcd..... \n'
        
		# Set GOPATH if not already set
		if [[ -z "${GOPATH}" ]]; then
		printf -- "Setting default value for GOPATH \n" >>"$LOG_FILE"
		mkdir $HOME/go
		export GOPATH="$HOME/go"
		export PATH=$PATH:$GOPATH/bin
		else
		printf -- "GOPATH already set \n" >>"$LOG_FILE"
		fi
		
        #ETCD_DATA_DIR path
        if [[ -z "${ETCD_DATA_DIR}" ]]; then
		 printf -- "Setting default value for ETCD \n" >>"$LOG_FILE"
	     mkdir -p /$GOPATH/etcd_temp
         export ETCD_DATA_DIR=/$GOPATH/etcd_temp
		else
		printf -- "ETCD_DATA_DIR already set \n" >>"$LOG_FILE"
		fi

		# Checkout the code from repository
		cd ${GOPATH}
		mkdir -p /${GOPATH}/src/github.com/coreos
        cd /${GOPATH}/src/github.com/coreos
		git clone git://github.com/coreos/etcd
        cd etcd
		git checkout "v${PACKAGE_VERSION}"
		printf -- 'Cloned the etcd code \n' >>"$LOG_FILE"

        #cd "${CURDIR}"


		# Build etcd
	
        printf -- "\n******************BUILDING*******************\n"
		
        ./build
		
		# Add etcd to /usr/bin
       	cp ${GOPATH}/src/github.com/coreos/etcd/bin/etcd /usr/bin/
	
	
    	printf -- 'Build etcd successfully \n' >>"$LOG_FILE"
		
		#Verify etcd installation
		 if ( [[ "$(command -v $PACKAGE_NAME)" ]]); then
		printf -- " %s Installation verified... continue with etcd installation...\n" "$PACKAGE_NAME" | tee -a "$LOG_FILE"
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
	p)
		checkPrequisites
        exit 0
		;;
	esac
done

function printSummary() {
	# tips
	printf -- "\n\n* Tips * \n"
	printf -- "\nRunning etcd: \n"
	printf -- " etcd  \n"
	printf -- "\n\n****\nNote: In case of error etcdmain : \n etcd on unsupported platform without 'ETCD_UNSUPPORTED_ARCH=s390x set' \n set following environment variable and rerun the command:
                export  ETCD_UNSUPPORTED_ARCH=s390x \n"
	printf -- "\nThis will bring up etcd listening on port 2379 for client communication and on port 2380 for server-to-server communication. \n"
	printf -- '****\n'
}

###############################################################################################################

logDetails
#checkPrequisites #Check Prequisites


while true; do
    printf -- "Do you wish to install this program : %s""$PACKAGE_NAME""\n"
    read -p "It requires installation of Go wich will be overidden if already exsisting [yn] :" yn
    case $yn in
        [Yy]* ) printf -- " Selected Yes for prerequisite installation. The installation will proceed. \n\n" | tee -a "$LOG_FILE"; break;;
        [Nn]* ) printf -- "**************** \n\nThe installation was Aborted. \n\n****************\n"  | tee -a "$LOG_FILE" ;
                    
                 exit 0 ;;
        * ) echo "Please answer yes or no.[y/n]";;
    esac
done

DISTRO="$ID-$VERSION_ID"
case "$DISTRO" in
"ubuntu-16.04" | "ubuntu-18.04")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	sudo apt-get update
    sudo apt-get install git curl wget tar gcc
	configureAndInstall
	;;

"rhel-7.3" | "rhel-7.4" | "rhel-7.5")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	sudo yum install curl git wget tar gcc which
	configureAndInstall
	;;

"sles-12.3" | "sles-15")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	sudo zypper install curl git wget tar gcc which
	configureAndInstall
	;;

*)
	printf -- "%s not supported \n" "$DISTRO" | tee -a "$LOG_FILE"
	exit 1
	;;
esac

# Print Summary
printSummary
