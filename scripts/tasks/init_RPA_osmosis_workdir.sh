#!/bin/bash

# Settings
set -e # Be sure we fail on error and output debugging information
trap 'echo "$0: error on line $LINENO"' ERR
#set -x # Print commands and their arguments as they are executed

# Config reading
here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. $here/../../conf/config


echo
echo ------------------------------------------------------
echo "Set some variables"
echo

OSMOSIS_WORKDIR=${DOCKERPATH_RPA_FILES_DIR}/${RPA_NAME}/${OSMOSIS_WORKING_DIRS_NAME}
AREA_ROOT_STATE_FILE=${OSMOSIS_WORKDIR}/state.txt
echo 'OSMOSIS_WORKDIR': ${OSMOSIS_WORKDIR}
echo 'AREA_ROOT_STATE_FILE': ${AREA_ROOT_STATE_FILE}

echo
echo ------------------------------------------------------
echo "Check for state.txt file at ${AREA_ROOT_STATE_FILE}"
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

echo
echo ------------------------------------------------------
echo OSMOSIS: INIT WITH 'osmosis --read-replication-interval-init' 
echo

CONFIG_FILE=${OSMOSIS_WORKDIR}/configuration.txt
if [ ! -f "${CONFIG_FILE}" ]
then
    osmosis --read-replication-interval-init workingDirectory=${OSMOSIS_WORKDIR}
else
    >&2 echo "Error: '${CONFIG_FILE}' file already exist"
    exit 1
fi


echo
echo ------------------------------------------------------
echo OSMOSIS: UPDATE configuration.txt
echo

echo
echo 'DEFAULT configuration.txt VERSION:'
echo -------
cat ${CONFIG_FILE}
echo -------
echo

sed -i "s!baseUrl=https://planet.openstreetmap.org/replication/minute\
!baseUrl=${RPA_RT_URL}!" \
${CONFIG_FILE}

sed -i "s!maxInterval = 3600\
!maxInterval = ${RPA_OSMOSIS_MAX_INTERVAL}!" \
${CONFIG_FILE}

echo
echo 'UPDATED configuration.txt VERSION:'
echo -------
cat ${CONFIG_FILE}
echo -------
echo
echo
