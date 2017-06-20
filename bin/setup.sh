#!/bin/bash
# This is simple wrapper to use cpanminus and local::lib to manage
# a virtual perl environment, see: http://stackoverflow.com/a/2980715
set -eo pipefail

# Root directory to find external libraries
venv_dir="../venv"
incdir="../include"

# External libaries to append to PERL5LIB
external_libs=($incdir/SEED-API/lib)

# Requested location of venv
venv_dir="$(readlink -f $venv_dir)"

# Get cpanminus and install local lib
unset PERL5LIB PERL_MM_OPT PERL_MB_OPT
/usr/bin/perl <(wget -O- http://cpanmin.us) --local-lib "$venv_dir" "App::cpanminus" "local::lib"

# Get PERL5LIB string
unset plib
for lib in ${external_libs[@]}; do
	plib+="$(readlink -f $lib):"
done

# Create wrapper to set @INC and start local::lib
venv_script=$(pwd)/setenv.sh
echo -n '' > $venv_script
echo "# Automatically generated script to start perl venv" >> $venv_script
echo "unset PERL5LIB PERL_MM_OPT PERL_MB_OPT" >> $venv_script
echo "eval \$(perl -I $venv_dir/lib/perl5 -Mlocal::lib=$venv_dir)" >> $venv_script
echo "export PERL5LIB=\"$plib\$PERL5LIB\"" >> $venv_script
