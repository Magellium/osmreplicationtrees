#!/bin/bash

## README
# This script will 
# - download all available .osc.gz files between $AREA_ROOT_STATE_FILE timestamp and ($AREA_ROOT_STATE_FILE timestamp - $OSM_FILE_DAYS_OF_DELAY)
# - produce a merge.osc.gz (using Osmium)
# - apply the merge.osc.gz to the PBF file (using Osmium)

# Settings
set -e # Be sure we fail on error and output debugging information
trap 'echo "$0: error on line $LINENO"' ERR
#set -x # Print commands and their arguments as they are executed

# Functions reading
here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. $here/statefiles_functions.sh

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
echo Print options
echo

OPTS=`getopt -o vhns: --long \
area-base-dir:,\
area-name:,\
area-osmosis-workdir-name:,\
area-root-state-file:,\
area-replication-tree-url:,\
osm-file-days-of-delay: \
-n 'parse-options' -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

echo "$OPTS"
eval set -- "$OPTS"

while true; do
  case "$1" in
    --area-base-dir ) AREA_BASE_DIR="$2"; shift 2;;
    --area-name ) AREA_NAME="$2"; shift 2;;
    --area-osmosis-workdir-name ) OSMOSIS_WORKDIR_NAME="$2"; shift 2;;
    --area-root-state-file ) AREA_ROOT_STATE_FILE="$2"; shift 2;;
    --area-replication-tree-url ) AREA_RT_URL="$2"; shift 2;;
    --osm-file-days-of-delay ) OSM_FILE_DAYS_OF_DELAY="$2"; shift 2;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

echo
echo ------------------------------------------------------
echo "Set some variables"
echo

INITAL_CHANGES_DIR=${AREA_BASE_DIR}/${OSMOSIS_WORKDIR_NAME}/changes/init
OSM_LATEST_FILE=${AREA_BASE_DIR}/${AREA_NAME}-latest.osm.pbf
OSM_OLD_FILE=${AREA_BASE_DIR}/${AREA_NAME}-old.osm.pbf
OSM_NEW_FILE=${AREA_BASE_DIR}/${AREA_NAME}-new.osm.pbf

echo 'INITAL_CHANGES_DIR': ${INITAL_CHANGES_DIR}

echo
echo ------------------------------------------------------
echo "Check for latest OSM file ${OSM_LATEST_FILE}"
echo

if [ ! -f "${OSM_LATEST_FILE}" ]
then
    >&2 echo -e "\nError: '${OSM_LATEST_FILE}' file does not exist."
    exit 1
elsetoday minor _STATE_FILE}"
echo

if [ ! -f "${AREA_ROOT_STATE_FILE}" ]
then
  echo "ERROR: '${AREA_ROOT_STATE_FILE}' local file does not exists."
  exit 1
else
  echo "'${AREA_ROOT_STATE_FILE}' file exists, let's print it:"
  echo
  cat ${AREA_ROOT_STATE_FILE}
fi

# get its sequence number
SEQUENCE_NUMBER=$(getAttributeFromStateFile ${AREA_ROOT_STATE_FILE} sequenceNumber)

echo
echo ------------------------------------------------------
echo Wget all available changes from latest SEQUENCE_NUMBER \(${SEQUENCE_NUMBER}\) 
echo to SEQUENCE_NUMBER minux number of days delay \(${OSM_FILE_DAYS_OF_DELAY} days\)
echo

if [ "$(ls ${INITAL_CHANGES_DIR} | wc -l)" -ge "1" ];
then
    echo -e "${INITAL_CHANGES_DIR} is not empty:"
    ls -l ${INITAL_CHANGES_DIR}/
    echo -e "Let\'s remove these files"    
    rm ${INITAL_CHANGES_DIR}/*.osc.gz
fi

OSC_INIT_FILES_PATH=""
for i in $(seq $((${SEQUENCE_NUMBER}-${OSM_FILE_DAYS_OF_DELAY})) ${SEQUENCE_NUMBER});
  do 
    echo --
    echo Get .osc.gz file for sequence number $i
    osc_file_name="$(getRTFileNameFromSeqNumber ${i}).osc.gz"
    RT_files_dir=$(getRTFileDirFromSeqNumber ${i})
    file_to_save="${INITAL_CHANGES_DIR}/${osc_file_name}"
    echo osc_file_name: $osc_file_name
    echo RT_files_dir: $RT_files_dir
    echo file_to_save: $file_to_save
    if [ ! -f "${file_to_save}" ]
    then
      wget -q --show-progress --progress=bar:force ${AREA_RT_URL}/${RT_files_dir}/${osc_file_name} -O ${file_to_save}
    else
      echo $file_to_save already exists
    fi
    # add the file full path in docker container filesystem to $OSC_INIT_FILES_PATH
    # -> used with osmium 'merge-changes' task as "/*.osc.gz" regex pattern does not work
    OSC_INIT_FILES_PATH="${OSC_INIT_FILES_PATH} ${INITAL_CHANGES_DIR}/${osc_file_name}"
done;

echo
echo ------------------------------------------------------
echo Osmium 'merge-changes' task on all available changes within number of days delay
echo

osmium merge-changes --verbose --simplify --overwrite --output ${INITAL_CHANGES_DIR}/merge.osc.gz \
${OSC_INIT_FILES_PATH}


echo
echo ------------------------------------------------------
echo Osmium 'apply-changes' task
echo

osmium apply-changes --verbose --progress --overwrite ${OSM_LATEST_FILE} \
${INITAL_CHANGES_DIR}/merge.osc.gz \
-o ${OSM_NEW_FILE}

echo
echo ------------------------------------------------------
echo Archive ${AREA_NAME}-latest.osm.pbf to ${AREA_NAME}-old.osm.pbf
echo

mv ${OSM_LATEST_FILE} ${OSM_OLD_FILE}

echo
echo ------------------------------------------------------
echo ${AREA_NAME}-new.osm.pbf becomes the new ${AREA_NAME}-latest.osm.pbf
echo

mv ${OSM_NEW_FILE} ${OSM_LATEST_FILE}

echo
echo ------------------------------------------------------
echo Remove change files
echo

rm ${INITAL_CHANGES_DIR}/*.osc.gz || true

# mesure script execution time
duration=$SECONDS

echo
echo "##############################################################################################################################################"
echo `date`: ${SCRIPT_NAME} completed in
echo "$(($duration / 3600)) hour(s) $(($duration / 60)) minute(s) $(($duration % 60)) second(s)."
echo "##############################################################################################################################################"
echo