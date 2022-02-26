#!/usr/bin/perl

# $Id$
# $Revision$
# $Date$

use strict;
use warnings;
use vars qw/ $VERSION /;

$VERSION = '0.01';

use Time::HiRes 'time','sleep';

my $startruntimer = time;  #timer for entire test run
my $result = `perl ../wi.pl --version`;
my $endruntimer = time;

my $thousand = 1000;
my $totalruntime = (int($thousand * ($endruntimer - $startruntimer)) / $thousand;  #elapsed time rounded to thousandths

print $result;

print "Startup time:$totalruntime\n";
