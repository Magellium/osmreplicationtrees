#!/bin/bash

## README
# This script will run consecutively the two needed scripts to keep up-to-date an osmreplicationtrees running instance:
# - first script to keep up-to-date the Root Parent Area PBF file
# - second script to keep up-to-date the Child Areas replication trees

# Settings
# set -e # We do not want to exit on error
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

# Keep up root parent area OSM file
bash  ${here}/tasks/keepup_RPA_osm_file.sh

# Keep up child areas replication trees
bash  ${here}/tasks/keepup_CAs_RTs.sh

# mesure script execution time
duration=$SECONDS

echo
echo "##############################################################################################################################################"
echo `date`: ${SCRIPT_NAME} completed in
echo "$(($duration / 3600)) hour(s) $(($duration / 60)) minute(s) $(($duration % 60)) second(s)."
echo "##############################################################################################################################################"
echo