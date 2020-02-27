#!/bin/bash

## README
# This script runs a new docker container (or use an existing one)
# and then launches the main script inside the container to deploy replication trees from scratch

# Settings
set -e # Be sure we fail on error and output debugging information
trap 'echo "$0: error on line $LINENO"' ERR
#set -x # Print commands and their arguments as they are executed

# Config reading
here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. $here/conf/config

SCRIPT_NAME=`basename "$0"`

echo
echo "##############################################################################################################################################"
echo `date`: running \'${SCRIPT_NAME}\'
echo "##############################################################################################################################################"
echo

echo
echo ------------------------------------------------------
echo Get options \(update $OSM_FILE_DAYS_OF_DELAY from options if provided\)
echo

OPTS=`getopt -o vhns: --long \
use-existing-container \
-n 'parse-options' -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

echo "$OPTS"
eval set -- "$OPTS"

while true; do
  case "$1" in
    --use-existing-container ) USE_EXISTING_CONTAINER=TRUE; shift;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done


echo
echo ------------------------------------------------------
echo '--> Run docker with all needed stuff'
echo ------------------------------------------------------
echo

NAMESAKE_CONTAINER_EXISTS=FALSE

if [[ $(sudo docker ps -f "name=${DOCKER_NAME}" --format '{{.Names}}') == ${DOCKER_NAME} ]]; then 
  NAMESAKE_CONTAINER_EXISTS=TRUE
fi

if [ "${NAMESAKE_CONTAINER_EXISTS}" = TRUE ]; then
  if [ ! "${USE_EXISTING_CONTAINER}" = TRUE ]; then
  echo -e "ERROR: a container with name '${DOCKER_NAME}' already exists! You can alternatively:\n\
  - remove it using 'sudo docker rm -f ${DOCKER_NAME}' (it's what you should do if initial docker \
  container volumes has been removed and recreated since your existing container is running)\n\
  - call this script appending '--use-existing-container' option"
  exit 1
  fi
else
  sudo docker run -dit \
    --restart always \
    --volume $here:${DOCKERPATH_SOURCE_DIR} \
    --volume ${HOSTPATH_RPA_FILES_DIR}:${DOCKERPATH_RPA_FILES_DIR} \
    --volume ${HOSTPATH_CA_FILES_DIR}:${DOCKERPATH_CA_FILES_DIR} \
    --volume ${HOSTPATH_LOGS_DIR}:${DOCKERPATH_LOGS_DIR} \
    --name ${DOCKER_NAME} \
    ${DOCKER_BUILD_TAG}
fi



echo
echo ------------------------------------------------------
echo '--> Root Parent Area: get an up-to-date OSM file'
echo ------------------------------------------------------
echo

sudo docker exec ${DOCKER_NAME} \
bash  ${DOCKERPATH_SOURCE_DIR}/scripts/deploy_trees.sh