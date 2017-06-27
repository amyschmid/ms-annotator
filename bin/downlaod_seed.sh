#!/bin/bash
#
# Round about method to download from the SEED repository 
# Avalable repositories are available here: http://biocvs.mcs.anl.gov/
# 
# Given a directory known to SEED, this script will recursivly download it contents
# 
set -eo pipefail

cvs_url="http://biocvs.mcs.anl.gov/"

usage() {
  echo "Download contents of: $cvs_url"
  echo "Usage $0 <prefix> <remote>:"
  echo "  <prefix> is local directory to download files"
  echo "  <remote> is the remote directory to be downloaded"
  exit 1
}

error() {
  echo -e "Error: $@\n"
  usage
}

get_urls() {
  # Given root dir and location of html file
  # Prints list of files/dirs in root directory
  local html_dir="${1/$remote_dir/$temp_dir}"
  local html_file=$html_dir/$(basename $1).html
  [[ ! -d "$html_dir" ]] && mkdir -p $html_dir

  if [ ! -e $html_file ]; then
    wget --no-verbose -O $html_file $cvs_url/viewcvs.cgi/$1
    # grep -v exits with non-zero when nothing is reported
    set +e
    grep "href.*viewcvs.cgi/$1" "$html_file" \
      | sed -r 's/.*href="([^"]+).*/\1/g' \
      | sed -r 's/\?.*//g' \
      | sort -u \
      | grep -v "$cvs_dir/viewcvs.cgi/$1/$"
    set -e
  fi
}

process_dir() {
  # Download root directory sturcture
  dir_links=("$(get_urls $1)")

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
    if [ ! -d "$(dirname $local_file)" ]; then
      mkdir -p "$(dirname $local_file)"
      dir_count=$(( $dir_count + 1 ))
    fi
    wget --no-verbose -O "$local_file" "${cvs_url}${link}?view=co"
    file_count=$(( $file_count + 1))
  done
}

declare -a subdirs
declare -a savelinks

prefix="$1"
remote_dir="$2"
prefix_dir="${prefix%/}"
temp_dir="$prefix/temp"

# Ensure proper parameters
[[ $# -ne 2 ]] && error "Please enter paths for <prefix> and <remote>"
[[ -d $prefix_dir/$remote_dir ]] && error "Download path: $prefix_dir/$remote_dir already exists, remove and try again"
[[ -d $temp_dir ]] && (rm -r "$temp_dir" && mkdir -p "$temp_dir")

# Get files to download
process_dir "$remote_dir"

# Download files  / dirs
file_count=0
dir_count=0
download_links "${savelinks[@]}"

# Cleanup
rm -r "$prefix_dir/temp"

echo "Sucessfully complete!"
echo "Downloaded $file_count files and $dir_count directories"


