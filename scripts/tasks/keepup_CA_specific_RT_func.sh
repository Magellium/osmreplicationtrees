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

function keepup_CA_specific_RT_func () {

# initialize $SECONDS to mesure script execution time
SECONDS=0

echo
echo ------------------------------------------------------
echo Process options
echo

OPTS=`getopt -o vhns: --long \
parent-area-name:,\
parent-area-files-dir:,\
parent-state-file-dir:,\
child-area-name:,\
child-area-files-dir:,\
child-area-poly-file-dir: \
-n 'parse-options' -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

echo "OPTIONS: $OPTS"
eval set -- "$OPTS"

while true; do
  case "$1" in
    --parent-area-name ) PARENT_AREA_NAME="$2"; shift 2;;
    --parent-area-files-dir ) PARENT_AREA_FILES_DIR="$2"; shift 2;;
    --parent-state-file-dir ) PARENT_STATE_FILE_DIR="$2"; shift 2;;
    --child-area-name ) CHILD_AREA_NAME="$2"; shift 2;;
    --child-area-files-dir ) CHILD_AREA_FILES_DIR="$2"; shift 2;;
    --child-area-poly-file-dir ) CHILD_AREA_POLY_FILE_DIR="$2"; shift 2;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

PA_OSM_LATEST_FILE=${PARENT_AREA_FILES_DIR}/${PARENT_AREA_NAME}-latest.osm.pbf
CA_OSM_LATEST_FILE=${CHILD_AREA_FILES_DIR}/${CHILD_AREA_NAME}-latest.osm.pbf
CA_OSM_NEW_FILE=${CHILD_AREA_FILES_DIR}/${CHILD_AREA_NAME}-new.osm.pbf
CA_OSM_OLD_FILE=${CHILD_AREA_FILES_DIR}/${CHILD_AREA_NAME}-old.osm.pbf
CA_POLY_FILE=${CHILD_AREA_POLY_FILE_DIR}/${CHILD_AREA_NAME}.poly
CA_ROOT_STATE_FILE=${CHILD_AREA_FILES_DIR}/${RT_DIRS_NAME}/state.txt
PA_ROOT_STATE_FILE=${PARENT_AREA_FILES_DIR}/${PARENT_STATE_FILE_DIR}/state.txt
PA_STATE_FILE_TIMESTAMP=$(getAttributeFromStateFile ${PA_ROOT_STATE_FILE} timestamp)
PA_STATE_FILE_SEQUENCE_NUMBER=$(getAttributeFromStateFile ${PA_ROOT_STATE_FILE} sequenceNumber)

echo
echo ------------------------------------------------------
echo Osmium 'extract' task to produce ${CA_OSM_NEW_FILE} from parent area
echo

osmium extract --verbose \
--polygon ${CA_POLY_FILE} ${PA_OSM_LATEST_FILE} \
--output ${CA_OSM_NEW_FILE} --overwrite --strategy=smart

echo
echo ------------------------------------------------------
echo Check if ${CA_OSM_LATEST_FILE} exists. If not, initialize the replication tree and exit.
echo


if [ ! -f "${CA_OSM_LATEST_FILE}" ]
  then
  echo -e "${CA_OSM_LATEST_FILE} file does not exist.\n\
  Let's initialize it"
  mv ${CA_OSM_NEW_FILE} ${CA_OSM_LATEST_FILE}
  if [ ! -f "${CA_ROOT_STATE_FILE}" ]
  then
    echo -e "${CA_ROOT_STATE_FILE} file does not exist. Let's initialize the replication tree!"
cat << EOF > ${CA_ROOT_STATE_FILE}
# this file has been generated on $(date) by osmreplicationtrees
# PARENT_AREA_NAME: ${PARENT_AREA_NAME}
# PARENT_AREA_SEQUENCE_NUMBER: ${PA_STATE_FILE_SEQUENCE_NUMBER}
timestamp=${PA_STATE_FILE_TIMESTAMP}
sequenceNumber=0000
EOF
  else
  echo "- '${CA_ROOT_STATE_FILE}' file exists"
  fi
  cat ${CA_ROOT_STATE_FILE}
  return 0
else
  echo "- '${CA_OSM_LATEST_FILE}' file exists"
fi

echo
echo ------------------------------------------------------
echo On monday, archive last ${CHILD_AREA_NAME}-old.osm.pbf
echo

if [ -f "${CA_OSM_OLD_FILE}" ]; then
  #locale's full weekday name (e.g., Sunday)
  WEEKDAY_NAME=$(date +%A)
  #day of week (1..7); 1 is Monday
  DAY_OF_WEEK=$(date +%u)

  if (( ${DAY_OF_WEEK} == 1 )); then
    # get current $CA_OSM_OLD_FILE modification date formatted as YYYY-MM-DD
    CA_OSM_OLD_FILE_MODDATE="$(stat -c %y ${CA_OSM_OLD_FILE})"
    CA_OSM_OLD_FILE_MODDATE="${CA_OSM_OLD_FILE_MODDATE%% *}"
    CA_OSM_OLD_FILE_ARCHIVE=${CHILD_AREA_FILES_DIR}/${CHILD_AREA_NAME}-old-${CA_OSM_OLD_FILE_MODDATE}.osm.pbf
    echo -e "Today is ${WEEKDAY_NAME}, let\'s archive ${CA_OSM_OLD_FILE} to ${CA_OSM_OLD_FILE_ARCHIVE}"
    mv ${CA_OSM_OLD_FILE} ${CA_OSM_OLD_FILE_ARCHIVE}
    #keep only the files of the last four weeks
    ls -tr ${CHILD_AREA_FILES_DIR}/${CHILD_AREA_NAME}-old-* | head -n -4 | xargs rm -rf
  else
    echo -e "Nothing to do on ${WEEKDAY_NAME}"
  fi
else
  echo -e "${CA_OSM_OLD_FILE} doesn not exist, skipping."
fi

echo
echo ------------------------------------------------------
echo Archive ${CHILD_AREA_NAME}-latest.osm.pbf to ${CHILD_AREA_NAME}-old.osm.pbf
echo

mv ${CA_OSM_LATEST_FILE} ${CA_OSM_OLD_FILE}


echo
echo ------------------------------------------------------
echo ${CHILD_AREA_NAME}-new.osm.pbf becomes the new ${CHILD_AREA_NAME}-latest.osm.pbf
echo

mv ${CA_OSM_NEW_FILE} ${CA_OSM_LATEST_FILE}

echo
echo ------------------------------------------------------
echo Get new sequenceNumber by incrementation
echo

SEQUENCE_NUMBER=$(getAttributeFromStateFile ${CA_ROOT_STATE_FILE} sequenceNumber)
# Increment the sequence number
SEQUENCE_NUMBER_INCREMENTED=$((${SEQUENCE_NUMBER}+1))

echo SEQUENCE_NUMBER: ${SEQUENCE_NUMBER}
echo SEQUENCE_NUMBER_INCREMENTED: ${SEQUENCE_NUMBER_INCREMENTED}

SEQUENCE_NUMBER_MAX_VALUE=999999999
if (( ${SEQUENCE_NUMBER_INCREMENTED} > ${SEQUENCE_NUMBER_MAX_VALUE} )); then
    echo
    echo "SEQUENCE_NUMBER_INCREMENTED=${SEQUENCE_NUMBER_INCREMENTED} is greater than ${SEQUENCE_NUMBER_MAX_VALUE}!"
    echo "This script can\'t manage this value (which corresponds to about 1902 years of minutely diff...)"
    echo
    exit 1
fi

echo
echo ------------------------------------------------------
echo Prepare new .osc.gz and state.txt files paths to have an Osmosis compliant replication tree
echo

RT_FILES_DIR=$(getRTFileDirFromSeqNumber ${SEQUENCE_NUMBER_INCREMENTED})
RT_FILES_NAMES=$(getRTFileNameFromSeqNumber ${SEQUENCE_NUMBER_INCREMENTED})

OSC_AND_STATE_FILES_DIR=${CHILD_AREA_FILES_DIR}/${RT_DIRS_NAME}/${RT_FILES_DIR}
STATE_FILE_NAME=${RT_FILES_NAMES}.state.txt
OSC_FILE_NAME=${RT_FILES_NAMES}.osc.gz

echo RT_FILES_DIR: ${RT_FILES_DIR}
echo RT_FILES_NAMES: ${RT_FILES_NAMES}
echo OSC_FILE_NAME: ${OSC_FILE_NAME}
echo STATE_FILE_NAME: ${STATE_FILE_NAME}

echo
echo ------------------------------------------------------
echo Create '${OSC_AND_STATE_FILES_DIR}' \(${OSC_AND_STATE_FILES_DIR}\) if not exists
echo

mkdir -p ${OSC_AND_STATE_FILES_DIR}

echo
echo ------------------------------------------------------
echo Osmium 'derive-changes' task to produce ${OSC_FILE_NAME} by comparing ${CA_OSM_LATEST_FILE} and ${CA_OSM_OLD_FILE}
echo

osmium derive-changes --verbose --progress \
${CA_OSM_OLD_FILE} ${CA_OSM_LATEST_FILE} \
-o ${OSC_AND_STATE_FILES_DIR}/${OSC_FILE_NAME}

echo
echo ------------------------------------------------------
echo Create ${STATE_FILE_NAME} next to ${OSC_FILE_NAME} in the replication tree
echo

cat << EOF > ${OSC_AND_STATE_FILES_DIR}/${STATE_FILE_NAME}
# this file has been generated on $(date) by osmreplicationtrees
# PARENT_AREA_NAME: ${PARENT_AREA_NAME}
# PARENT_AREA_SEQUENCE_NUMBER: ${PA_STATE_FILE_SEQUENCE_NUMBER}
timestamp=${PA_STATE_FILE_TIMESTAMP}
sequenceNumber=${SEQUENCE_NUMBER_INCREMENTED}
EOF

echo
echo ------------------------------------------------------
echo Update ${CA_ROOT_STATE_FILE} by copying newborn ${STATE_FILE_NAME}
echo

cp ${OSC_AND_STATE_FILES_DIR}/${STATE_FILE_NAME} ${CA_ROOT_STATE_FILE}

# mesure script execution time
duration=$SECONDS

echo
echo ------------------------------------------------------
echo `date`: ${CA_OSM_LATEST_FILE} and replication tree update completed in
echo "$(($duration / 3600)) hour(s) $(($duration / 60)) minute(s) $(($duration % 60)) second(s)."
echo

}