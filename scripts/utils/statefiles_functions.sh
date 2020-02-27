#!/bin/bash

## README
# Useful functions to manipulate OSM replication trees paths and sequence numbers

# Settings
set -e # Be sure we fail on error and output debugging information
trap 'echo "$0: error on line $LINENO"' ERR
#set -x # Print commands and their arguments as they are executed

function getAttributeFromStateFile () {
    statefile=$1
    attribute=$2
    # Get sequenceNumber line from latest state.txt file
    attribute_line=$(grep -i "$attribute" ${statefile})
    # Remove 'sequenceNumber=' prefix
    attribute_value=${attribute_line#${attribute}=}
    if [ "$attribute" == "sequenceNumber" ]
    # Drop leading zeros (10# converts the number from base 10 to base 10 causing any leading zeros to be dropped)
    then
        attribute_value=$((10#${attribute_value}))
    fi
    # display some informations but output to standard error (stdout used to return a value)
    echo -e "\n'${FUNCNAME[0]}' function\n\
    - 'statefile': $statefile\n\
    - 'attribute': $attribute\n\
    - value: $attribute_value">&2
    # Return attribute_value
    echo $attribute_value
}

function getRTFileDirFromSeqNumber () {
    # Ex: 
    #   - if 'sequenceNumber=47', rt_files_dir=000/000 (files are '/000/000/047.(state.txt|osc.gz)')
    #   - if 'sequenceNumber=2004', rt_files_dir=000/002 (files are '/000/002/004.(state.txt|osc.gz)')
    sequence_number=$1
    # add leading zeros to get a fixed width of 9 ('12' becomes '000000012')
	printf -v sequence_number "%09d" $sequence_number
    # cut every three characters to get files full path ('000/000/012')
	rt_files_root_dir=`echo $sequence_number | cut -c 1-3`
	rt_files_sub_dir=`echo $sequence_number | cut -c 4-6`
    rt_files_dir=$rt_files_root_dir/$rt_files_sub_dir
    echo $rt_files_dir
}

function getRTFileNameFromSeqNumber () {
    # Ex:
    #   - if 'sequenceNumber=47', rt_files_name=047 (files are '/000/000/047.(state.txt|osc.gz)')
    #   - if 'sequenceNumber=2004', rt_files_name=004 (files are '/000/002/004.(state.txt|osc.gz)')
    sequence_number=$1
    # add leading zeros to get a fixed width of 9 ('12' becomes '000000012')
	printf -v sequence_number "%09d" $sequence_number
    # get last 3 characters ('xxx/xxx/012')
	rt_files_name=`echo $sequence_number | cut -c 7-9`
    echo $rt_files_name
}

# OLD FASHION - START
    #SEQUENCE_NUMBER_INCREMENTED_MOD_1M=$((${SEQUENCE_NUMBER_INCREMENTED}/1000000))
    #OSC_AND_STATE_FILES_ROOT_DIR=$SEQUENCE_NUMBER_INCREMENTED_MOD_1M
    #OSC_AND_STATE_FILES_SUB_DIR=$(((${SEQUENCE_NUMBER_INCREMENTED}-1000000*${SEQUENCE_NUMBER_INCREMENTED_MOD_1M})/1000))
    #OSC_AND_STATE_FILES_NUMBER=$(((${SEQUENCE_NUMBER_INCREMENTED}-1000000*${SEQUENCE_NUMBER_INCREMENTED_MOD_1M})%1000))
    #printf -v OSC_AND_STATE_FILES_ROOT_DIR "%03d" OSC_AND_STATE_FILES_ROOT_DIR
    #printf -v OSC_AND_STATE_FILES_SUB_DIR "%03d" $OSC_AND_STATE_FILES_SUB_DIR
    #printf -v OSC_AND_STATE_FILES_NUMBER "%03d" $OSC_AND_STATE_FILES_NUMBER
# OLD FASHION - ENDSTATE_FILENUMBER}.state.txt
