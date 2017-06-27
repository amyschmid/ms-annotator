#!/bin/bash
# This is simple wrapper to use cpanminus and local::lib to manage
# a virtual perl environment, see: http://stackoverflow.com/a/2980715

# Root directory to find external libraries
# Assuming this script is executed from $PATH/bin
venv_dir="../venv"
include_dir="../include"
depfile="requirements.txt"

# External libaries to append to PERL5LIB
external_libs=($include_dir/SEED/lib)

# Requested location of venv
venv_dir="$(readlink -f $venv_dir)"

# Get cpanminus and install local lib
depstr="$(cat $depfile | tr "\n" " ")"
depstr="${depstr% }"
unset PERL5LIB PERL_MM_OPT PERL_MB_OPT
perl <(wget -O - http://cpanmin.us) \
  --notest --verbose --local-lib-contained $venv_dir $depstr

# Get PERL5LIB string
unset perl5lib
for lib in ${external_libs[@]}; do
  perl5lib+="$(readlink -fn "$lib"):"
done

# Create wrapper to set @INC and start local::lib
venv_script=$(pwd)/setenv.sh
echo -n '' > $venv_script
echo "# Automatically generated script to start perl venv" >> $venv_script
echo "unset PERL5LIB PERL_MM_OPT PERL_MB_OPT" >> $venv_script
echo "eval \$(perl -I $venv_dir/lib/perl5 -Mlocal::lib=$venv_dir)" >> $venv_script
echo "export PERL5LIB=\"$perl5lib\$PERL5LIB\"" >> $venv_script
echo "Setup completed sucessfully!"
