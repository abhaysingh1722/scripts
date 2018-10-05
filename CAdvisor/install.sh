#!/bin/bash
# © Copyright IBM Corporation 2017, 2018.
# LICENSE: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)

set -e

PACKAGE_NAME="cadvisor"
PACKAGE_VERSION="0.27.4"
LOG_FILE="${PACKAGE_NAME}-${PACKAGE_VERSION}-$(date +"%F-%T").log"
OVERRIDE=false

trap cleanup 0 1 2 ERR

source "/etc/os-release"

function error_handle() {
  stty echo;
}


function checkPrequisites()
{
  _=$(command -v sudo);
  if [ "$?" != "0" ]; 
  then
    printf -- 'You dont seem to have sudo installed. \n';
    printf -- 'You can install the same from installing sudo from repository using apt, yum or zypper based on your distro. \n';
    exit 1;
  fi;

  if ( [[ "$(command -v cadvisor)" ]] )
  then
    printf -- "You already have %s installed. \n" "$PACKAGE_NAME" | tee -a  "$LOG_FILE"

    if cadvisor --version | grep -q "$PACKAGE_VERSION" 
    then
      printf -- "Version detected: %s \n" "${PACKAGE_VERSION}" | tee -a  "$LOG_FILE"
      printf -- "Not installing as requested version already installed. \n" | tee -a  "$LOG_FILE"
      exit 1;
    else
      printf -- "You have %s installed but not the requested version %s. \n" "${PACKAGE_NAME}" "${PACKAGE_VERSION}" | tee -a  "$LOG_FILE"
      if [[ $OVERRIDE ]]
      then
        printf -- 'Override (-o) flag is set \n' | tee -a  "$LOG_FILE"
        exit 0;
      fi
      exit 1
    fi
    exit 1;
  fi;
}

function cleanup()
{
  rm -rf "*.tar.gz"
  printf -- 'Cleaned up the artifacts\n'  >> "$LOG_FILE"
}

function configureAndInstall()
{
  printf -- 'Configuration and Installation started \n'

  if [[ "${OVERRIDE}" == "true" ]]
  then
    printf -- 'cAdvisor exists on the system. Override flag is set to true hence updating the same\n ' | tee -a "$LOG_FILE"
  fi

  # Install cAdvisor
 

  #Verify if cAdvisor is configured correctly
  
}

function logDetails()
{
    printf -- '**************************** SYSTEM DETAILS *************************************************************\n' > "$LOG_FILE";
    cat "/etc/os-release" >> "$LOG_FILE"
    cat /proc/version >> "$LOG_FILE"
    printf -- '*********************************************************************************************************\n' >> "$LOG_FILE";

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
    stty -echo;
    trap error_handle INT;
    trap error_handle TERM;
    trap error_handle EXIT;
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

function printSummary()
{
  printf 'Execute command : '
 # tips
  printf -- "\n\nTips: \n"
  printf -- '\n'
}

###############################################################################################################

logDetails
checkPrequisites  #Check Prequisites

DISTRO="$ID-$VERSION_ID"
case "$DISTRO" in
"ubuntu-16.04" | "ubuntu-18.04")
  printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
  sudo apt-get update

  if [[ "${VERSION_ID}" == "18.04" ]] 
  then
    printf -- 'Detected 18.04 version hence installing from repository \n' | tee -a "$LOG_FILE"
    sudo apt install -y "$PACKAGE_NAME"="$PACKAGE_VERSION" |  tee -a >> "$LOG_FILE"
  else
    sudo apt-get install git libseccomp-dev curl
    configureAndInstall
  fi
  ;;

"rhel-7.3" | "rhel-7.4" | "rhel-7.5")
  printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
  sudo yum install -y git libseccomp-devel
  configureAndInstall
  ;;

"sles-15")
  printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" | tee -a "$LOG_FILE"
  sudo zypper install -y git libseccomp-devel wget tar curl gcc
  configureAndInstall
  ;;

*)
  printf -- "%s not supported \n" "$DISTRO"| tee -a "$LOG_FILE"
  exit 1 ;;
esac

# Print Summary
printSummary
