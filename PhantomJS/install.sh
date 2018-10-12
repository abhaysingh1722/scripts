#!/bin/bash
# © Copyright IBM Corporation 2017, 2018.
# LICENSE: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)

set -e

PACKAGE_NAME="phantomjs"
PACKAGE_VERSION="2.1.1"
CURDIR="$(pwd)"
LOG_FILE="${CURDIR}/${PACKAGE_NAME}-${PACKAGE_VERSION}-$(date +"%F-%T").log"
FORCE="false"
BUILD_DIR="/usr/local"
CONF_URL="https://raw.githubusercontent.com/sid226/scripts/master/PhantomJS/files"

trap "" 1 2 ERR

# Need handling for RHEL 6.10 as it  doesn't have os-release file
if [ -f "/etc/os-release" ]; then
	source "/etc/os-release"
else
	cat /etc/redhat-release >>"${LOG_FILE}"
	export ID="rhel"
	export VERSION_ID="6.x"
	export PRETTY_NAME="Red Hat Enterprise Linux 6.x"
fi

function checkPrequisites() {
	# Check Sudo exist
	if command -v "sudo" >/dev/null; then
		printf -- 'Sudo : Yes\n'
	else
		printf -- 'Sudo : No \n'
		printf -- 'You can install the same from installing sudo from repository using apt, yum or zypper based on your distro. \n'
		exit 1
	fi

  if [[ "$FORCE" == "true" ]] ;
    then
      printf -- 'Force attribute provided hence continuing with install without confirmation message' | tee -a "$LOG_FILE"
    else
      # Ask user for prerequisite installation
      printf -- "\n\nAs part of the installation , some package dependencies will be installed, \n";
      while true; do
          read -r -p "Do you want to continue (y/n) ? :  " yn
          case $yn in
              [Yy]* ) printf -- 'User responded with Yes. \n' | tee -a "$LOG_FILE"; 
            break;;
              [Nn]* ) exit;;
              * ) 	echo "Please provide confirmation to proceed.";;
          esac
      done
    fi	

}

function cleanup() {
	rm -rf "${BUILD_DIR}/openssl"
	rm -rf "${BUILD_DIR}/curl"
	rm -rf "${BUILD_DIR}/curl/mk-ca-bundle.pl"
	rm -rf "${BUILD_DIR}/phantomjs"
	printf -- 'Cleaned up the artifacts\n' >>"$LOG_FILE"

}

function configureAndInstall() {
	printf -- 'Configuration and Installation started \n'

	if [[ "${VERSION_ID}" == "15" ]]; then
		# Build OpenSSL 1.0.2
		cd "$BUILD_DIR"
		git clone -q -b OpenSSL_1_0_2l git://github.com/openssl/openssl.git
		cd openssl
		./config --prefix=/usr --openssldir=/usr/local/openssl shared
		make
		sudo make install

		# Build cURL 7.52.1
		cd "$BUILD_DIR"
		git clone -q -b curl-7_52_1 git://github.com/curl/curl.git
		cd curl
		./buildconf
		./configure --prefix=/usr/local --with-ssl --disable-shared
		make && sudo make install
		export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib64
		export PATH=/usr/local/bin:$PATH
		printf -- 'Build cURL success\n' >>"$LOG_FILE"

		# Generate ca-bundle.crt for curl
		echo insecure >>$HOME/.curlrc
		wget -q https://raw.githubusercontent.com/curl/curl/curl-7_53_0/lib/mk-ca-bundle.pl
		perl mk-ca-bundle.pl -k
		export SSL_CERT_FILE=$(pwd)/ca-bundle.crt
		rm $HOME/.curlrc

		printf -- 'Build OpenSSL success\n' >>"$LOG_FILE"

	fi

	# Install Phantomjs
	cd "$BUILD_DIR"
  git clone -q -b "${PACKAGE_VERSION}" git://github.com/ariya/phantomjs.git
	cd phantomjs
	git submodule init
	git submodule update
	printf -- 'Clone Phantomjs repo success\n' >>"$LOG_FILE"
	# Download  JSStringRef.h
	if [[ "${VERSION_ID}" == "15" ]]; 
  then
		# get config file
		wget -q $CONF_URL/JSStringRef.h
		# replace config file
		cp JSStringRef.h "${BUILD_DIR}/phantomjs/src/qt/qtwebkit/Source/JavaScriptCore/API/JSStringRef.h"
		printf -- 'Updated JSStringRef.h for sles-15 \n' >>"$LOG_FILE"
	fi

	# Build Phantomjs
	python build.py
	printf -- 'Build Phantomjs success \n' >>"$LOG_FILE"

	# Add Phantomjs to /usr/bin
	cp "${BUILD_DIR}/phantomjs/bin/phantomjs" /usr/bin/
	printf -- 'Add Phantomjs to /usr/bin success \n' >>"$LOG_FILE"

	#Clean up 
	cleanup

	#Verify if phantomjs is configured correctly
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

	printf -- "\n\nUsage: \n"
	printf -- "\n\nTo run PhantomJS , run the following command: \n"
	printf -- "\n\nFor Ubuntu: \n"
	printf -- "\n\n  export QT_QPA_PLATFORM=offscreen \n"
	printf -- "    phantomjs &   (Run in background)  \n"
	printf -- '\n'
}

