#!/bin/bash

# Load environment and add lib to PERL5LIB
source bin/setenv.sh

perl -I$(pwd)/lib -e 'use MSAnnotator::Main qw(main); main();'

