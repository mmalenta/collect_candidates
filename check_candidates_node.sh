#!/bin/bash

source ./logging.sh
source ./constants.sh

function header() {

  labels=("Node" "# candidates" "# known" "# archives" "# plots" "# tarballs" "# known + archives")

  for label in "${labels[@]}"; do
    printf "\033[1;30;47m %-20s\033[0m " "${label}"
  done
  printf "\n"

}

function recheck_header() {

  labels=("UTC directory" "# candidates" "# known" "# archives" "# known + archives")

  for label in "${labels[@]}"; do
    printf "\033[1;30;47m %-20s\033[0m " "${label}"
  done
  printf "\n"

}

########
# Provide a more detailed check for a given day
# Instead of providing aggregated statistics for the whole day,
# provide the information for every directory in that day.
#
# Arguments:
#   node
#   parent_dir
#   date_dir
#
# Outputs:
#   Candidates and data statistics for every directory in a given day
########
function recheck_day() {

  local process_node=$1
  local parent_dir=$2
  local date_dir=$3

  recheck_header

  directories="$( ssh "${process_node}" \
    "
      cd ${parent_dir} \
        && ls -1d ${date_dir}*
    "
  )"

  for idir in ${directories}; do
    printf "\033[1m %-20s \033[m" "${idir}"

    recheck_results="$( ssh "${process_node}" \
      "
    
        cd ${parent_dir} \
          && tail -n +2 -q ${idir}/beam*/*.spccl 2> /dev/null | wc -l \
          && cat ${idir}/beam*/known_sources.dat 2> /dev/null | wc -l \
          && find ${idir} -name '*.hdf5' 2> /dev/null | wc -l
          
      "
    )"

    for result in ${recheck_results}; do
      printf "\033[1m %-20s\033[0m " "${result}"
    done

    printf "\n"

  done

  header

}

########
# Pretty-print candidate information
#
# Arguments:
#   process_node
#   candidate_results
function candidates_row() {

  local process_node=$1
  local candidate_results=$2

  printf "\033[1m %-20s\033[0m " "${process_node}"

  for result in ${candidate_results}; do
    printf "\033[1m %-20s\033[0m " "${result}"
  done

  local -i spccl_candidates
  spccl_candidates="$( echo "${candidate_results}" | awk -F ' ' '{print $1}')"
  local -i known_sources
  known_sources="$( echo "${candidate_results}" | awk -F ' ' '{print $2}')"
  local -i archive_files
  archive_files="$( echo "${candidate_results}" | awk -F ' ' '{print $3}')"

  local -i full_cand_processed
  full_cand_processed=$(( known_sources + archive_files ))
  local -i full_cand_diff
  full_cand_diff=$(( spccl_candidates - full_cand_processed ))

  if (( full_cand_diff != 0 )); then

    if (( $( echo "${full_cand_diff} >= ${spccl_candidates} * ${ERROR_THRESHOLD}" | bc ) )); then
      printf "\033[1;31m %-20s\033[0m " "${full_cand_processed}"
      printf "\n"
      ERROR "More than $( echo "${ERROR_THRESHOLD} * 100" | bc )% of candidates processed incorrectly!"
      ERROR "Got ${full_cand_processed} instead of expected ${spccl_candidates}"
      read -rp "$( echo -e "\033[1;31mWould you like to get the details of that day? [y/n/q]\033[0m " )" decision
      case "$decision" in
        y)
          WARNING "Will collect statistics for day ${date_dir}!"
          recheck_day "${process_node}" "${parent_dir}" "${date_dir}"
          ;;
        n)
          WARNING "Will continue with downloading this day like nothing happened!"
          ;;
        q)
          INFO "Will quit now!"
          exit 0
          ;;
        *)
          ERROR "Unrecognised option \"${decision}\"!"
          ERROR "Your job was to choose between y or n..."
          ERROR "Will now quit!"
          exit 1
          ;;
      esac
    else
      printf "\033[1;33m %-20s\033[0m " "${full_cand_processed}"
    fi

  else
    printf "\033[1m %-20s\033[0m " "${full_cand_processed}"
  fi

}

function check_candidates_node() {

  local process_node=$1
  local parent_dir=$2
  local date_dir=$3

  candidate_results="$( ssh "${process_node}" \
    "
      cd ${parent_dir} \
        && tail -n +2 -q ${date_dir}*/beam*/*.spccl | wc -l \
        && cat ${date_dir}*/beam*/known_sources.dat 2> /dev/null | wc -l \
        && find ${date_dir}* -name '*.hdf5' 2> /dev/null | wc -l \
        && find ${date_dir}* -name '*.jpg' 2> /dev/null | wc -l \
        && find ${date_dir}* -name '*.tar' 2> /dev/null | wc -l \
    "
  )"


  candidate_results="$( echo "${candidate_results}" | tr '\n' ' ' )"

  candidates_row "${process_node}" "${candidate_results}"

}