###############################################################################################################
function verify_repo_install() {
  #Verify if package is configured correctly
	if command -v "$PACKAGE_NAME" >/dev/null; then
		printf -- "%s installation completed. Please check the Usage to start the service.\n" "$PACKAGE_NAME" | tee -a "$LOG_FILE"
	else
		printf -- "Error while installing %s, exiting with 127 \n" "$PACKAGE_NAME"
		exit 127
	fi
}


logDetails
checkPrequisites #Check Prequisites

DISTRO="$ID-$VERSION_ID"
case "$DISTRO" in
"ubuntu-16.04" | "ubuntu-18.04")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	sudo apt-get update >/dev/null

	printf -- 'Installing the PhantomJS from repository \n' | tee -a "$LOG_FILE"
	sudo sudo apt-get install -y -qq phantomjs >/dev/null
	verify_repo_install
	;;

"rhel-7.3" | "rhel-7.4" | "rhel-7.5")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	printf -- 'Installing the dependencies for PhantomJS from repository \n' | tee -a "$LOG_FILE"
	sudo yum -y -q install gcc gcc-c++ make flex bison gperf ruby openssl-devel freetype-devel fontconfig-devel libicu-devel sqlite-devel libpng-devel libjpeg-devel libXfont.s390x libXfont-devel.s390x xorg-x11-utils.s390x xorg-x11-font-utils.s390x tzdata.noarch tzdata-java.noarch xorg-x11-fonts-Type1.noarch xorg-x11-font-utils.s390x python python-setuptools git wget tar >/dev/null
	configureAndInstall
	;;

"sles-12.3" | "sles-15")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	printf -- 'Installing the dependencies for PhantomJS from repository \n' | tee -a "$LOG_FILE"

	if [[ "${VERSION_ID}" == "12.3" ]]; then
		sudo zypper install -y -q gcc gcc-c++ make flex bison gperf ruby openssl-devel freetype-devel fontconfig-devel libicu-devel sqlite-devel libpng-devel libjpeg-devel python-setuptools git xorg-x11-devel xorg-x11-essentials xorg-x11-fonts xorg-x11 xorg-x11-util-devel libXfont-devel libXfont1 python python-setuptools >/dev/null
		printf -- 'Install dependencies for sles-12.3 success \n' >>"$LOG_FILE"
	else
		sudo zypper install -y -q gcc gcc-c++ make flex bison gperf ruby freetype2-devel fontconfig-devel libicu-devel sqlite3-devel libpng16-compat-devel libjpeg8-devel python2 python2-setuptools git xorg-x11-devel xorg-x11-essentials xorg-x11-fonts xorg-x11 xorg-x11-util-devel libXfont-devel libXfont1 autoconf automake libtool >/dev/null
		printf -- 'Install dependencies for sles-15 success \n' >>"$LOG_FILE"
	fi

	configureAndInstall
	;;

*)
	printf -- "%s not supported \n" "$DISTRO" | tee -a "$LOG_FILE"
	exit 1
	;;
esac

printSummary
