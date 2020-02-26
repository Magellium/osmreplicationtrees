#!/bin/bash

# Settings
set -e # Be sure we fail on error and output debugging information
trap 'echo "$0: error on line $LINENO"' ERR
#set -x # Print commands and their arguments as they are executed

# Config reading
here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. $here/../../conf/config

# Functions reading
. $here/../utils/statefiles_functions.sh
. $here/../utils/check_for_lockfile.sh

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

# check functions - START
LOCKFILE_EXISTS=FALSE
function check_for_lock_files () {
  echo
  echo ------------------------------------------------------
  echo Check for existing lock files
  echo
  for lock_file in ${LOCK_FILES[@]}; do
      LOCKFILE_EXISTS=$(checkForLockFile ${lock_file})
      if [ "$LOCKFILE_EXISTS" = TRUE ]; then
      echo -e "-> ERROR: a Lock File exists: aborting."
      exit 1
      fi
  done;
}
# call check function
check_for_lock_files

echo
echo ------------------------------------------------------
echo Set some variables
echo

AREA_BASE_DIR=${DOCKERPATH_RPA_FILES_DIR}/${RPA_NAME}
AREA_ROOT_STATE_FILE=${AREA_BASE_DIR}/${OSMOSIS_WORKING_DIRS_NAME}/state.txt
AREA_ROOT_STATE_FILE_NEW=${AREA_BASE_DIR}/${OSMOSIS_WORKING_DIRS_NAME}/state-new.txt
AREA_RT_URL=${RPA_RT_URL}

OSM_LATEST_FILE=${AREA_BASE_DIR}/${RPA_NAME}-latest.osm.pbf
OSM_OLD_FILE=${AREA_BASE_DIR}/${RPA_NAME}-old.osm.pbf


echo
echo ------------------------------------------------------
echo "Get latest available state.txt at RPA replication tree url ${AREA_RT_URL}."
echo

wget -q --show-progress --progress=bar:force ${AREA_RT_URL}/state.txt -O ${AREA_ROOT_STATE_FILE_NEW}

echo
echo ------------------------------------------------------
echo "If a local state.txt file already exists, check if its sequenceNumber is up-to-date with \
latest available state.txt at RPA replication tree url."
echo "If not, exit script to avoid messing existing replications trees"
echo

if [ -f "${AREA_ROOT_STATE_FILE}" ]
then
    echo "'${AREA_ROOT_STATE_FILE}' file already exists:"
    echo
    SEQUENCE_NUMBER=$(getAttributeFromStateFile ${AREA_ROOT_STATE_FILE} sequenceNumber)
    SEQUENCE_NUMBER_NEW=$(getAttributeFromStateFile ${AREA_ROOT_STATE_FILE_NEW} sequenceNumber)
    if (( ${SEQUENCE_NUMBER} != ${SEQUENCE_NUMBER_NEW} ))
    then
      echo "-> ERROR: '${AREA_ROOT_STATE_FILE}' local file is not up to date with ${AREA_RT_URL}/state.txt:"
      echo
      rm ${AREA_ROOT_STATE_FILE_NEW}
      exit 1
    else
      echo "-> '${AREA_ROOT_STATE_FILE}' file is already up-to-date"
      rm ${AREA_ROOT_STATE_FILE_NEW}
    fi
else
  echo "ERROR: '${AREA_ROOT_STATE_FILE}' file does not exists."
  exit 1
fi

echo
echo ------------------------------------------------------
echo Archive ${OSM_LATEST_FILE} to ${OSM_OLD_FILE}
echo

mv ${OSM_LATEST_FILE} ${OSM_OLD_FILE}

echo
echo ------------------------------------------------------
echo "Call init_RPA_osm_and_state_files.sh"
echo

bash  ${here}/init_RPA_osm_and_state_files.sh \
--osm-file-days-of-delay "${OSM_FILE_DAYS_OF_DELAY}"

echo
echo "##############################################################################################################################################"
echo `date`: ${SCRIPT_NAME} completed in
echo "$(($duration / 3600)) hour(s) $(($duration / 60)) minute(s) $(($duration % 60)) second(s)."
echo "##############################################################################################################################################"
echo