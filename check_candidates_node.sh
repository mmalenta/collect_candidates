#!/bin/bash

source ./logging.sh
source ./constants.sh

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

  ssh "${process_node}" \
    "
    
      cd ${parent_dir} \
        && for idir in ${date_dir}*; do
            echo \${idir} \
              && echo 'Number of candidates:' \
              && tail -n +2 -q \${idir}/beam*/*.spccl 2> /dev/null | wc -l \
              && echo 'Number of known sources:' \
              && cat \${idir}/beam*/known_sources.dat 2> /dev/null | wc -l \
              && echo 'Number of archives:' \
              && find \${idir}* -name '*.hdf5' 2> /dev/null | wc -l \
              && echo 'Number of plots:' \
              && find \${idir}* -name '*.jpg' 2> /dev/null | wc -l \
              && echo 'Number of tarballs:' \
              && find \${idir}* -name '*.tar' 2> /dev/null | wc -l \
              && echo 
          done
    "

  read -rp "$( echo -e "\033[1;33mWould you like to download that day? [y/n]\033[0m " )" decision

  case "$decision" in
    y)
      WARNING "Will download the possibly incomplete ${date_dir}!"
      ;;
    n)
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
        && cat ${date_dir}*/beam*/Plots/used* 2> /dev/null | wc -l
    "
  )"

  candidate_results="$( echo "${candidate_results}" | tr '\n' ' ' )"

  local -i spccl_candidates
  spccl_candidates="$( echo "${candidate_results}" | awk -F ' ' '{print $1}')"
  local -i known_sources
  known_sources="$( echo "${candidate_results}" | awk -F ' ' '{print $2}')"
  local -i archive_files
  archive_files="$( echo "${candidate_results}" | awk -F ' ' '{print $3}')"
  local -i plot_files
  plot_files="$( echo "${candidate_results}" | awk -F ' ' '{print $4}')"
  local -i tarball_files
  tarball_files="$( echo "${candidate_results}" | awk -F ' ' '{print $5}')"
  local -i plots_made
  plots_made="$( echo "${candidate_results}" | awk -F ' ' '{print $6}')"

  INFO "Node ${process_node}:"
  INFO "Number of candidates:"
  echo "${spccl_candidates}"
  INFO "Number of known sources:"
  echo "${known_sources}"
  INFO "Number of archives:"
  echo "${archive_files}"
  INFO "Number of plots:"
  echo "${plot_files}"
  INFO "Number of tarballs:"
  echo "${tarball_files}"
  INFO "Total plots done (including duplicates):"
  echo "${plots_made}"

  local -i full_cand_processed
  full_cand_processed=$(( known_sources + archive_files ))
  local -i full_cand_diff
  full_cand_diff=$(( spccl_candidates - full_cand_processed ))
  
  INFO "Number of known sources + archives:"
  if (( full_cand_diff != 0 )); then

    if (( $( echo "${full_cand_diff} >= ${spccl_candidates} * ${ERROR_THRESHOLD}" | bc ) )); then
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
    fi

  else
    echo "${full_cand_processed}"
  fi

}