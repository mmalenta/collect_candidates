#!/bin/bash

source ./logging.sh
source ./constants.sh

source ./check_candidates_node.sh
source ./collect_candidates_node.sh

function validate_directories() {

  if [[ ! -d  "${STORAGE_DIR}" ]]; then
    ERROR "Storage directory ${STORAGE_DIR} does not exist!"
    exit 1
  fi

}

########
# Checks the candidates on all the nodes
#
# Globals:
#   available_nodes
#   collect_day
#
# Arguments:
#   None
########
function check_candidates() {

  for node in "${available_nodes[@]}"; do
    check_candidates_node "${node}" "${OUTPUT_DIR}" "${collect_day}"
  done

}


########
# Collects the candidates on all the nodes
#
# Globals:
#   available_nodes
#   collect_day
#
# Arguments:
#   None
########
function collect_candidates() {

  for node in "${available_nodes[@]}"; do
    collect_candidates_node "${node}" "${OUTPUT_DIR}" "${collect_day}"
  done

}

########
# Check the disk usage by the data in the staging areas
#
# Globals:
#   collect_day
#
# Arguments:
#   None
#
# Output:
#   Report on the required disk space. Warn if the used disk space would
#   take us under the specified threshold and ask what to do. 
#   Error if there is not enough disk space at all.
########
function check_disk_usage() {

  local -i nodes_used_space_mb
  nodes_used_space_mb=0

  for node in "${available_nodes[@]}"; do

    node_mb="$( ssh "${node}" \
      "
      
        cd ${OUTPUT_DIR}/collected_hdf5/ \
        && du -BM ${collect_day} | sed 's/^\([0-9]*\)M.*/\1/g'
      
      "
    )"

    nodes_used_space_mb=$(( nodes_used_space_mb + node_mb ))

  done

  available_space_mb="$( echo "$(df "${STORAGE_DIR}" --output=avail | tail -n 1) / 1024 " | bc )"

  if (( nodes_used_space_mb >= available_space_mb )); then
    ERROR "Not enough space available on ${STORAGE_DIR} to download the data!"
    ERROR "Requested ${nodes_used_space_mb}MiB when ${available_space_mb} is available!"
    exit 1
  elif (( available_space_mb - nodes_used_space_mb <= STORAGE_LIMIT_MIB )); then
    WARNING "Downloading the data would take you below the safety threshold of ${STORAGE_LIMIT_GIB}GiB"
    WARGING "Requested ${nodes_used_space_mb}MiB when ${available_space_mb} is available!"
    read -rp "$( echo -e "\033[1;33mWould you still like to continue? [y/n]\033[0m " )" decision
    case "$decision" in
      y)
        WARNING "Will download the data! If the head node dies, you have been warned!"
        ;;
      n)
        INFO "Good! Better be safe than sorry!"
        exit 0
        ;;
      *)
        ERROR "Unrecognised option \"${decision}\"!"
        ERROR "Your job was to choose between y or n..."
        ERROR "Will now quit!"
        exit 1
        ;;
    esac
  fi

}

########
# Validate the provided date
# First check if the date is of the correct yyyy-mm-dd format
# Then check if the date is earlier than the current date - warn user
# if that the case and ask what to do moving forward - it is possible
# that the user wants to pull a partial current day.
#
# Globals:
#   collect_day
#
# Arguments:
#   None
#
# Outputs:
#   Validation stage and possibly asking for the user input, depending
#   on the status of validation
########
function validate_day() {

  DATE_REGEX="^[0-9]{4}-[0-9]{2}-[0-9]{2}$"  

  if [[ ! $collect_day =~ $DATE_REGEX ]]; then
    ERROR "Invalid date provided! yyyy-mm-dd format required!"
    exit 1
  fi

  today="$( date +%Y-%m-%d )"

  if [[ "${collect_day}" > "${today}" ]]; then
    ERROR "Sorry, cannot collect data from the future!"
    ERROR "Today is ${today} and you requested ${collect_day}"
    exit 1
  fi

  if [[ "${collect_day}" == "${today}" ]]; then
    WARNING "You requested data from today!"
    WARNING "This may cause incomplete data to be downloaded!"

    read -rp "$( echo -e "\033[1;33mWould you still like to continue? [y/n]\033[0m " )" decision
    case "$decision" in
      y)
        WARNING "Will collect the possibly incomplete ${collect_day}!"
        ;;
      n)
        INFO "Good! Use a better date next time!"
        exit 0
        ;;
      *)
        ERROR "Unrecognised option \"${decision}\"!"
        ERROR "Your job was to choose between y or n..."
        ERROR "Will now quit!"
        exit 1
        ;;
    esac
  fi
}

########
# Get the list of available nodes
#
# Globals:
#   available_nodes
#   collect_day
#
# Arguments:
#   None
########
function get_nodes() {

  old_ifs=$IFS
  IFS=$'\n'
  for node in $( rocks run host "ls -1d ${OUTPUT_DIR}/${collect_day}* 2> /dev/null | wc -l" collate=true ); do

    node_name="$( echo "${node}" | awk -F ': ' '{print $1}' | xargs )"
    num_directories="$( echo "${node}" | awk -F ': ' '{print $2}' | xargs )"

    if [[ "${num_directories}" == "down" ]]; then
      ERROR "Node ${node_name} is down!"
      continue
    fi

    if (( num_directories == 0 )); then
      WARNING "Node ${node_name} has no directories for ${collect_day}"
    else
      available_nodes[${#available_nodes[@]}]="${node_name}"
    fi

  done
  IFS=$old_ifs

  INFO "Available nodes:"
  for node in "${available_nodes[@]}"; do
    echo "${node}"
  done

}

########
# Print out the help message, describing all of the command line
# options.
#
# Arguments:
#   None
#
# Outputs:
#   Help information
########
function help() {

  echo "Collect the HDF5 archives"
  echo
  INFO "Usage: collect_candidates.sh [OPTIONS]"
  echo
  echo "Available options:"
  echo "-h print this message"
  echo "-d day to collect in the format yyyy-mm-dd"
  echo
  exit 0

}

function main() {

  if (( EUID == 0 )); then
    ERROR "You are not allowed to run this script with root account!"
    exit 1
  fi

  optstring=":hd:"

  while getopts "${optstring}" arg; do
    case "${arg}" in
      h) help ;;
      d) collect_day="${OPTARG}" ;;
      ?) 
        ERROR "Invalid option -${OPTARG}"
        ERROR "There are a total of 2 options. How hard can it be?"
        help
        exit 2
        ;;  
    esac
  done

  if [[ -z "${collect_day}" ]]; then
    ERROR "Collection day not specified!"
    exit 1
  fi

  INFO "Will process with the following default configuration:"
  echo "Output data directory: ${OUTPUT_DIR}"
  echo "Storage data directory: ${STORAGE_DIR}"

  validate_directories

  validate_day

  declare -a available_nodes

  get_nodes

  check_candidates

  collect_candidates

  check_disk_usage

}

main "$@"