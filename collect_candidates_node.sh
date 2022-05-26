#!/bin/bash

source ./constants.sh
source ./logging.sh

########
# Get candidates from the observing directories to the staging
# area on each node. 
#
# Arguments:
#   node
#   parent_dir
#   date_dir
#
# Outputs:
#   Information on the number of candidates and disk usage
########
function collect_candidates_node() {

  local process_node=$1
  local parent_dir=$2
  local date_dir=$3

  total_archives="$( ssh "${process_node}" \
    "
      cd ${parent_dir} \
        && find ${date_dir}* -name '*.hdf5' 2> /dev/null | wc -l
    "
  )"

  moved_archives="$( ssh "${process_node}" \
    "

      cd ${parent_dir} \
        && mkdir collected_hdf5/${date_dir} -p \
        && mv ${date_dir}*/beam*/*.hdf5 collected_hdf5/${date_dir} \
        && find collected_hdf5/${date_dir} -name '*.hdf5' 2> /dev/null | wc -l

    "
  )"

  if (( total_archives > moved_archives )); then
    ERROR "Something went wrong when moving archives on ${process_node}"
    ERROR "Will now quit!"
    exit 1
  fi


}