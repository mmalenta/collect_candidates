#!/bin/bash

########
# Get candidates from the observing directories to the staging
# area on each node. Check the disk usage and download if enough
# space is available on the head node
#
# Arguments:
#   process_node
#   parent_dir
#   storage_dir
#   date_dir
#
# Outputs:
#   Information on the number of candidates and disk usage
########
function get_candidates_node() {

  local process_node=$1
  local parent_dir=$2
  local storage_dir=$3
  local date_dir=$4

  ssh "${process_node}" \
    "
      cd ${parent_dir}/collected_hdf5/${date_dir}/ \
        && rsync --ignore-existing *.hdf5 tuse:${storage_dir}/${date_dir}
    "

}