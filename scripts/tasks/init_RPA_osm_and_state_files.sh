#!/bin/bash

# Settings
set -e # Be sure we fail on error and output debugging information
trap 'echo "$0: error on line $LINENO"' ERR
#set -x # Print commands and their arguments as they are executed

# Config reading
here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. $here/../../conf/config


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
echo Get options \(update $OSM_FILE_DAYS_OF_DELAY from options if provided\)
echo

OSM_FILE_DAYS_OF_DELAY=${RPA_INITIAL_DAYS_OF_DELAY}

OPTS=`getopt -o vhns: --long \
osm-file-days-of-delay: \
-n 'parse-options' -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

echo "$OPTS"
eval set -- "$OPTS"

while true; do
  case "$1" in
    --osm-file-days-of-delay ) OSM_FILE_DAYS_OF_DELAY="$2"; shift 2;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

echo
echo ------------------------------------------------------
echo Set some variables
echo

AREA_BASE_DIR=${DOCKERPATH_RPA_FILES_DIR}/${RPA_NAME}
AREA_ROOT_STATE_FILE=${AREA_BASE_DIR}/${OSMOSIS_WORKING_DIRS_NAME}/state.txt

OSM_LATEST_FILE=${AREA_BASE_DIR}/${RPA_NAME}-latest.osm.pbf
OSM_NEW_FILE=${AREA_BASE_DIR}/${RPA_NAME}-new.osm.pbf


echo
echo ------------------------------------------------------
echo "Get latest available state.txt at RPA replication tree url ${RPA_RT_URL}."
echo

wget -q --show-progress --progress=bar:force ${RPA_RT_URL}/state.txt -O ${AREA_ROOT_STATE_FILE}

echo
echo ------------------------------------------------------
echo Download ${OSM_NEW_FILE}
echo

wget -q --show-progress --progress=bar:force ${RPA_OSM_FILE_DOWNLOAD_URL} -O ${OSM_NEW_FILE}

echo
echo ------------------------------------------------------
echo New file ${OSM_NEW_FILE} becomes the latest file: ${OSM_LATEST_FILE}
echo

mv ${OSM_NEW_FILE} ${OSM_LATEST_FILE}

echo ------------------------------------------------------
echo Update RPA PBF file with all available OSC files
echo

bash $here/../utils/update_osm_file_with_available_osc.sh \
--area-base-dir "${AREA_BASE_DIR}" \
--area-name "${RPA_NAME}" \
--area-osmosis-workdir-name "${OSMOSIS_WORKING_DIRS_NAME}" \
--area-root-state-file "${AREA_ROOT_STATE_FILE}" \
--area-replication-tree-url "${RPA_RT_URL}" \
--osm-file-days-of-delay "${OSM_FILE_DAYS_OF_DELAY}"

# mesure script execution time
duration=$SECONDS

echo
echo "##############################################################################################################################################"
echo `date`: ${SCRIPT_NAME} completed in
echo "$(($duration / 3600)) hour(s) $(($duration / 60)) minute(s) $(($duration % 60)) second(s)."
echo "##############################################################################################################################################"
echo