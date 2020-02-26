#!/bin/bash

# Settings
set -e # Be sure we fail on error and output debugging information
trap 'echo "$0: error on line $LINENO"' ERR
#set -x # Print commands and their arguments as they are executed

# Config reading
here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. $here/../../conf/config

# Function reading
. $here/../utils/check_for_lockfile.sh
. $here/../utils/statefiles_functions.sh

SCRIPT_NAME=`basename "$0"`

echo
echo "##############################################################################################################################################"
echo `date`: running \'${SCRIPT_NAME}\'
echo "##############################################################################################################################################"
echo

# initialize $SECONDS to mesure script execution time
SECONDS=0

# check functions - START

RTs_WERE_UPDATED=TRUE
function check_if_rts_updated () {
  RTs_WERE_UPDATED=TRUE ##reinit variable
  echo ----
  echo Compare RPA state.txt and keepup-RT-last-used-state-file.txt files
  echo to be sure that RTs have been updated since last RPA update
  echo ----

  RPA_OSMOSIS_DIR=${DOCKERPATH_RPA_FILES_DIR}/${RPA_NAME}/${OSMOSIS_WORKING_DIRS_NAME}
  RPA_STATE_FILE=${RPA_OSMOSIS_DIR}/state.txt
  RPA_LATEST_USED_STATE_FILE=${RPA_OSMOSIS_DIR}/keepup-RT-last-used-state-file.txt

  echo RPA_LATEST_USED_STATE_FILE: 
  if [ -f "${RPA_LATEST_USED_STATE_FILE}" ]; then
    cat $RPA_LATEST_USED_STATE_FILE
    if [ -f "${RPA_STATE_FILE}" ]; then
      cat $RPA_STATE_FILE;
      RPA_STATE_FILE_SEQNUM=$(getAttributeFromStateFile ${RPA_STATE_FILE} sequenceNumber)
      RPA_LATEST_USED_STATE_FILE_SEQNUM=$(getAttributeFromStateFile ${RPA_LATEST_USED_STATE_FILE} sequenceNumber)
      if (( ${RPA_STATE_FILE_SEQNUM} != ${RPA_LATEST_USED_STATE_FILE_SEQNUM} )); then
        RTs_WERE_UPDATED=FALSE
      fi
    else
      echo \$RPA_STATE_FILE is empty. RPA update forbidden as it has not been initialized.
      RTs_WERE_UPDATED=FALSE
    fi
  else 
    echo \$RPA_LATEST_USED_STATE_FILE is empty. RPA update allowed.
  fi
}

LOCKFILE_EXISTS=FALSE
function check_for_lock_files () {
  echo
  echo ------------------------------------------------------
  echo Check for existing lock files
  echo
  for lock_file in ${LOCK_FILES[@]}; do
      LOCKFILE_EXISTS=$(checkForLockFile ${lock_file})
      if [ "$LOCKFILE_EXISTS" = TRUE ]; then
      break
      fi
  done;
}

# check functions - END

export NUMBER_OF_TRIES=0

function keepup_RPA_osm_file () {

  NUMBER_OF_TRIES=$(($NUMBER_OF_TRIES + 1))
  echo
  echo ------------------------------------------------------
  echo -e "'${FUNCNAME[0]}' function - Try number: $NUMBER_OF_TRIES - Date: $(date)"

  # call check function
  check_for_lock_files
  check_if_rts_updated
  echo "'RTs_WERE_UPDATED': ${RTs_WERE_UPDATED}"
  echo "'LOCKFILE_EXISTS': ${LOCKFILE_EXISTS}"
  if [[ "${RTs_WERE_UPDATED}" = FALSE || "${LOCKFILE_EXISTS}" = TRUE ]]; then
    if (( $NUMBER_OF_TRIES < $KEEPUP_RPA_MAX_TRY_NUM )); 
    then
      echo -e "'-> WARNING: CA RTs were not updated and/or a Lock file exists: we wait for ${KEEPUP_RPA_DELAY_BETWEEN_TRIES} \
      and we recall the same function '${FUNCNAME[0]}'"
      sleep ${KEEPUP_RPA_DELAY_BETWEEN_TRIES}
      keepup_RPA_osm_file
    else
      echo -e "-> ERROR: ${KEEPUP_RPA_MAX_TRY_NUM} tries, a Lock File still exists: aborting."
      exit 1
    fi
  else
    echo -e "'-> SUCCESS: CA RTs are up-to-date and there is no current lock file, let's update RPA osm file"
    
    # directories
    OSM_FILE_DIR=${DOCKERPATH_RPA_FILES_DIR}/${RPA_NAME}
    OSMOSIS_DIR=${OSM_FILE_DIR}/${OSMOSIS_WORKING_DIRS_NAME}
    OSC_FILE_DIR=${OSMOSIS_DIR}/changes

    # files
    OSC_FILE=${OSC_FILE_DIR}/changes.osc.gz
    OSM_LATEST_FILE=${OSM_FILE_DIR}/${RPA_NAME}-latest.osm.pbf
    OSM_OLD_FILE=${OSM_FILE_DIR}/${RPA_NAME}-old.osm.pbf
    OSM_NEW_FILE=${OSM_FILE_DIR}/${RPA_NAME}-new.osm.pbf

    echo
    echo ------------------------------------------------------
    echo Create a lock file ${RPA_LOCK_FILE} with PID $$
    echo

    echo $$ >${RPA_LOCK_FILE}

    echo
    echo ------------------------------------------------------
    echo Remove ${OSC_FILE} old change file if exists and archive the last one
    echo

    rm ${OSC_FILE}_old || true
    mv ${OSC_FILE} ${OSC_FILE}_old || true

    echo
    echo ------------------------------------------------------
    echo Osmosis 'read-replication' task
    echo

    osmosis --read-replication-interval workingDirectory=${OSMOSIS_DIR} --simplify-change --write-xml-change ${OSC_FILE}

    echo
    echo ------------------------------------------------------
    echo Osmium 'apply-changes' task to produce ${OSM_NEW_FILE}
    echo

    osmium apply-changes --verbose --progress ${OSM_LATEST_FILE} ${OSC_FILE} --output ${OSM_NEW_FILE}

    echo
    echo ------------------------------------------------------
    echo Archive ${OSM_LATEST_FILE} to ${OSM_OLD_FILE}
    echo

    mv ${OSM_LATEST_FILE} ${OSM_OLD_FILE}

    echo
    echo ------------------------------------------------------
    echo New file ${OSM_NEW_FILE} becomes the latest file: ${OSM_LATEST_FILE}
    echo

    mv ${OSM_NEW_FILE} ${OSM_LATEST_FILE}

    echo
    echo ------------------------------------------------------
    echo Remove lock file \(${RPA_LOCK_FILE}\)
    echo

    rm ${RPA_LOCK_FILE} || true

  fi

}

echo
echo ------------------------------------------------------
echo Call keepup_RPA_osm_file
echo

if [ "$NUMBER_OF_TRIES" -eq "0" ]
then 
  keepup_RPA_osm_file
fi

# mesure script execution time
duration=$SECONDS

echo
echo "##############################################################################################################################################"
echo `date`: ${SCRIPT_NAME} completed in
echo "$(($duration / 3600)) hour(s) $(($duration / 60)) minute(s) $(($duration % 60)) second(s)."
echo "##############################################################################################################################################"
echo