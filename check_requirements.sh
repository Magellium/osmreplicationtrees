#!/bin/bash

# Settings
set -e # Be sure we fail on error and output debugging information
trap 'echo "$0: error on line $LINENO"' ERR
#set -x # Print commands and their arguments as they are executed

# Config reading
here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. $here/conf/config

echo
echo ------------------------------------------------------
echo Check requirements
echo

## Check if docker is installed
if ! [ -x "$(command -v docker)" ]
then
  echo 'Error: docker is not installed.' >&2
  exit 1
else
  echo '- Docker is installed.' >&2
fi

## Check for a base working dir
if [ ! -d "$HOST_VOLUMES_BASE_DIR" ]
then
    >&2 echo -e "\nError: '$HOST_VOLUMES_BASE_DIR' base directory does not exist. You could run:\n\
    mkdir -p $HOST_VOLUMES_BASE_DIR"
    exit 1
else
  echo "- '$HOST_VOLUMES_BASE_DIR' base directory exists.">&2
fi

## Check for some working dir
DIR="\
$RPA_FILES_DIR_NAME/$RPA_NAME/${OSMOSIS_WORKING_DIRS_NAME}/changes/init \
$CA_FILES_DIR_NAME \
$LOG_FILES_DIR_NAME"
for child_area in ${CA_NAMES[@]}
  do
    DIR="${DIR} $CA_FILES_DIR_NAME/$child_area/$RT_DIRS_NAME"
done
MISSING_DIR=""
for dir in $DIR
do
if [ ! -d "$HOST_VOLUMES_BASE_DIR/$dir" ]
then
    MISSING_DIR="$MISSING_DIR $HOST_VOLUMES_BASE_DIR/$dir"
    >&2 echo -e "Error: '$HOST_VOLUMES_BASE_DIR/$dir' directory does not exist."
else
  echo "- '$dir' directory exists.">&2
fi
done

if [ ! -z "$MISSING_DIR" ]; then
    echo -e "\nAt least one working directory is missing. You could run:\n\
    mkdir -p $MISSING_DIR"
    exit 1
fi

## Check for the poly files

ITER=0
for child_area in ${CA_NAMES[@]}
  do
    POLY_FILE_RELATIVE_PATH="./conf/poly_files/${child_area}.poly"
    POLY_FILE="$here/${POLY_FILE_RELATIVE_PATH}"
    if [ ! -f $POLY_FILE ]
    then
        >&2 echo -e "\nError: '$POLY_FILE_RELATIVE_PATH' poly file does not exist."
        if [ ! -z "${CA_POLY_FILES_DOWNLOAD_URL[${ITER}]}" ]; 
        then
        DL_URL="${CA_POLY_FILES_DOWNLOAD_URL[${ITER}]}"
        echo -e "You could run:\n\n\
        wget "${DL_URL}" -O $POLY_FILE\n\n\
        or put your own .poly file under the given path ($POLY_FILE)."
        else
        echo -e "\${CA_POLY_FILES_DOWNLOAD_URL[${ITER}]} not provided.\n
        Please put your own .poly file under the given path ($POLY_FILE)."
        fi
        exit 1
    else
      echo "- '$POLY_FILE_RELATIVE_PATH' child area poly file exists">&2
    fi
  ITER=$(($ITER + 1))
done;

## Check for the replication tree
if ! curl --head --fail --silent "$RPA_RT_URL/state.txt" >/dev/null
then
    >&2 echo "\nError: replication tree is not reachable (no file behind URL '$RPA_RT_URL/state.txt')"
    exit 1
else
  echo -e "- replication tree is reachable: $RPA_RT_URL, \n\
  here is the last state.txt file:" >&2
  curl -s $RPA_RT_URL/state.txt
fi


