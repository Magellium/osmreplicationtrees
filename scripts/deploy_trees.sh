#!/bin/bash

## README
# This script will run consecutively all needed scripts to initialize an osmreplicationtrees instance

# Settings
set -e # Be sure we fail on error and output debugging information
trap 'echo "$0: error on line $LINENO"' ERR
#set -x # Print commands and their arguments as they are executed

# Config reading
here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. $here/../conf/config

SCRIPT_NAME=`basename "$0"`

echo
echo "##############################################################################################################################################"
echo `date`: running \'${SCRIPT_NAME}\'
echo "##############################################################################################################################################"
echo

# initialize $SECONDS to mesure script execution time
SECONDS=0

echo
echo ------------------------------------------------------
echo Get options
echo

OSM_FILE_DAYS_OF_DELAY=${RPA_INITIAL_DAYS_OF_DELAY}

echo
echo ------------------------------------------------------
echo \'${SCRIPT_NAME}\'
echo '--> Root Parent Area: get an up-to-date OSM file'
echo ------------------------------------------------------
echo

bash  ${here}/tasks/init_RPA_osm_and_state_files.sh \
--osm-file-days-of-delay "${RPA_INITIAL_DAYS_OF_DELAY}"

echo
echo ------------------------------------------------------
echo \'${SCRIPT_NAME}\'
echo '--> Root Parent Area: init Osmosis working directory'
echo ------------------------------------------------------
echo

bash  ${here}/tasks/init_RPA_osmosis_workdir.sh

echo
echo ------------------------------------------------------
echo \'${SCRIPT_NAME}\'
echo '--> Replication trees: initialize Child Areas Replication Trees'
echo 'by running keepup_CAs_RTs.sh a first time'
echo ------------------------------------------------------
echo

bash  ${here}/tasks/keepup_CAs_RTs.sh

# mesure script execution time
duration=$SECONDS

echo
echo ------------------------------------------------------
echo `date`: ${SCRIPT_NAME} completed in
echo "$(($duration / 3600)) hour(s) $(($duration / 60)) minute(s) $(($duration % 60)) second(s)."
echo