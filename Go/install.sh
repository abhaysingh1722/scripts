#!/bin/bash
# © Copyright IBM Corporation 2017, 2018.
# LICENSE: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)

set -e

PACKAGE_NAME="go"
PACKAGE_VERSION="1.10.1"

LOG_FILE="${PACKAGE_NAME}-${PACKAGE_VERSION}-$(date +"%F-%T").log"

function error_handle() {
  stty echo;
}

function getDetails()
{
    printf -- '**************************** SYSTEM DETAILS *************************************************************\n' > "$LOG_FILE";
    source "/etc/os-release" && cat "/etc/os-release" >> "$LOG_FILE"
    cat /proc/version >> "$LOG_FILE"
    printf -- '*********************************************************************************************************\n' >> "$LOG_FILE"; 

    printf -- 'Detected %s \n' "$PRETTY_NAME"
    printf -- 'Installing Go with version : %s \n' "$PACKAGE_VERSION" | tee -a "$LOG_FILE"
}

# Print the usage message
function printHelp() {
  echo "Usage: "
  echo "  install.sh [-s <silent>] [-d <debug>] [-v package-version]"
  echo "       default: If no -v specified, latest version will be installed"
  echo
}

while getopts "h?sdv:" opt; do
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
  esac
done

getDetails