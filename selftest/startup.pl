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
my $result = `perl ../webinject.pl --version`;
my $endruntimer = time;

my $totalruntime = (int(1000 * ($endruntimer - $startruntimer)) / 1000);  #elapsed time rounded to thousandths

print $result;

print "Startup time:$totalruntime\n";
