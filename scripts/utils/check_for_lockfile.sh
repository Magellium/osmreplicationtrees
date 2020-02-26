#!/bin/bash

# Useful functions to manipulate OSM replication trees paths 
# and sequence numbers

# Settings
set -e # Be sure we fail on error and output debugging information
trap 'echo "$0: error on line $LINENO"' ERR
#set -x # Print commands and their arguments as they are executed

function checkForLockFile () {
    lockfile=$1
    lockfileexists=FALSE
    if [ -f ${lockfile} ]; then
      # display some informations but output to standard error (stdout used to return a value)
      if [ "$(ps -p `cat ${lockfile}` | wc -l)" -gt 1 ]; then
        echo "ERROR: ${lockfile} exists and referenced process still running">&2
        cat ${lockfile}>&2
        lockfileexists=TRUE
      else
        echo "Delete existing ${lockfile} \(referenced process not running anymore\)">&2
        rm ${lockfile}
      fi
    else
      echo "${lockfile} does not exist">&2
    fi
    # Return result
    echo ${lockfileexists}
}