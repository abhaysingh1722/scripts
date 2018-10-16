#!/bin/bash
# © Copyright IBM Corporation 2017, 2018.
# LICENSE: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)

set -e

PACKAGE_NAME="glusterfs"
PACKAGE_VERSION="4.0.2"
CURDIR="$(pwd)"
REPO_URL="https://raw.githubusercontent.com/prankkelkar/scripts/master/glusterfs/patch"
GLUSTER_REPO_URL="https://github.com/gluster/glusterfs"
LOG_FILE="$CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-$(date +"%F-%T").log"
TEST_USER="$(whoami)"
FORCE="false"

trap cleanup 0 1 2 ERR

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

	if [[ "${TEST_USER}" != "root" ]]; then
		printf -- 'Cannot run GlusterFS as non-root . Please switch to superuser\n\n\n' | tee -a "$LOG_FILE"
		exit 1
	fi

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
		printf -- '\nFollowing packages are needed before going ahead\n' | tee -a "$LOG_FILE"
		printf -- 'URCU\n\n' | tee -a "$LOG_FILE"
		printf -- 'thin-provisioning-tools\n\n' | tee -a "$LOG_FILE"
		printf -- '\nBuild might take some time.Sit back and relax\n' | tee -a "$LOG_FILE"
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
	# rm -rf "${CURDIR}/GlusterFS.yml"
	# rm -rf "${CURDIR}/jvm.options"
	# rm -rf "${CURDIR}/GlusterFS"
	# rm -rf "${CURDIR}/OpenJDK10_s390x_Linux_jdk-10.0.2.13.tar.gz"

	printf -- '\nCleaned up the artifacts\n' >>"$LOG_FILE"
}

function configureAndInstall() {
	printf -- '\nConfiguration and Installation started \n' | tee -a "$LOG_FILE"

	#Installing dependencies
	printf -- 'User responded with Yes. \n' | tee -a "$LOG_FILE"
	printf -- 'Building dependencies\n' | tee -a "$LOG_FILE"

	cd "${CURDIR}"

	#only for sles and rhel
	if [[ "${ID}" != "ubuntu" ]]; then
		printf -- 'Building URCU\n' | tee -a "$LOG_FILE"
		git clone -q git://git.liburcu.org/userspace-rcu.git
		cd userspace-rcu
		./bootstrap 
		./configure
		make
		make install
		ldconfig
	fi

	printf -- 'URCU installed successfully\n' | tee -a "$LOG_FILE"
	
	cd "${CURDIR}"

	#only for rhel
	if [[ "${ID}" == "rhel" ]]; then
		printf -- 'Building thin-provisioning-tools\n' | tee -a "$LOG_FILE"
		git clone https://github.com/jthornber/thin-provisioning-tools
		cd thin-provisioning-tools
		autoreconf
		./configure
		make
		make install
	fi
	
	printf -- 'thin-provisioning-tools installed\n' | tee -a "$LOG_FILE"

	cd "${CURDIR}"

	printenv >>"$LOG_FILE"

	# Download and configure GlusterFS
	printf -- '\nDownloading GlusterFS. Please wait.\n' | tee -a "$LOG_FILE"
	git clone -q -b v$PACKAGE_VERSION $GLUSTER_REPO_URL
	sleep 2
	./autogen.sh
	if [[ "${ID}" == "sles" ]]; then
		./configure --enable-gnfs --disable-events # for SLES
	else
		./configure --enable-gnfs # for RHEL and Ubuntu
	fi

	./autogen.sh
	./configure --enable-gnfs

	if [[ "${ID}" == "rhel" ]]; then
		rm contrib/userspace-rcu/rculist-extra.h
		cp /usr/local/include/urcu/rculist.h contrib/userspace-rcu/rculist-extra.h
	else
		#Patch to be applied here
		wget -q $REPO_URL/patch.diff
	    patch "${CURDIR}/glusterfs/xlators/performance/io-threads/src/io-threads.h" patch.diff
	fi

	#Build GlusterFS
	printf -- '\nBuilding GlusterFS \n' | tee -a "$LOG_FILE"
	printf -- '\nBuild might take some time.Sit back and relax\n' | tee -a "$LOG_FILE"
	cd "${CURDIR}/glusterfs"
	make
	make install
	printf -- 'Built GlusterFS successfully \n\n' | tee -a "$LOG_FILE"

	if [[ "$(cat .bashrc | grep -q LD_LIBRARY_PATH)" ]]; then
		printf -- '\nChanging LD_LIBRARY_PATH\n' | tee -a "$LOG_FILE"
		sed -n 's/^.*\bLD_LIBRARY_PATH\b.*$/export LD_LIBRARY_PATH=\/usr\/local\/lib:$LD_LIBRARY_PATH\/p' .bashrc | tee -a "$LOG_FILE"

	else
		echo "export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH" >>.bashrc
	fi

	ldconfig
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
	printf -- '\n\nSet LD_LIBRARY_PATH to start using GlusterFS right away.' | tee -a "$LOG_FILE"
	printf -- '\nLD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH\n' | tee -a "$LOG_FILE"
	printf -- '\nOr restart the session to Configure the changes automatically' | tee -a "$LOG_FILE"
	printf -- '\nFor more information on curator client visit https://www.elastic.co/guide/en/GlusterFS/client/curator/current/index.html \n\n' | tee -a "$LOG_FILE"
}

logDetails
#checkPrequisites #Check Prequisites

DISTRO="$ID-$VERSION_ID"
case "$DISTRO" in
"ubuntu-16.04" | "ubuntu-18.04")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	printf -- '\nInstalling dependencies \n' | tee -a "$LOG_FILE"
	prepare
	sudo apt-get update >/dev/null
	sudo apt-get install -y -qq make automake autoconf libtool flex bison pkg-config libssl-dev libxml2-dev python-dev libaio-dev libibverbs-dev librdmacm-dev libreadline-dev liblvm2-dev libglib2.0-dev liburcu-dev libcmocka-dev libsqlite3-dev libacl1-dev wget tar dbench git xfsprogs attr nfs-common yajl-tools sqlite3 libxml2-utils thin-provisioning-tools bc >/dev/null
	configureAndInstall
	;;

"rhel-7.3" | "rhel-7.4" | "rhel-7.5")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	printf -- '\nInstalling dependencies \n' | tee -a "$LOG_FILE"
	prepare
	sudo yum install -y -q wget git make gcc-c++ libaio-devel boost-devel expat-devel autoconf autoheader automake libtool flex bison openssl-devel libacl-devel sqlite-devel libxml2-devel python-devel python attr yajl nfs-utils xfsprogs popt-static sysvinit-tools psmisc libibverbs-devel librdmacm-devel readline-devel lvm2-devel glib2-devel fuse-devel bc >/dev/null
	configureAndInstall

	;;

"sles-12.3" | "sles-15")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
	printf -- '\nInstalling dependencies \n' | tee -a "$LOG_FILE"
	prepare
	sudo zypper --non-interactive install -q wget which git make gcc-c++ libaio-devel boost-devel autoconf automake cmake libtool flex bison lvm2-devel libacl-devel python-devel python attr xfsprogs sysvinit-tools psmisc bc libopenssl-devel libxml2-devel sqlite3 sqlite3-devel popt-devel nfs-utils libyajl2 python-xml net-tools >/dev/null
	configureAndInstall

	;;

*)
	printf -- "%s not supported \n" "$DISTRO" | tee -a "$LOG_FILE"
	exit 1
	;;
esac

# Print Summary
printSummary

