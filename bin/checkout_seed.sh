#!/bin/bash
#
# Hacky method to download directories from the SEED repository 
# Avalable repositories are available here: http://biocvs.mcs.anl.gov/
# 
# Given a directory known to SEED, this script will recursivly download it contents
# 
set -eo pipefail

cvs_url="http://biocvs.mcs.anl.gov/"

usage() {
  echo "Usage $0 <prefix> <remote>"
  echo "Download contents of: $cvs_url"
  echo "Where:"
  echo "  <prefix> is local directory to download files"
  echo "  <remote> is the remote directory to be downloaded"
  exit $1
}

error() {
  echo -e "Error: $@\n"
  usage 1
}

get_urls() {
  # Given root dir and location of html file
  # Prints list of files/dirs in root directory
  local html_dir="${1/$checkout_dir/$temp_dir}"
  local html_file=$html_dir/$(basename $1).html
  [[ ! -d "$html_dir" ]] && mkdir -p $html_dir

  if [ ! -e $html_file ]; then
    wget --no-verbose -O $html_file $cvs_url/viewcvs.cgi/$1
    grep "href.*viewcvs.cgi/$1" "$html_file" \
      | sed -r 's/.*href="([^"]+).*/\1/g' \
      | sed -r 's/\?.*//g' \
      | sort -u \
      | grep -v "$cvs_dir/viewcvs.cgi/$1/$"
  fi
}

process_dir() {
  # Download root directory sturcture
  dir_links=($(get_urls $1))
  n=$(( $n + 1 ))
  #[ $n -eq 3 ] && exit

  # First slurp up all files
  for link in ${dir_links[@]}; do
    if [ "${link: -1}" != "/" ]; then
      savelinks+=("$link")
    else
      dir=$(echo "$link" | sed -r 's/\/viewcvs.cgi\/(.*)\/$/\1/g')
      subdirs+=("$dir")
    fi
  done
  
  # Then, work on subdirs
  for i in "${!subdirs[@]}"; do
    next_dir="${subdirs[$i]}"
    [[ -z $next_dir ]] && continue
    unset subdirs[$i]
    process_dir $next_dir
  done
}

download_links() {
  for link in "$@"; do
    local_file="$prefix_dir/${link#/viewcvs.cgi/}"
    [ ! -d "$(dirname $local_file)" ] && mkdir -p "$(dirname $local_file)"
    wget --no-verbose -O "$local_file" "${cvs_url}${link}?view=co"
  done
}

prefix="$1"
checkout_dir="$2"
prefix_dir="${prefix%/}"
temp_dir="$prefix/temp/$checkout_dir"

[[ $# -ne 2 ]] && error "Please enter values for <prefix> and <remote>"
[[ -d $prefix_dir/$checkout_dir ]] && error "Download path: $prefix_dir/$checkout_dir already exists, remove and try again"
[[ -d $temp_dir ]] && rm -r "$temp_dir"

mkdir -p "$temp_dir"

declare -a subdirs
declare -a savelinks
process_dir "$checkout_dir"
download_links "${savelinks[@]}"
rm -r "$temp_dir"




