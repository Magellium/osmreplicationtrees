#!/bin/bash

## README
# This script will iterate on every child area to keep up-to-date its specific replication tree
# Before all it will check that:
# - the Root Parent Area has been updated since last script call
# - there is no concurrent process (no lock file)
# -> if not the script will try to perform the task later (see $KEEPUP_CAs_RTs_DELAY_BETWEEN_TRIES and $KEEPUP_RPA_MAX_TRY_NUM)

# Settings
set -e # Be sure we fail on error and output debugging information
trap 'echo "$0: error on line $LINENO"' ERR
#set -x # Print commands and their arguments as they are executed

# Config reading
here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. $here/../../conf/config

# Function reading
. $here/../utils/check_for_lockfile.sh
. $here/keepup_CA_specific_RT_func.sh

SCRIPT_NAME=`basename "$0"`

echo
echo "##############################################################################################################################################"
echo `date`: running \'${SCRIPT_NAME}\'
echo "##############################################################################################################################################"
echo

# initialize $SECONDS to mesure script execution time
SECONDS=0

# check functions - START

RPA_WAS_UPDATED=TRUE
function check_if_rpa_updated () {
  RPA_WAS_UPDATED=TRUE ##reinit variable
  echo ----
  echo Compare RPA state.txt and keepup-RT-last-used-state-file.txt files
  echo to be sure that Root Parent Area has been updated since last RT updates
  echo ----

  RPA_OSMOSIS_DIR=${DOCKERPATH_RPA_FILES_DIR}/${RPA_NAME}/${OSMOSIS_WORKING_DIRS_NAME}
  RPA_STATE_FILE=${RPA_OSMOSIS_DIR}/state.txt
  RPA_LATEST_USED_STATE_FILE=${RPA_OSMOSIS_DIR}/keepup-RT-last-used-state-file.txt

  echo RPA_STATE_FILE: 
  if [ -f "${RPA_STATE_FILE}" ]; then
    cat $RPA_STATE_FILE
    if [ -f "${RPA_LATEST_USED_STATE_FILE}" ]; then
      cat $RPA_LATEST_USED_STATE_FILE;
      RPA_STATE_FILE_SEQNUM=$(getAttributeFromStateFile ${RPA_STATE_FILE} sequenceNumber)
      RPA_LATEST_USED_STATE_FILE_SEQNUM=$(getAttributeFromStateFile ${RPA_LATEST_USED_STATE_FILE} sequenceNumber)
      if (( ${RPA_STATE_FILE_SEQNUM} == ${RPA_LATEST_USED_STATE_FILE_SEQNUM} )); then
        RPA_WAS_UPDATED=FALSE
      fi
    else
      echo \$RPA_LATEST_USED_STATE_FILE is empty
    fi
  else 
    echo \$RPA_STATE_FILE is empty. Child areas RT update forbidden;
    RPA_WAS_UPDATED=FALSE
  fi
}

LOCKFILE_EXISTS=FALSE
function check_for_lock_files () {
  echo
  echo ------------------------------------------------------
  echo Check for existing lock files
  echo
  for lock_file in "${LOCK_FILES[@]}"; do
      LOCKFILE_EXISTS=$(checkForLockFile ${lock_file})
      echo 'LOCKFILE_EXISTS': $LOCKFILE_EXISTS
      if [ "$LOCKFILE_EXISTS" = TRUE ]; then
      break
      fi
  done;
}

# check functions - END

export NUMBER_OF_TRIES=0

function keepup_RT () {
  NUMBER_OF_TRIES=$(($NUMBER_OF_TRIES + 1))
  echo
  echo ------------------------------------------------------
  echo -e "'${FUNCNAME[0]}' function - Try number: $NUMBER_OF_TRIES - Date: $(date)"
  
  # call check functions
  check_if_rpa_updated
  check_for_lock_files
  echo "'RPA_WAS_UPDATED': ${RPA_WAS_UPDATED}"
  echo "'LOCKFILE_EXISTS': ${LOCKFILE_EXISTS}"
  if [[ "${RPA_WAS_UPDATED}" = FALSE || "${LOCKFILE_EXISTS}" = TRUE ]]; then
    if (( ${NUMBER_OF_TRIES} < ${KEEPUP_CAs_RTs_MAX_TRY_NUM} )); 
    then
      echo -e "'-> WARNING: RPA was not updated and/or a Lock file exists: we wait for ${KEEPUP_CAs_RTs_DELAY_BETWEEN_TRIES} \
      and we recall the same function '${FUNCNAME[0]}'"
      sleep ${KEEPUP_CAs_RTs_DELAY_BETWEEN_TRIES}
      keepup_RT
    else
      echo -e "-> ERROR: After ${KEEPUP_CAs_RTs_MAX_TRY_NUM} tries, max number of tries reached: aborting."
      exit 1
    fi
  else
    echo -e "'-> SUCCESS: RPA is up-to-date and there is no current lock file, \let's call keepup_CA_specific_RT_func.sh for each RT"
    
    echo
    echo ------------------------------------------------------
    echo Create a lock file ${CA_LOCK_FILE} with PID $$
    echo

    echo $$ >${CA_LOCK_FILE}
    
    ITER=O
    for child_area_name in "${CA_NAMES[@]}"
      do
        echo
        echo "#################################"
        echo "#################################"
        echo `date`
        echo -e "Call 'keepup_CA_specific_RT_func' (ITER $ITER) \n\
        - 'child_area_name': $child_area_name \n\
        - 'parent-area-name': ${PARENTS_NAMES[ITER]}"
        echo "#################################"
        echo "#################################"
        echo
        keepup_CA_specific_RT_func \
          --parent-area-name ${PARENTS_NAMES[ITER]} \
          --parent-area-files-dir ${PARENTS_DIR[ITER]}/${PARENTS_NAMES[ITER]} \
          --parent-state-file-dir ${PARENTS_STATE_FILE_DIR[ITER]}\
          --child-area-name ${child_area_name} \
          --child-area-files-dir ${DOCKERPATH_CA_FILES_DIR}/${child_area_name} \
          --child-area-poly-file-dir $here/../../conf/poly_files
        ITER=$(($ITER + 1))
    done;
  
    echo
    echo ------------------------------------------------------
    echo Remove lock file \(${CA_LOCK_FILE}\)
    echo

    rm ${CA_LOCK_FILE} || true

  fi
}

echo
echo ------------------------------------------------------
echo Call keepup_RT to iterate on all replication trees and update them
echo

if [ "$NUMBER_OF_TRIES" -eq "0" ]
then 
  keepup_RT
fi

echo
echo ------------------------------------------------------
echo Copy last ${RPA_STATE_FILE} file to ${RPA_LATEST_USED_STATE_FILE}
echo

cp ${RPA_STATE_FILE} ${RPA_LATEST_USED_STATE_FILE}

# mesure script execution time
duration=$SECONDS

echo
echo "##############################################################################################################################################"
echo `date`: ${SCRIPT_NAME} completed in
echo "$(($duration / 3600)) hour(s) $(($duration / 60)) minute(s) $(($duration % 60)) second(s)."
echo "##############################################################################################################################################"
echo