        #!/bin/bash
        # © Copyright IBM Corporation 2017, 2018.
        # LICENSE: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)

        set -e

        PACKAGE_NAME="etcd"
        PACKAGE_VERSION="3.3.8"
        CURDIR="$(pwd)"
        GO_URL="https://raw.githubusercontent.com/imdurgadas/scripts/master/Go/install.sh"
        FORCE="false"
        LOG_FILE="$CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-$(date +"%F-%T").log"
        trap cleanup 0 1 2 ERR

        # Need handling for RHEL 6.10 as it doesn't have os-release file
        if [ -f "/etc/os-release" ];then
                source "/etc/os-release"
            else
                    cat /etc/redhat-release >> "${LOG_FILE}"
                    export ID="rhel"
                    export VERSION_ID="6.x"
                    export PRETTY_NAME="Red Hat Enterprise Linux 6.x"
        fi

        function prepare() {
        if  command -v "sudo" > /dev/null ;
        then
            printf -- 'Sudo : Yes\n' >> "$LOG_FILE"
        else
            printf -- 'Sudo : No \n' >> "$LOG_FILE"
            printf -- 'You can install the same from installing sudo from repository using apt, yum or zypper based on your distro. \n';
    	    exit 1;
  	    fi;
           
        if command -v "go" > /dev/null
        then
            printf -- "Go : Yes \n";
        else
            printf -- "Go : No \n";
            printf -- "This setup includes installation of Go.\n";
        fi

        if command -v $PACKAGE_NAME > /dev/null;
        then
            printf -- "%s : Yes \n" "$PACKAGE_NAME" | tee -a  "$LOG_FILE"
            printf -- "\nYou already have the package installed on ur system.\n"

        else
            printf -- "%s : No \n" "$PACKAGE_NAME" ;
            printf -- 'Package not present on system \n\n'

        fi;

        if [[ "$FORCE" == "true" ]] ;
	    then
		printf -- 'Force attribute provided hence continuing with install without confirmation message' | tee -a "$LOG_FILE"
	    else
		    # Ask user for prerequisite installation
		    printf -- "\n\nAs part of the installation , Go 1.10.1 will be installed, \n";
		    while true; do
    		    read -r -p "Do you want to continue (y/n) ? :  " yn
    		    case $yn in
      	 		    [Yy]* ) printf -- 'User responded with Yes. \n' | tee -a "$LOG_FILE"; 
					break;;
        		    [Nn]* ) exit;;
        		    *) 	echo "Please provide confirmation to proceed.";;
   		 	    esac
		    done
	    fi	
        }

        function cleanup() {
            # Remove artifacts
            rm -rf ${GOPATH}/src/github.com/coreos/etcd
            printf -- "Cleaned up the artifacts\n" >>$LOG_FILE
        }

        function configureAndInstall() {
         printf -- "Configuration and Installation started \n"

         #GO Installation
         printf -- "\n\n Installing Go \n" | tee -a "$LOG_FILE"
         curl $GO_URL | bash
        
        # Install etcd
        printf -- 'Installing etcd..... \n'
                
        # Set GOPATH if not already set
        if [[ -z "${GOPATH}" ]];then
            printf -- "Setting default value for GOPATH \n" >>"$LOG_FILE"
            
            #Check if directory exsists
            if [ ! -d $HOME/go ];then
                 mkdir "$HOME/go"
            fi
            export GOPATH="$HOME/go"
            export PATH=$PATH:$GOPATH/bin
            else
                printf -- "GOPATH already set : Value : %s \n" "$GOPATH" >>"$LOG_FILE"
        fi
        printenv >> "$LOG_FILE"

        #ETCD_DATA_DIR path
        if [[ -z "${ETCD_DATA_DIR}" ]]; then
            printf -- "Setting default value for ETCD \n" >>"$LOG_FILE"
            if [ ! -d $GOPATH/etcd ];
            then
                mkdir -p /$GOPATH/etcd
            fi
                export ETCD_DATA_DIR=/$GOPATH/etcd
            else
                printf -- "ETCD_DATA_DIR already set \n" >>"$LOG_FILE"
        fi

        printenv >> "$LOG_FILE"

        # Checkout the code from repository
        cd ${GOPATH}
        mkdir -p /${GOPATH}/src/github.com/coreos
        cd /${GOPATH}/src/github.com/coreos
        printf -- 'Cloning etcd code \n' >> "$LOG_FILE"
        git clone -b "v${PACKAGE_VERSION}" -q git://github.com/coreos/etcd
        
        #git checkout "v${PACKAGE_VERSION}"
        printf -- 'Cloned the etcd code \n' >>"$LOG_FILE"

        # Build etcd
        printf -- "\nBuilding etcd\n"
        cd etcd
        ./build
                
        # Add etcd to /usr/bin
        cp "${GOPATH}/src/github.com/coreos/etcd/bin/etcd" /usr/bin/            
        printf -- 'Build etcd successfully \n' >>"$LOG_FILE"
	
	#Cleanup
	cleanup

        #Verify etcd installation
        if command -v "$PACKAGE_NAME" > /dev/null; then 
                printf -- " %s Installation verified... continue with etcd installation...\n" "$PACKAGE_NAME" | tee -a "$LOG_FILE"
            else
                printf -- "Error while installing %s, exiting with 127 \n" "$PACKAGE_NAME";
                exit 127;
        fi
        }

        function logDetails() {
            printf -- '**************************** SYSTEM DETAILS *************************************************************\n' >"$LOG_FILE"
            if [ -f "/etc/os-release" ]; then
	            cat "/etc/os-release" >> "$LOG_FILE"
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
            echo " install.sh  [-d <debug>] [-v package-version] [-y install-without-confirmation]"
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
                exit 0
                ;;
            esac
        done

        function printSummary() {
            printf -- '\n***************************************************************************************\n'
            printf -- "\n\n* Getting Started * \n"
            printf -- "\nRunning etcd: \n"
            printf -- " etcd  \n\n"
            printf -- "In case of error etcdmain: etcd on unsupported platform without ETCD_UNSUPPORTED_ARCH=s390x, set following\n"
	    printf -- "export ETCD_UNSUPPORTED_ARCH=s390x \n"
            printf -- "This will bring up etcd listening on port 2379 for client communication and on port 2380 for server-to-server communication.\n"
            printf -- "Next, let's set a single key, and then retrieve it:"
            printf -- "     curl -L http://127.0.0.1:2379/v2/keys/mykey -XPUT -d value='this is awesome' \n"
            printf -- "     curl -L http://127.0.0.1:2379/v2/keys/mykey \n"
            printf -- "You have successfully started etcd and written a key to the store.\n"
	    printf -- '***************************************************************************************\n'
        }
        
        logDetails
        prepare #Check Prequisites

        DISTRO="$ID-$VERSION_ID"
        case "$DISTRO" in
        "ubuntu-16.04" | "ubuntu-18.04")
            printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
            sudo apt-get update
            sudo apt-get install -qq git curl wget tar gcc > /dev/null
            configureAndInstall
            ;;

        "rhel-7.3" | "rhel-7.4" | "rhel-7.5")
            printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
            sudo yum install -y -q curl git wget tar gcc which > /dev/null
            configureAndInstall
            ;;

        "sles-12.3" | "sles-15")
            printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
            sudo zypper install -y -q curl git wget tar gcc which
            configureAndInstall
            ;;

        *)
            printf -- "%s not supported \n" "$DISTRO" | tee -a "$LOG_FILE"
            exit 1
            ;;
        esac

        # Print Summary
        printSummary
