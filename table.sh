#!/bin/bash

########
# Pretty-prints candidate table header
#
# Arguments:
#   None
########
function candidate_header() {

  labels=("Node" "# candidates" "# known" "# archives" "# plots" "# tarballs" "# known + archives")

  for label in "${labels[@]}"; do
    printf "\033[1;30;47m %-20s\033[0m " "${label}"
  done
  printf "\n"

}

########
# Pretty-prints node recheck candidate header
# This table contains information on the number of candidates, known
# sources and archives per UTC directory for the selected node and day
#
# Arguments:
#   None
########
function recheck_header() {

  labels=("UTC directory" "# candidates" "# known" "# archives" "# known + archives")

  for label in "${labels[@]}"; do
    printf "\033[1;30;47m %-20s\033[0m " "${label}"
  done
  printf "\n"

}

