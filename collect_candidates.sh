#!/bin/bash

source ./logging.sh

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

  for node in $( rocks run host "ls -1d ${OUTPUT_DIR}/${collect_day}* 2> /dev/null | wc -l" collate=true ); do

    node_name="$( echo "${node}" | awk -F ': ' '{print $1}') "
    num_directories="$( echo "${node}" | awk -F ': ' '{print $2}') "

    if [[ "${num_directories}" == "down" ]]; then
      WARNING "Node ${node_name} is down!"
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

  validate_day

  declare -a available_nodes



}

main "$@"