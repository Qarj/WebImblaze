#!/usr/bin/perl

# $Id$
# $Revision$
# $Date$

use strict;
use warnings;
use vars qw/ $VERSION /;

$VERSION = '1.80';

#removed the -w parameter from the first line so that warnings will not be displayed for code in the packages

#    Copyright 2004-2006 Corey Goldberg (corey@goldb.org)
#    Extensive updates 2015-2016 Tim Buckland
#
#    This file is part of WebInject.
#
#    WebInject is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    WebInject is distributed in the hope that it will be useful,
#    but without any warranty; without even the implied warranty of
#    merchantability or fitness for a particular purpose.  See the
#    GNU General Public License for more details.


#use Selenium::Remote::Driver; ## to use the clean version in the library
#use Driver; ## using our own version of the package - had to stop it from dieing on error
my $sel; ## support for Selenium test cases

use LWP;
use URI::URL; ## So gethrefs can determine the absolute URL of an asset, and the asset name, given a page url and an asset href
use File::Basename; ## So gethrefs can determine the filename of the asset from the path
use HTTP::Request::Common;
use HTTP::Cookies;
use XML::Simple;
use Time::HiRes 'time','sleep';
use Getopt::Long;
use Crypt::SSLeay;  #for SSL/HTTPS (you may comment this out if you don't need it)
local $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 'false';
use IO::Socket::SSL qw( SSL_VERIFY_NONE );
use IO::Handle;
use HTML::Entities; #for decoding html entities (you may comment this out if aren't using decode function when parsing responses)
use Data::Dumper;  #uncomment to dump hashes for debugging
use MIME::QuotedPrint; ## for decoding quoted-printable with decodequotedprintable parameter and parseresponse dequote feature

local $| = 1; #don't buffer output to STDOUT

my ($timestamp, $dirname, $testfilename);
my (%parsedresult);
my (%varvar);
my ($useragent, $request, $response);
my ($latency, $verificationlatency, $screenshotlatency);
my (%teststeptime); ## record in a hash the latency for every step for later use
my ($cookie_jar, @httpauth);
my ($xnode, $stop);
my ($runcount, $totalruncount, $casepassedcount, $casefailedcount, $passedcount, $failedcount);
my ($totalresponse, $avgresponse, $maxresponse, $minresponse);
my (@casefilelist, $currentcasefile, $currentcasefilename, $casecount, $isfailure, $verifynegativefailed);
my (%case);
my (%config);
my ($currentdatetime, $totalruntime, $starttimer, $endtimer);
my ($opt_configfile, $opt_version, $opt_output, $opt_autocontroller, $opt_port, $opt_proxy, $opt_basefolder, $opt_driver, $opt_proxyrules, $opt_ignoreretry, $opt_help); ## $opt_port, $opt_basefolder, $opt_proxy, $opt_proxyrules

my (@lastpositive, @lastnegative, $lastresponsecode, $entrycriteriaok, $entryresponse); ## skip tests if prevous ones failed
my ($testnum, $xmltestcases); ## $testnum made global
my ($testnumlog, $desc1log, $desc2log); ## log separator enhancement
my ($retry, $retries, $globalretries, $retrypassedcount, $retryfailedcount, $retriesprint, $jumpbacks, $jumpbacksprint); ## retry failed tests
my ($forcedretry); ## force retry when specific http error code received
my ($sanityresult); ## if a sanity check fails, execution will stop (as soon as all retries are exhausted on the current test case)
my ($starttime); ## to store a copy of $startruntimer in a global variable
my ($elapsedseconds, $elapsedminutes); ## number of seconds and minutes since starting till now - always rounded up
my ($cmdresp); ## response from running a terminal command
my ($selresp); ## response from a Selenium command
my (@verifyparms); ## friendly error message to show when an assertion fails
my (@verifycountparms); ## regex match occurences must much a particular count for the assertion to pass
my ($output, $outputfolder); ## output path including possible filename prefix, output path without filename prefix
my ($outsum); ## outsum is a checksum calculated on the output directory name. Used to help guarantee test data uniqueness where two WebInject processes are running in parallel.
my ($userconfig); ## support arbirtary user defined config
my $totalassertionskips = 0;

my (@pages); ## page source of previously visited pages
my (@pagenames); ## page name of previously visited pages
my (@pageupdatetimes); ## last time the page was updated in the cache

my $chromehandle = 0; ## windows handle of chrome browser window - for screenshots

## put the current date and time into variables - startdatetime - for recording the start time in a format an xsl stylesheet can process
my @MONTHS = qw(01 02 03 04 05 06 07 08 09 10 11 12);
my @WEEKDAYS = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
my ($SECOND, $MINUTE, $HOUR, $DAYOFMONTH, $MONTH, $YEAROFFSET, $DAYOFWEEK, $DAYOFYEAR, $DAYLIGHTSAVINGS) = localtime;
my $YEAR = 1900 + $YEAROFFSET;
my $YY = substr $YEAR, 2; #year as 2 digits
$DAYOFMONTH = sprintf '%02d', $DAYOFMONTH;
my $WEEKOFMONTH = int(($DAYOFMONTH-1)/7)+1;
my $STARTDATE = "$YEAR-$MONTHS[$MONTH]-$DAYOFMONTH";
$MINUTE = sprintf '%02d', $MINUTE; #put in up to 2 leading zeros
$SECOND = sprintf '%02d', $SECOND;
$HOUR = sprintf '%02d', $HOUR;
my $TIMESECONDS = ($HOUR * 60 * 60) + ($MINUTE * 60) + $SECOND;

my $cwd = (`cd`); ## find current Windows working directory using backtick method
$cwd =~ s/\n//g; ## remove newline character

my ($counter); ## keeping track of the loop we are up to
$counter = 0;

my $hostname = `hostname`; ##no critic(ProhibitBacktickOperators) ## Windows hostname
$hostname =~ s/\r|\n//g; ## strip out any rogue linefeeds or carriage returns
my $concurrency = 'null'; ## current working directory - not full path
my $png_base64; ## Selenium full page grab screenshot

my ( $HTTPLOGFILE, $RESULTS, $RESULTSXML ); ## output file handles

engine();


#------------------------------------------------------------------
sub engine {

    my ($startruntimer, $endruntimer, $repeat, $start);
    my ($casefilecheck); ## removed $testnum, $xmltestcases from here, made global

    getdirname();  #get the directory webinject engine is running from

    getoptions();  #get command line options

    whackoldfiles();  #delete files leftover from previous run (do this here so they are whacked each run)

    startseleniumbrowser();  #start selenium browser if applicable. If it is already started, close browser then start it again.

    startsession(); #starts, or restarts the webinject session

    processcasefile();

    #add proxy support if it is set in config.xml
    if ($config{proxy}) {
        $useragent->proxy(['http', 'https'], "$config{proxy}")
    }

    #add http basic authentication support
    #corresponds to:
    #$useragent->credentials('servername:portnumber', 'realm-name', 'username' => 'password');
    if (@httpauth) {
        #add the credentials to the user agent here. The foreach gives the reference to the tuple ($elem), and we
        #deref $elem to get the array elements.
        foreach my $elem(@httpauth) {
            #print "adding credential: $elem->[0]:$elem->[1], $elem->[2], $elem->[3] => $elem->[4]\n";
            $useragent->credentials("$elem->[0]:$elem->[1]", "$elem->[2]", "$elem->[3]" => "$elem->[4]");
        }
    }

    #change response delay timeout in seconds if it is set in config.xml
    if ($config{timeout}) {
        $useragent->timeout("$config{timeout}");  #default LWP timeout is 180 secs.
    }

    #open file handles
    open( $HTTPLOGFILE, '>' ,"$output".'http.log' ) or die "\nERROR: Failed to open http.log file\n\n";
    open( $RESULTS, '>', "$output".'results.html' ) or die "\nERROR: Failed to open results.html file\n\n";
    open( $RESULTSXML, '>', "$output".'results.xml' ) or die "\nERROR: Failed to open results.xml file\n\n";

    if ($output =~ m~\\([^\\]*)\\$~s) { ## match between the penultimate \ and the final \ ($ means character after end of string)
        $concurrency = $1;
    }

    $outsum = unpack("%32C*", $output); ## checksum of output directory name - for concurrency
    #print "outsum $outsum \n";

    print {$RESULTSXML} qq|<results>\n\n|;  #write initial xml tag
    writeinitialhtml();  #write opening tags for results file

    unless ($xnode) { #skip regular STDOUT output if using an XPath
        writeinitialstdout();  #write opening tags for STDOUT.
    }

    $totalruncount = 0;
    $casepassedcount = 0;
    $casefailedcount = 0;
    $passedcount = 0;
    $failedcount = 0;
    $totalresponse = 0;
    $avgresponse = 0;
    $maxresponse = 0;
    $minresponse = 10000000; #set to large value so first minresponse will be less
    $stop = 'no';

    $globalretries=0; ## total number of retries for this run across all test cases

    $currentdatetime = localtime time;  #get current date and time for results report
    $startruntimer = time();  #timer for entire test run
    $starttime = $startruntimer; ## need a global variable to make a copy of the start run timer

    foreach (@casefilelist) { #process test case files named in config

        $currentcasefile = $_;
        $currentcasefilename = basename($currentcasefile); ## with extension
        $testfilename = fileparse($currentcasefile, '.xml'); ## without extension

        $casefilecheck = ' ';

        convtestcases();

        fixsinglecase();

        $xmltestcases = XMLin("$outputfolder$currentcasefilename.$$.tmp", VarAttr => 'varname'); #slurp test case file to parse (and specify variables tag)
        #print Dumper($xmltestcases);  #for debug, dump hash of xml
        #print keys %{$configfile};  #for debug, print keys from dereferenced hash

        #delete the temp file as soon as we are done reading it
        if (-e "$outputfolder$currentcasefilename.$$.tmp") { unlink "$outputfolder$currentcasefilename.$$.tmp"; }

        $repeat = $xmltestcases->{repeat};  #grab the number of times to iterate test case file
        unless ($repeat) { $repeat = 1; }  #set to 1 in case it is not defined in test case file

        $start = $xmltestcases->{start};  #grab the start for repeating (for restart)
        unless ($start) { $start = 1; }  #set to 1 in case it is not defined in test case file

        $counter = $start - 1; #so starting position and counter are aligned

        foreach ($start .. $repeat) {

            $counter = $counter + 1;
            $runcount = 0;
            $jumpbacksprint = ""; ## we do not indicate a jump back until we actually jump back
            $jumpbacks = 0;

            my @teststeps = sort {$a<=>$b} keys %{$xmltestcases->{case}};
            my $numsteps = scalar @teststeps;

TESTCASE:   for (my $stepindex = 0; $stepindex < $numsteps; $stepindex++) {

                $testnum = $teststeps[$stepindex];

                ## use $testnumlog for all testnum output, add 10000 in case of repeat loop
                $testnumlog = $testnum + ($counter*10000) - 10000;

                if ($xnode) {  #if an XPath Node is defined, only process the single Node
                    $testnum = $xnode;
                }

                $isfailure = 0;
                $retries = 1; ## we increment retries after writing to the log
                $retriesprint = ""; ## the printable value is used before writing the results to the log, so it is one behind, 0 being printed as null

                $timestamp = time();  #used to replace parsed {timestamp} with real timestamp value

                $case{useragent} = $xmltestcases->{case}->{$testnum}->{useragent}; ## change the user agent
                if ($case{useragent}) {
                    $useragent->agent($case{useragent});
                }

                $case{testonly} = $xmltestcases->{case}->{$testnum}->{testonly}; ## skip test cases marked as testonly when running against production
                if ($case{testonly}) { ## is the testonly value set for this testcase?
                    if ($config{testonly}) { ## if so, does the config file allow us to run it?
                        ## run this test case as normal since it is allowed
                    }
                    else {
                          print {*STDOUT} "Skipping Test Case $testnum... (TESTONLY)\n";
                          print {*STDOUT} qq|------------------------------------------------------- \n|;

                          next TESTCASE; ## skip this test case if a testonly parameter is not set in the global config
                    }
                }

                $case{autocontrolleronly} = $xmltestcases->{case}->{$testnum}->{autocontrolleronly}; ## only run this test case on the automation controller, e.g. test case may involve a test virus which cannot be run on a regular corporate desktop
                if ($case{autocontrolleronly}) { ## is the autocontrolleronly value set for this testcase?
                    if ($opt_autocontroller) { ## if so, was the auto controller option specified?
                        ## run this test case as normal since it is allowed
                    }
                    else {
                          print {*STDOUT} "Skipping Test Case $testnum...\n (This is not the automation controller)\n";
                          print {*STDOUT} qq|------------------------------------------------------- \n|;

                          next TESTCASE; ## skip this test case if this isn't the test controller
                    }
                }

                $case{liveonly} = $xmltestcases->{case}->{$testnum}->{liveonly}; ## only run the test case against production
                if ($case{liveonly}) { ## is the liveonly value set for this testcase?
                    if (!$config{testonly}) { ## assume that if the config doesn't contain the testonly item, then it is a live config
                        ## run this test case as normal since it is allowed
                    }
                    else {
                          print {*STDOUT} "Skipping Test Case $testnum... (LIVEONLY)\n";
                          print {*STDOUT} qq|------------------------------------------------------- \n|;

                          next TESTCASE; ## skip this test case if a liveonly parameter is not set in the global config
                    }
                }

                $case{firstlooponly} = $xmltestcases->{case}->{$testnum}->{firstlooponly}; ## only run this test case on the first loop
                if ($case{firstlooponly}) { ## is the firstlooponly value set for this testcase?
                    if ($counter == 1) { ## counter keeps track of what loop number we are on
                        ## run this test case as normal since it is the first pass
                    }
                    else {
                          print {*STDOUT} "Skipping Test Case $testnum... (firstlooponly)\n";
                          print {*STDOUT} qq|------------------------------------------------------- \n|;

                          next TESTCASE; ## skip this test case since it is firstlooponly and we have already run it
                    }
                }

                $case{lastlooponly} = $xmltestcases->{case}->{$testnum}->{lastlooponly}; ## only run this test case on the last loop
                if ($case{lastlooponly}) { ## is the lastlooponly value set for this testcase?
                    if ($counter == $repeat) { ## counter keeps track of what loop number we are on
                        ## run this test case as normal since it is the first pass
                    }
                    else {
                          print {*STDOUT} "Skipping Test Case $testnum... (LASTLOOPONLY)\n";
                          print {*STDOUT} qq|------------------------------------------------------- \n|;

                          next TESTCASE; ## skip this test case since it is not yet the lastloop
                    }
                }

                $entrycriteriaok = "true"; ## assume entry criteria met
                $entryresponse = "";

                $case{checkpositive} = $xmltestcases->{case}->{$testnum}->{checkpositive};
                if (defined $case{checkpositive}) { ## is the checkpositive value set for this testcase?
                    if ($lastpositive[$case{checkpositive}] eq 'pass') { ## last verifypositive for this indexed passed
                        ## ok to run this test case
                    }
                    else {
                        $entrycriteriaok = '';
                        $entryresponse =~ s!^!ENTRY CRITERIA NOT MET ... (last verifypositive$case{checkpositive} failed)\n!;
                        ## print "ENTRY CRITERIA NOT MET ... (last verifypositive$case{checkpositive} failed)\n";
                        ## $cmdresp =~ s!^!HTTP/1.1 100 OK\n!; ## pretend this is an HTTP response - 100 means continue
                    }
                }

                $case{checknegative} = $xmltestcases->{case}->{$testnum}->{checknegative};
                if (defined $case{checknegative}) { ## is the checkpositive value set for this testcase?
                    if ($lastnegative[$case{checknegative}] eq 'pass') { ## last verifynegative for this indexed passed
                        ## ok to run this test case
                    }
                    else {
                        $entrycriteriaok = '';
                        $entryresponse =~ s!^!ENTRY CRITERIA NOT MET ... (last verifynegative$case{checknegative} failed)\n!;
                        ## print "ENTRY CRITERIA NOT MET ... (last verifynegative$case{checknegative} failed)\n";
                    }
                }

                $case{checkresponsecode} = $xmltestcases->{case}->{$testnum}->{checkresponsecode};
                if (defined $case{checkresponsecode}) { ## is the checkpositive value set for this testcase?
                    if ($lastresponsecode == $case{checkresponsecode}) { ## expected response code last test case equals actual
                        ## ok to run this test case
                    }
                    else {
                        $entrycriteriaok = '';
                        $entryresponse =~ s!^!ENTRY CRITERIA NOT MET ... (expected last response code of $case{checkresponsecode} got $lastresponsecode)\n!;
                        ## print "ENTRY CRITERIA NOT MET ... (expected last response code of $case{checkresponsecode} got $lastresponsecode)\n";
                    }
                }

                # populate variables with values from testcase file, do substitutions, and revert converted values back
                ## old parmlist, kept for reference of what attributes are supported
                ##
                ## "method", "description1", "description2", "url", "postbody", "posttype", "addheader", "command", "command1", "command2", "command3", "command4", "command5", "command6", "command7", "command8", "command9", "command10", "", "command11", "command12", "command13", "command14", "command15", "command16", "command17", "command18", "command19", "command20", "parms", "verifytext",
                ## "verifypositive", "verifypositive1", "verifypositive2", "verifypositive3", "verifypositive4", "verifypositive5", "verifypositive6", "verifypositive7", "verifypositive8", "verifypositive9", "verifypositive10", "verifypositive11", "verifypositive12", "verifypositive13", "verifypositive14", "verifypositive15", "verifypositive16", "verifypositive17", "verifypositive18", "verifypositive19", "verifypositive20",
                ## "verifynegative", "verifynegative1", "verifynegative2", "verifynegative3", "verifynegative4", "verifynegative5", "verifynegative6", "verifynegative7", "verifynegative8", "verifynegative9", "verifynegative10", "verifynegative11", "verifynegative12", "verifynegative13", "verifynegative14", "verifynegative15", "verifynegative16", "verifynegative17", "verifynegative18", "verifynegative19", "verifynegative20",
                ## "parseresponse", "parseresponse1", ... , "parseresponse40", ... , "parseresponse9999999", "parseresponseORANYTHING", "verifyresponsecode", "verifyresponsetime", "retryresponsecode", "sleep", "errormessage", "checkpositive", "checknegative", "checkresponsecode", "ignorehttpresponsecode", "ignoreautoassertions", "ignoresmartassertions",
                ## "retry", "sanitycheck", "logastext", "section", "assertcount", "searchimage", "searchimage1", "searchimage2", "searchimage3", "searchimage4", "searchimage5", "screenshot", "formatxml", "formatjson", "logresponseasfile", "addcookie", "restartbrowseronfail", "restartbrowser", "commandonerror", "gethrefs", "getsrcs", "getbackgroundimages", "firstlooponly", "lastlooponly", "decodequotedprintable");
                ##
                ## "verifypositivenext", "verifynegativenext" were features of WebInject 1.41 - removed since it is probably incompatible with the "retry" feature, and was never used by the author in writing more than 5000 test cases

                my %casesave; ## we need a clean array for each test case
                undef %case; ## do not allow values from previous test cases to bleed over
                foreach my $testAttrib ( keys %{ $xmltestcases->{case}->{$testnum} } ) {
                    #print "DEBUG: $testAttrib", ": ", $xmltestcases->{case}->{$testnum}->{$testAttrib};
                    #print "\n";
                    $case{$testAttrib} = $xmltestcases->{case}->{$testnum}->{$testAttrib};
                    convertbackxml($case{$testAttrib});
                    $casesave{$testAttrib} = $case{$testAttrib}; ## in case we have to retry, some parms need to be resubbed
                }

                $case{retry} = $xmltestcases->{case}->{$testnum}->{retry}; ## optional retry of a failed test case
                if ($case{retry}) { ## retry parameter found
                      $retry = $case{retry}; ## assume we can retry as many times as specified
                      if ($config{globalretry}) { ## ensure that the global retry limit won't be exceeded
                          if ($retry > ($config{globalretry} - $globalretries)) { ## we can't retry that many times
                             $retry =  $config{globalretry} - $globalretries; ## this is the most we can retry
                             if ($retry < 0) {$retry = 0;} ## if less than 0 then make 0
                          }
                      }
                      print {*STDOUT} qq|Retry $retry times\n|;
                }
                else {
                      $retry = 0; #no retry parameter found, don't retry this case
                }

                $case{retryfromstep} = $xmltestcases->{case}->{$testnum}->{retryfromstep}; ## retry from a [previous] step
                if ($case{retryfromstep}) { ## retryfromstep parameter found
                      $retry = 0; ## we will not do a regular retry
                }

                do ## retry loop
                {
                    ## for each retry, there are a few substitutions that we need to redo - like the retry number
                    foreach my $testAttrib ( keys %{ $xmltestcases->{case}->{$testnum} } ) {
                        if (defined $casesave{$testAttrib}) ## defaulted parameters like posttype may not have a saved value on a subsequent loop
                        {
                            $case{$testAttrib} = $casesave{$testAttrib}; ## need to restore to the original partially substituted parameter
                            convertbackxmldynamic($case{$testAttrib}); ## now update the dynamic components
                        }
                    }

                    set_variables(); ## finally set any variables after doing all the static and dynamic substitutions
                    foreach my $testAttrib ( keys %{ $xmltestcases->{case}->{$testnum} } ) { ## then substitute them in
                            convertback_variables($case{$testAttrib});
                    }

                    $desc1log = $case{description1};
                    if ($case{description2}) {
                       $desc2log = $case{description2};
                    }
                    else
                    {
                       $desc2log = ""; ## must blank it out if not being used
                    }

                    if ($config{globalretry}) {
                        if ($globalretries >= $config{globalretry}) {
                            $retry = 0; ## globalretries value exceeded - not retrying any more this run
                        }
                    }
                    $isfailure = 0;
                    $verifynegativefailed = "false";
                    $retrypassedcount = 0;
                    $retryfailedcount = 0;

                    $timestamp = time();  #used to replace parsed {timestamp} with real timestamp value

                    if ($case{description1} and $case{description1} =~ /dummy test case/) {  #if we hit a dummy record, skip it
                        next;
                    }

                    print {$RESULTS} qq|<b>Test:  $currentcasefile - $testnumlog$jumpbacksprint$retriesprint </b><br />\n|;

                    print {*STDOUT} qq|Test:  $currentcasefile - $testnumlog$jumpbacksprint$retriesprint \n|;

                    unless ($casefilecheck eq $currentcasefile) {
                        unless ($currentcasefile eq $casefilelist[0]) {  #if this is the first test case file, skip printing the closing tag for the previous one
                            print {$RESULTSXML} qq|    </testcases>\n\n|;
                        }
                        print {$RESULTSXML} qq|    <testcases file="$currentcasefile">\n\n|;
                    }
                    print {$RESULTSXML} qq|        <testcase id="$testnumlog$jumpbacksprint$retriesprint">\n|;

                    for (qw/section description1 description2/) { ## support section breaks
                        next unless defined $case{$_};
                        print {$RESULTS} qq|$case{$_} <br />\n|;
                        print {*STDOUT} qq|$case{$_} \n|;
                        print {$RESULTSXML} qq|            <$_>$case{$_}</$_>\n|;
                    }

                    print {$RESULTS} qq|<br />\n|;

                    ## display and log the verifications to do
                    ## verifypositive, verifypositive1, ..., verifypositive9999 (or even higher)
                    ## verifynegative, verifynegative2, ..., verifynegative9999 (or even higher)
                    foreach my $testAttrib ( sort keys %{ $xmltestcases->{case}->{$testnum} } ) {
                        if ( substr($testAttrib, 0, 14) eq "verifypositive" || substr($testAttrib, 0, 14) eq "verifynegative") {
                            my $verifytype = ucfirst substr($testAttrib, 6, 8); ## so we get the word Positive or Negative
                            @verifyparms = split(/\|\|\|/, $case{$testAttrib}); ## index 0 contains the actual string to verify
                            print {$RESULTS} qq|Verify $verifytype: "$verifyparms[0]" <br />\n|;
                            print {*STDOUT} qq|Verify $verifytype: "$verifyparms[0]" \n|;
                            print {$RESULTSXML} qq|            <$testAttrib>$verifyparms[0]</$testAttrib>\n|;
                        }
                    }

                    if ($case{verifyresponsecode}) {
                        print {$RESULTS} qq|Verify Response Code: "$case{verifyresponsecode}" <br />\n|;
                        print {*STDOUT} qq|Verify Response Code: "$case{verifyresponsecode}" \n|;
                        print {$RESULTSXML} qq|            <verifyresponsecode>$case{verifyresponsecode}</verifyresponsecode>\n|;
                    }

                    if ($case{verifyresponsetime}) {
                        print {$RESULTS} qq|Verify Response Time: at most "$case{verifyresponsetime} seconds" <br />\n|;
                        print {*STDOUT} qq|Verify Response Time: at most "$case{verifyresponsetime}" seconds\n|;
                        print {$RESULTSXML} qq|            <verifyresponsetime>$case{verifyresponsetime}</verifyresponsetime>\n|;
                    }

                    if ($case{retryresponsecode}) {## retry if a particular response code was returned
                        print {$RESULTS} qq|Retry Response Code: "$case{retryresponsecode}" <br />\n|;
                        print {*STDOUT} qq|Will retry if we get response code: "$case{retryresponsecode}" \n|;
                        print {$RESULTSXML} qq|            <retryresponsecode>$case{retryresponsecode}</retryresponsecode>\n|;
                    }

                    $RESULTS->autoflush();

                    if ($entrycriteriaok) { ## do not run it if the case has not met entry criteria
                       if ($case{method}) {
                           if ($case{method} eq "get") { httpget(); }
                           elsif ($case{method} eq "post") { httppost(); }
                           elsif ($case{method} eq "cmd") { cmd(); }
                           elsif ($case{method} eq "selenium") { selenium(); }
                           else { print STDERR qq|ERROR: bad Method Type, you must use "get", "post", "cmd" or "selenium"\n|; }
                       }
                       else {
                          httpget();  #use "get" if no method is specified
                       }
                    }
                    else {
                         # Response code 412 means Precondition failed
                         print {*STDOUT} $entryresponse;
                         $entryresponse =~ s!^!412 \n!;
                         $response = HTTP::Response->parse($entryresponse);
                         $latency = 0.001; ## Prevent latency bleeding over from previous test step
                    }

                    searchimage(); ## search for images within actual screen or page grab

					if ($case{decodequotedprintable}) {
						 my $decoded = decode_qp($response->as_string); ## decode the response output
						 $response = HTTP::Response->parse($decoded); ## inject it back into the response
					}

                    verify(); #verify result from http response

                    gethrefs(); ## get specified web page href assets
                    getsrcs(); ## get specified web page src assets
                    getbackgroundimages(); ## get specified web page src assets

                    httplog();  #write to http.log file

                    if ($entrycriteriaok) { ## do not want to parseresponse on junk
                       parseresponse();  #grab string from response to send later
                    }

                    ## check max jumpbacks - globaljumpbacks - i.e. retryfromstep usages before we give up - otherwise we risk an infinite loop
                    if ( (($isfailure > 0) && ($retry < 1) && !($case{retryfromstep})) || (($isfailure > 0) && ($case{retryfromstep}) && ($jumpbacks > ($config{globaljumpbacks}-1) )) || ($verifynegativefailed eq "true")) {  #if any verification fails, test case is considered a failure UNLESS there is at least one retry available, or it is a retryfromstep case. However if a verifynegative fails then the case is always a failure
                        print {$RESULTSXML} qq|            <success>false</success>\n|;
                        if ($case{errormessage}) { #Add defined error message to the output
                            print {$RESULTS} qq|<b><span class="fail">TEST CASE FAILED : $case{errormessage}</span></b><br />\n|;
                            print {$RESULTSXML} qq|            <result-message>$case{errormessage}</result-message>\n|;
                            print {*STDOUT} qq|TEST CASE FAILED : $case{errormessage}\n|;
                        }
                        else { #print regular error output
                            print {$RESULTS} qq|<b><span class="fail">TEST CASE FAILED</span></b><br />\n|;
                            print {$RESULTSXML} qq|            <result-message>TEST CASE FAILED</result-message>\n|;
                            print {*STDOUT} qq|TEST CASE FAILED\n|;
                        }
                        $casefailedcount++;
                    }
                    elsif (($isfailure > 0) && ($retry > 0)) {#Output message if we will retry the test case
                        print {$RESULTS} qq|<b><span class="pass">RETRYING... $retry to go</span></b><br />\n|;
                        print {*STDOUT} qq|RETRYING... $retry to go \n|;
                        print {$RESULTSXML} qq|            <success>false</success>\n|;
                        print {$RESULTSXML} qq|            <result-message>RETRYING... $retry to go</result-message>\n|;

                        ## all this is for ensuring correct behaviour when retries occur
                        $retriesprint = ".$retries";
                        $retries++;
                        $globalretries++;
                        $passedcount = $passedcount - $retrypassedcount;
                        $failedcount = $failedcount - $retryfailedcount;
                    }
                    elsif (($isfailure > 0) && $case{retryfromstep}) {#Output message if we will retry the test case from step
                        my $jumpbacksleft = $config{globaljumpbacks} - $jumpbacks;
                        print {$RESULTS} qq|<b><span class="pass">RETRYING FROM STEP $case{retryfromstep} ... $jumpbacksleft tries left</span></b><br />\n|;
                        print {*STDOUT} qq|RETRYING FROM STEP $case{retryfromstep} ...  $jumpbacksleft tries left\n|;
                        print {$RESULTSXML} qq|            <success>false</success>\n|;
                        print {$RESULTSXML} qq|            <result-message>RETRYING FROM STEP $case{retryfromstep} ...  $jumpbacksleft tries left</result-message>\n|;
                        $jumpbacks++; ## increment number of times we have jumped back - i.e. used retryfromstep
                        $jumpbacksprint = "-$jumpbacks";
                        $globalretries++;
                        $passedcount = $passedcount - $retrypassedcount;
                        $failedcount = $failedcount - $retryfailedcount;

                        ## find the index for the test step we are retrying from
                        $stepindex = 0;
                        my $foundindex = "false";
                        foreach (@teststeps) {
                            if ($teststeps[$stepindex] eq $case{retryfromstep}) {
                                $foundindex = "true";
                                last;
                            }
                            $stepindex++
                        }
                        if ($foundindex eq "false") {
                            print {*STDOUT} qq|ERROR - COULD NOT FIND STEP $case{retryfromstep} - TESTING STOPS \n|;
                        }
                        else
                        {
                            $stepindex--; ## since we increment it at the start of the next loop / end of this loop
                        }
                    }
                    else {
                        print {$RESULTS} qq|<b><span class="pass">TEST CASE PASSED</span></b><br />\n|;
                        print {*STDOUT} qq|TEST CASE PASSED \n|;
                        print {$RESULTSXML} qq|            <success>true</success>\n|;
                        print {$RESULTSXML} qq|            <result-message>TEST CASE PASSED</result-message>\n|;
                        $casepassedcount++;
                        $retry = 0; # no need to retry when test case passes
                    }

                    print {$RESULTS} qq|Response Time = $latency sec <br />\n|;

                    print {*STDOUT} qq|Response Time = $latency sec \n|;

                    print {$RESULTSXML} qq|            <responsetime>$latency</responsetime>\n|;

                    if ($case{method} eq "selenium") {
                        print {$RESULTS} qq|Verification Time = $verificationlatency sec <br />\n|;
                        print {$RESULTS} qq|Screenshot Time = $screenshotlatency sec <br />\n|;

                        print {*STDOUT} qq|Verification Time = $verificationlatency sec \n|;
                        print {*STDOUT} qq|Screenshot Time = $screenshotlatency sec \n|;

                        print {$RESULTSXML} qq|            <verificationtime>$verificationlatency</verificationtime>\n|;
                        print {$RESULTSXML} qq|            <screenshottime>$screenshotlatency</screenshottime>\n|;
                    }


                    print {$RESULTSXML} qq|        </testcase>\n\n|;
                    print {$RESULTS} qq|<br />\n------------------------------------------------------- <br />\n\n|;

                    unless ($xnode) { #skip regular STDOUT output if using an XPath
                        print {*STDOUT} qq|------------------------------------------------------- \n|;
                    }

                    $casefilecheck = $currentcasefile;  #set this so <testcases> xml is only closed after each file is done processing

                    $endruntimer = time();
                    $totalruntime = (int(1000 * ($endruntimer - $startruntimer)) / 1000);  #elapsed time rounded to thousandths

                    #if (($isfailure > 0) && ($retry > 0)) {  ## do not increase the run count if we will retry
                    if ( (($isfailure > 0) && ($retry > 0) && !($case{retryfromstep})) || (($isfailure > 0) && ($case{retryfromstep}) && ($jumpbacks < $config{globaljumpbacks}  ) && ($verifynegativefailed eq "false") ) ) {
                        ## do not count this in run count if we are retrying, again maximum usage of retryfromstep has been hard coded
                    }
                    else {
                        $runcount++;
                        $totalruncount++;
                    }

                    if ($latency > $maxresponse) { $maxresponse = $latency; }  #set max response time
                    if ($latency < $minresponse) { $minresponse = $latency; }  #set min response time
                    $totalresponse = ($totalresponse + $latency);  #keep total of response times for calculating avg
                    if ($totalruncount > 0) { #only update average response if at least one test case has completed, to avoid division by zero
                        $avgresponse = (int(1000 * ($totalresponse / $totalruncount)) / 1000);  #avg response rounded to thousandths
                    }

                    $teststeptime{$testnumlog}=$latency; ## store latency for step

                    if ($case{restartbrowseronfail} && ($isfailure > 0)) { ## restart the Selenium browser session and also the WebInject session
                        print {*STDOUT} qq|RESTARTING BROWSER DUE TO FAIL ... \n|;
                        startseleniumbrowser();
                        startsession();
                    }

                    if ($case{restartbrowser}) { ## restart the Selenium browser session and also the WebInject session
                        print {*STDOUT} qq|RESTARTING BROWSER ... \n|;
                        startseleniumbrowser();
                        startsession();
                    }

                    if ( (($isfailure < 1) && ($case{retry})) || (($isfailure < 1) && ($case{retryfromstep})) )
                    {
                        ## ignore the sleep if the test case worked and it is a retry test case
                    }
                    else
                    {
                        if ($case{sleep})
                        {
                            if ( (($isfailure > 0) && ($retry < 1)) || (($isfailure > 0) && ($jumpbacks > ($config{globaljumpbacks}-1))) )
                            {
                                ## do not sleep if the test case failed and we have run out of retries or jumpbacks
                            }
                            else
                            {
                                ## if a sleep value is set in the test case, sleep that amount
                                sleep($case{sleep})
                            }
                        }
                    }

                    if ($xnode) {  #if an XPath Node is defined, only process the single Node
                        last;
                    }
                    $retry = $retry - 1;
                } ## end of retry loop
                until ($retry < 0);

                if ($case{sanitycheck} && ($casefailedcount > 0)) { ## if sanitycheck fails (i.e. we have had any error at all after retries exhausted), then execution is aborted
                    print {*STDOUT} qq|SANITY CHECK FAILED ... Aborting \n|;
                    last;
                }
            } ## end of test case loop

            $testnum = 1;  #reset testcase counter so it will reprocess test case file if repeat is set
        }
    }

    finaltasks();  #do return/cleanup tasks


    ## shut down the Selenium server last - it is less important than closing the files
    if ($opt_port) {  ## if -p is used, we need to close the browser and stop the selenium server
        $selresp = $sel->quit(); ## shut down selenium browser session
    }

    return;

} #end engine subroutine



#------------------------------------------------------------------
#  SUBROUTINES
#------------------------------------------------------------------
sub writeinitialhtml {  #write opening tags for results file

    print $RESULTS
qq|<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>WebInject Test Results</title>
    <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
    <style type="text/css">
        body {
            background-color: #F5F5F5;
            color: #000000;
            font-family: Verdana, Arial, Helvetica, sans-serif;
            font-size: 10px;
        }
        .pass {
            color: green;
        }
        .fail {
            color: red;
        }
        .skip {
            color: orange;
        }
    </style>
</head>
<body>
<hr />
-------------------------------------------------------<br />
|;

    return;
}

#------------------------------------------------------------------
sub writeinitialstdout {  #write initial text for STDOUT

    print STDOUT
qq|
Starting WebInject Engine...

-------------------------------------------------------
|;

    return;
}

#------------------------------------------------------------------
sub writefinalhtml {  #write summary and closing tags for results file

    print $RESULTS
qq|
<br /><hr /><br />
<b>
Start Time: $currentdatetime <br />
Total Run Time: $totalruntime seconds <br />
<br />
Test Cases Run: $totalruncount <br />
Test Cases Passed: $casepassedcount <br />
Test Cases Failed: $casefailedcount <br />
Verifications Passed: $passedcount <br />
Verifications Failed: $failedcount <br />
<br />
Average Response Time: $avgresponse seconds <br />
Max Response Time: $maxresponse seconds <br />
Min Response Time: $minresponse seconds <br />
</b>
<br />

</body>
</html>
|;

    return;
}

#------------------------------------------------------------------
sub writefinalxml {  #write summary and closing tags for XML results file

    if ($case{sanitycheck} && ($casefailedcount > 0)) { ## sanitycheck
        $sanityresult = "false";
    }
    else {
        $sanityresult = "true";
    }

## startdatetime - inserted start-seconds and start-date-time below
    print $RESULTSXML
qq|
    </testcases>

    <test-summary>
        <start-time>$currentdatetime</start-time>
        <start-seconds>$TIMESECONDS</start-seconds>
        <start-date-time>$STARTDATE|;
print {$RESULTSXML} qq|T$HOUR:$MINUTE:$SECOND</start-date-time>
        <total-run-time>$totalruntime</total-run-time>
        <test-cases-run>$totalruncount</test-cases-run>
        <test-cases-passed>$casepassedcount</test-cases-passed>
        <test-cases-failed>$casefailedcount</test-cases-failed>
        <verifications-passed>$passedcount</verifications-passed>
        <verifications-failed>$failedcount</verifications-failed>
        <assertion-skips>$totalassertionskips</assertion-skips>
        <average-response-time>$avgresponse</average-response-time>
        <max-response-time>$maxresponse</max-response-time>
        <min-response-time>$minresponse</min-response-time>
        <sanity-check-passed>$sanityresult</sanity-check-passed>
    </test-summary>

</results>
|;

    return;
}

#------------------------------------------------------------------
sub writefinalstdout {  #write summary and closing text for STDOUT

    print STDOUT
qq|
Start Time: $currentdatetime
Total Run Time: $totalruntime seconds

Test Cases Run: $totalruncount
Test Cases Passed: $casepassedcount
Test Cases Failed: $casefailedcount
Verifications Passed: $passedcount
Verifications Failed: $failedcount

|;

    return;
}

## Selenium server support
#------------------------------------------------------------------
sub selenium {  ## send Selenium command and read response

    my $command = '';
    my $verifytext = '';
    my @verfresp = ();
    my $idx = 0; #For keeping track of index in foreach loop
    my $grab = '';
    my $jswait = '';
    my @parseverify ='';
    my $timestart;

    $starttimer = time();

    my $combinedresp='';
    $request = HTTP::Request->new('GET',"WebDriver");
    for (qw/command command1 command2 command3 command4 command5 command6 command7 command8 command9 command10  command11 command12 command13 command14 command15 command16 command17 command18 command19 command20/) {
       if ($case{$_}) {#perform command
          $command = $case{$_};
          $selresp = '';
          my $evalresp = eval { eval "$command"; }; ## no critic
          print "EVALRESP:$@\n";
          if (defined $selresp) { ## phantomjs does not return a defined response sometimes
              if (($selresp =~ m!(^|=)HASH\b!) || ($selresp =~ m!(^|=)ARRAY\b!)) { ## check to see if we have a HASH or ARRAY object returned
                  my $dumpresp = Dumper($selresp);
                  print "SELRESP:$dumpresp";
                  $selresp = "selresp:$dumpresp";
              }
              else {
                  print "SELRESP:$selresp\n";
                  $selresp = "selresp:$selresp";
              }
          }
          else {
              print "SELRESP:<undefined>\n";
              $selresp = "selresp:<undefined>";
          }
          #$request = new HTTP::Request('GET',"$case{command}");
          $combinedresp =~ s!$!<$_>$command</$_>\n$selresp\n\n\n!; ## include it in the response
       }
    }

    $endtimer = time(); ## we only want to measure the time it took for the commands, not to do the screenshots and verification
    $latency = (int(1000 * ($endtimer - $starttimer)) / 1000);  ## elapsed time rounded to thousandths


    $starttimer = time(); ## measure latency for the verification

    $selresp = $combinedresp;

    sleep( 0.02 ); ## Sleep for 20 milliseconds

    ## multiple verifytexts are separated by commas
    if ($case{verifytext}) {
      @parseverify = split(/,/, $case{verifytext});
      foreach (@parseverify) {
         print "$_\n";
         $idx = 0;
         $verifytext = $_;
         if ($verifytext eq "get_body_text") {
            print "GET_BODY_TEXT:$verifytext\n";
            eval { @verfresp =  $sel->find_element('body','tag_name')->get_text(); };
         }
         else
         {
            eval { @verfresp = $sel->$verifytext(); }; ## sometimes Selenium will return an array
         }
         $selresp =~ s!$!\n\n\n\n!; ## put in a few carriage returns after any Selenium server message first
         foreach my $vresp (@verfresp) {
            $vresp =~ s/[^[:ascii:]]+//g; ## get rid of non-ASCII characters in the string element
            $idx++; ## keep track of where we are in the loop
            $selresp =~ s!$!<$verifytext$idx>$vresp</$verifytext$idx>\n!; ## include it in the response
            if (($vresp =~ m!(^|=)HASH\b!) || ($vresp =~ m!(^|=)ARRAY\b!)) { ## check to see if we have a HASH or ARRAY object returned
               my $dumpresp = Dumper($vresp);
               my $dumped = "dumped";
               $selresp =~ s!$!<$verifytext$dumped$idx>$dumpresp</$verifytext$dumped$idx>\n!; ## include it in the response
               ## ^ means match start of string, $ end of string
            }
         }
      }
    }

    $endtimer = time(); ## we only want to measure the time it took for the commands, not to do the screenshots and verification
    $verificationlatency = (int(1000 * ($endtimer - $starttimer)) / 1000);  ## elapsed time rounded to thousandths

    $starttimer = time(); ## measure latency for the screenshot

    if ($case{screenshot} && (lc($case{screenshot}) eq "false" || lc($case{screenshot}) eq "no")) #lc = lowercase
    {
      ## take a very fast screenshot - visible window only, only works for interactive sessions
      if ($chromehandle > 0) {
         my $minicap = (`WindowCapture "$cwd\\$output$testnumlog$jumpbacksprint$retriesprint.png" $chromehandle`);
         #my $minicap = (`minicap -save "$cwd\\$output$testnumlog$jumpbacksprint$retriesprint.png" -capturehwnd $chromehandle -exit`);
         #my $minicap = (`screenshot-cmd -o "$cwd\\$output$testnumlog$jumpbacksprint$retriesprint.png" -wh "$hexchromehandle"`);
      }
    }
    else ## take a full pagegrab - works for interactive and non interactive, but is slow i.e > 2 seconds
    {
      eval
      {  ## do the screenshot, needs to be in eval in case modal popup is showing (screenshot not possible)
         #$timestart = time();
         $png_base64 = $sel->screenshot();
         #print "TIMER: selenium screenshot took " . (int(1000 * (time() - $timestart)) / 1000) . "\n";
      };

      if ($@) ## if there was an error in taking the screenshot, $@ will have content
      {
          print "Selenium full page grab failed.\n";
          print "ERROR:$@";
      }
      else
      {
         require MIME::Base64;
         open( my $FH, '>', "$cwd\\$output$testnumlog$jumpbacksprint$retriesprint.png" );
         binmode $FH; ## set binary mode
         print $FH MIME::Base64::decode_base64($png_base64);
         close $FH;
      }
    }

    $endtimer = time(); ## we only want to measure the time it took for the commands, not to do the screenshots and verification
    $screenshotlatency = (int(1000 * ($endtimer - $starttimer)) / 1000);  ## elapsed time rounded to thousandths

    if ($selresp =~ /^ERROR/) { ## Selenium returned an error
       $selresp =~ s!^!HTTP/1.1 500 Selenium returned an error\n\n!; ## pretend this is an HTTP response - 100 means continue
    }
    else {
       $selresp =~ s!^!HTTP/1.1 100 OK\n\n!; ## pretend this is an HTTP response - 100 means continue
    }
    $response = HTTP::Response->parse($selresp); ## pretend the response is an http response - inject it into the object
    #print $response->as_string; print "\n\n";

    return;
} ## end sub

sub custom_select_by_text { ## usage: custom_select_by_label(Search Target, Locator, Label);
                            ##        custom_select_by_label('candidateProfileDetails_ddlCurrentSalaryPeriod','id','Daily Rate');

    my ($searchtarget, $locator, $labeltext) = @_;

    my $elem1 = $sel->find_element("$searchtarget", "$locator");
    #my $child = $sel->find_child_element($elem1, "./option[\@value='4']")->click();
    my $child = $sel->find_child_element($elem1, "./option[. = '$labeltext']")->click();

    return $child;
}

sub custom_clear_and_send_keys { ## usage: custom_clear_and_send_keys(Search Target, Locator, Keys);
                                 ##        custom_clear_and_send_keys('candidateProfileDetails_txtPostCode','id','WC1X 8TG');

    my ($searchtarget, $locator, $sendkeys) = @_;

    my $elem1 = $sel->find_element("$searchtarget", "$locator")->clear();
    my $resp1 = $sel->find_element("$searchtarget", "$locator")->send_keys("$sendkeys");

    return $resp1;
}

sub custom_mouse_move_to_location { ## usage: custom_mouse_move_to_location(Search Target, Locator, xoffset, yoffset);
                                    ##        custom_mouse_move_to_location('closeBtn','id','3','4');

    my ($searchtarget, $locator, $xoffset, $yoffset) = @_;

    my $elem1 = $sel->find_element("$searchtarget", "$locator");
    my $child = $sel->mouse_move_to_location($elem1, $xoffset, $yoffset);

    return $child;
}

sub custom_switch_to_window { ## usage: custom_switch_to_window(window number);
                              ##        custom_switch_to_window(0);
                              ##        custom_switch_to_window(1);

    my ($windownumber) = @_;

    my $handles = $sel->get_window_handles;
    print Dumper $handles;
    my $resp1 =  $sel->switch_to_window($handles->[$windownumber]);

    return $resp1;
}

sub custom_js_click { ## usage: custom_js_click(id);
                      ##        custom_js_click("btnSubmit");

    my ($idToClick) = @_;

    my $script = q{
        var arg1 = arguments[0];
        var elem = window.document.getElementById(arg1).click();
        return elem;
    };
    my $resp1 = $sel->execute_script($script,$idToClick);

    return $resp1;
}

sub custom_js_set_value {  ## usage: custom_js_set_value(id,value);
                           ##        custom_js_set_value('cvProvider_filCVUploadFile','{CWD}\testdata\MyCV.doc');
                           ##
                           ##        Single quotes will not treat \ as escape codes

    my ($idToSetValue, $valueToSet) = @_;

    my $script = q{
        var arg1 = arguments[0];
        var arg2 = arguments[1];
        var elem = window.document.getElementById(arg1).value=arg2;
        return elem;
    };
    my $resp1 = $sel->execute_script($script,$idToSetValue,$valueToSet);

    return $resp1;
}

sub custom_js_make_field_visible_to_webdriver {     ## usage: custom_js_make_field_visible(id);
                                                    ##        custom_js_make_field_visible('cvProvider_filCVUploadFile');

    my ($idToSetCSS) = @_;

    my $script = q{
        var arg1 = arguments[0];
        window.document.getElementById(arg1).style.width = "5px";
        var elem = window.document.getElementById(arg1).style.height = "5px";
        return elem;
    };
    my $resp1 = $sel->execute_script($script,$idToSetCSS);

    return $resp1;
}

sub custom_check_element_within_pixels {     ## usage: custom_check_element_within_pixels(searchTarget,id,xBase,yBase,pixelThreshold);
                                             ##        custom_check_element_within_pixels('txtEmail','id',193,325,30);

    my ($searchTarget, $locator, $xBase, $yBase, $pixelThreshold) = @_;

    ## get_element_location will return a reference to a hash associative array
    ## http://www.troubleshooters.com/codecorn/littperl/perlscal.htm
    ## the array will look something like this
    # { 'y' => 325, 'hCode' => 25296896, 'x' => 193, 'class' => 'org.openqa.selenium.Point' };
    my ($location) = $sel->find_element("$searchTarget", "$locator")->get_element_location();

    ## if the element doesn't exist, we get an empty output, so presumably this subroutine just dies and the program carries on

    ## we use the -> operator to get to the underlying values in the hash array
    my $x = $location->{x};
    my $y = $location->{y};

    my $xDiff = abs($xBase - $x);
    my $yDiff = abs($yBase - $y);

    my $Message = "Pixel threshold check passed - $searchTarget is $xDiff,$yDiff (x,y) pixels removed from baseline of $xBase,$yBase; actual was $x,$y";

    if ($xDiff > $pixelThreshold || $yDiff > $pixelThreshold) {
        $Message = "Pixel threshold check failed - $searchTarget is $xDiff,$yDiff (x,y) pixels removed from baseline of $xBase,$yBase; actual was $x,$y";
    }

    return $Message;
}

sub custom_wait_for_text_present { ## usage: custom_wait_for_text_present("Search Text",Timeout);
                                   ##        custom_wait_for_text_present("Job title",10);
                                   ##
                                   ## waits for text to appear in page source

    my ($searchtext, $timeout) = @_;

    print {*STDOUT} "SEARCHTEXT:$searchtext\n";
    print {*STDOUT} "TIMEOUT:$timeout\n";

    my $timestart = time();
    my @resp1;
    my $foundit = "false";

    while ( (($timestart + $timeout) > time()) && $foundit eq "false" ) {
        eval { @resp1 = $sel->get_page_source(); };
        foreach my $resp (@resp1) {
            if ($resp =~ m~$searchtext~si) {
                $foundit = "true";
            }
        }
        if ($foundit eq "false")
        {
            sleep( 0.1 ); # Sleep for 0.1 seconds
        }
    }
    my $trytime = ( int( (time() - $timestart) *10 ) / 10);

    my $returnmsg;
    if ($foundit eq "true") {
        $returnmsg = "Found sought text in page source after $trytime seconds";
    }
    else
    {
        $returnmsg = "Did not find sought text in page source, timed out after $trytime seconds";
    }

    return $returnmsg;
}

sub custom_wait_for_text_not_present { ## usage: custom_wait_for_text_not_present("Search Text",Timeout);
                                       ##        custom_wait_for_text_not_present("Job title",10);
                                       ##
                                       ## waits for text to disappear from page source

    my ($searchtext, $timeout) = @_;

    print {*STDOUT} "DO NOT WANT TEXT:$searchtext\n";
    print {*STDOUT} "TIMEOUT:$timeout\n";

    my $timestart = time();
    my @resp1;
    my $foundit = "true";

    while ( (($timestart + $timeout) > time()) && $foundit eq "true" ) {
        eval { @resp1 = $sel->get_page_source(); };
        foreach my $resp (@resp1) {
            if ($resp =~ m~$searchtext~si) {
                sleep( 0.1 ); ## sleep for 0.1 seconds
            } else {
                $foundit = "false";
            }
        }
    }

    my $trytime = ( int( (time() - $timestart) *10 ) / 10);

    my $returnmsg;
    if ($foundit eq "true") {
        $returnmsg = "TIMEOUT: Text was *still* in page source after $trytime seconds";
    } else {
        $returnmsg = "SUCCESS: Did not find sought text in page source after $trytime seconds";
    }

    return $returnmsg;
}

sub custom_wait_for_text_visible { ## usage: custom_wait_for_text_visible("Search Text","target", "locator", Timeout);
                                   ##         custom_wait_for_text_visible("Job title", "body", "tag_name", 10);
                                   ##
                                   ## Waits for text to appear visible in the body text. This function can sometimes be very slow on some pages.

    my ($searchtext, $target, $locator, $timeout) = @_;

    print {*STDOUT} "VISIBLE SEARCH TEXT:$searchtext\n";
    print {*STDOUT} "TIMEOUT:$timeout\n";

    my $timestart = time();
    my @resp1;
    my $foundit = "false";

    while ( (($timestart + $timeout) > time()) && $foundit eq "false" ) {
        eval { @resp1 = $sel->find_element($target,$locator)->get_text(); };
        foreach my $resp (@resp1) {
            if ($resp =~ m~$searchtext~si) {
                $foundit = "true";
            }
        }
        if ($foundit eq "false")
        {
            sleep( 0.5 ); ## sleep for 0.5 seconds
        }
    }

    my $trytime = ( int( (time() - $timestart) *10 ) / 10);

    my $returnmsg;
    if ($foundit eq "true") {
        $returnmsg = "Found sought text visible after $trytime seconds";
    }
    else
    {
        $returnmsg = "Did not find sought text visible, timed out after $trytime seconds";
    }

    return $returnmsg;
}

sub custom_wait_for_text_not_visible { ## usage: custom_wait_for_text_not_visible("Search Text",Timeout);
                                       ##        custom_wait_for_text_not_visible("This job has been emailed to",10);
                                       ##
                                       ## waits for text to be not visible in the body text - e.g. closing a JavaScript popup

    my ($searchtext, $timeout) = @_;

    print {*STDOUT} "NOT VISIBLE SEARCH TEXT:$searchtext\n";
    print {*STDOUT} "TIMEOUT:$timeout\n";

    my $timestart = time();
    my @resp1;
    my $foundit = "true"; ## we assume it is there already (from previous test step), otherwise it makes no sense to call this

    while ( (($timestart + $timeout) > time()) && $foundit eq "true" ) {
        eval { @resp1 = $sel->find_element('body','tag_name')->get_text(); };
        foreach my $resp (@resp1) {
            if (not ($resp =~ m~$searchtext~si)) {
                $foundit = "false";
            }
        }
        if ($foundit eq "true")
        {
            sleep( 0.1 ); ## sleep for 0.1 seconds
        }
    }

    my $trytime = ( int( (time() - $timestart) *10 ) / 10);

    my $returnmsg;
    if ($foundit eq "false") {
        $returnmsg = "Sought text is now not visible after $trytime seconds";
    }
    else
    {
        $returnmsg = "Sought text still visible, timed out after $trytime seconds";
    }

    return $returnmsg;
}

sub custom_wait_for_element_present { ## usage: custom_wait_for_element_present('element-name','element-type','Timeout');
                                      ##        custom_wait_for_element_present('menu-search-icon','id','5');

    my ($elementName, $elementType, $timeout) = @_;

    print {*STDOUT} "SEARCH ELEMENT[$elementName], ELEMENT TYPE[$elementType], TIMEOUT[$timeout]\n";

    my $timestart = time();
    my $foundit = "false";
    my $findElement;

    while ( (($timestart + $timeout) > time()) && $foundit eq "false" )
    {
        eval { $findElement = $sel->find_element("$elementName","$elementType"); };
        if ($findElement)
        {
            $foundit = "true";
        }
        if ($foundit eq "false")
        {
            sleep( 0.1 ); ## Sleep for 0.1 seconds
        }
    }

    my $trytime = ( int( (time() - $timestart) *10 ) / 10);

    my $returnmsg;
    if ($foundit eq "true") {
        $returnmsg = "Found sought element after $trytime seconds";
    }
    else
    {
        $returnmsg = "Did not find sought element, timed out after $trytime seconds";
    }

    #print {*STDOUT} "$returnmsg\n";
    return $returnmsg;
}

sub custom_wait_for_element_visible { ## usage: custom_wait_for_element_visible('element-name','element-type','Timeout');
                                      ##        custom_wait_for_element_visible('menu-search-icon','id','5');

    my ($elementName, $elementType, $timeout) = @_;

    print {*STDOUT} "SEARCH ELEMENT[$elementName], ELEMENT TYPE[$elementType], TIMEOUT[$timeout]\n";

    my $timestart = time();
    my $foundit = "false";
    my $findElement;

    while ( (($timestart + $timeout) > time()) && $foundit eq "false" )
    {
        eval { $findElement = $sel->find_element("$elementName","$elementType")->is_displayed(); };
        if ($findElement)
        {
            $foundit = "true";
        }
        if ($foundit eq "false")
        {
            sleep( 0.1 ); ## Sleep for 0.1 seconds
        }
    }
    my $trytime = ( int( (time() - $timestart) *10 ) / 10);

    my $returnmsg;
    if ($foundit eq "true") {
        $returnmsg = "Found sought element visible after $trytime seconds";
    }
    else
    {
        $returnmsg = "Did not find sought element visible, timed out after $trytime seconds";
    }

    #print {*STDOUT} "$returnmsg\n";
    return $returnmsg;
}


#------------------------------------------------------------------
sub addcookie { ## add a cookie like JBM_COOKIE=4830075
    if ($case{addcookie}) { ## inject in an additional cookie for this test step only if specified
        my $cookies = $request->header("Cookie");
        if (defined $cookies) {
            #print "[COOKIE] $cookies\n";
            $request->header("Cookie" => "$cookies; " . $case{addcookie});
            #print "[COOKIE UPDATED] " . $request->header("Cookie") . "\n";
        } else {
            #print "[COOKIE] <UNDEFINED>\n";
            $request->header("Cookie" => $case{addcookie});
            #print "[COOKIE UPDATED] " . $request->header("Cookie") . "\n";
        }
        undef $cookies;
    }

    return;
}

#------------------------------------------------------------------
sub gethrefs { ## get page href assets matching a list of ending patterns, separate multiple with |
               ## gethrefs=".less|.css"
    if ($case{gethrefs}) {
        my $match = "href=";
        my $delim = "\x22"; #"
        getassets ($match,$delim,$delim,$case{gethrefs});
        #getassets ("href",$case{gethrefs});
    }

    return;
}

#------------------------------------------------------------------
sub getsrcs { ## get page src assets matching a list of ending patterns, separate multiple with |
              ## getsrcs=".js|.png|.jpg|.gif"
    if ($case{getsrcs}) {
        my $match = "src=";
        my $delim = '"';
        getassets ($match, $delim, $delim, $case{getsrcs});
        #getassets ("src",$case{getsrcs});
    }

    return;
}

#------------------------------------------------------------------
sub getbackgroundimages { ## style="background-image: url( )"

    if ($case{getbackgroundimages}) {
        my $match = 'style="background-image: url';
        my $leftdelim = '\(';
        my $rightdelim = '\)';
        getassets ($match,$leftdelim,$rightdelim,$case{getbackgroundimages});
    }

    return;
}

#------------------------------------------------------------------
sub getassets { ## get page assets matching a list for a reference type
                ## getassets ("href",".less|.css")

    my ($match, $leftdelim, $rightdelim, $assetlist) = @_;

    my ($startassetrequest, $endassetrequest, $assetlatency);
    my ($assetref, $ururl, $asseturl, $path, $filename, $assetrequest, $assetresponse, $cachecontrol);

    my $page = $response->as_string;

    my @extensions = split(/\|/, $assetlist);

    foreach my $extension (@extensions) {

        #while ($page =~ m~$assettype="([^"]*$extension)["\?]~g) ##" Iterate over all the matches to this extension
        print "\n $match$leftdelim([^$rightdelim]*$extension)[$rightdelim\?] \n";
        while ($page =~ m~$match$leftdelim([^$rightdelim]*$extension)[$rightdelim\?]~g) ##" Iterate over all the matches to this extension
        {
            $startassetrequest = time();

            $assetref = $1;
            #print "$extension: $assetref\n";

            $ururl = URI::URL->new($assetref, $case{url}); ## join the current page url together with the href of the asset
            $asseturl = $ururl->abs; ## determine the absolute address of the asset
            #print "$asseturl\n\n";
            $path = $asseturl->path; ## get the path portion of the asset location
            $filename = basename($path); ## get the filename from the path
            print {*STDOUT} "  GET Asset [$filename] ...";

            $assetrequest = HTTP::Request->new('GET',"$asseturl");
            $cookie_jar->add_cookie_header($assetrequest); ## session cookies will be needed

            $assetresponse = $useragent->request($assetrequest);

            open( my $RESPONSEASFILE, '>', "$outputfolder/$filename" ); #open in clobber mode
            binmode $RESPONSEASFILE; ## set binary mode
            print $RESPONSEASFILE $assetresponse->content, ""; ## content just outputs the content, whereas as_string includes the response header
            close( $RESPONSEASFILE );

            $endassetrequest = time();
            $assetlatency = (int(1000 * ($endassetrequest - $startassetrequest)) / 1000);  ## elapsed time rounded to thousandths
            print {*STDOUT} " $assetlatency s\n";

            #print {*STDOUT} $assetresponse->headers()->as_string(), "\n\n\n";

            #$assetresponse->headers()->as_string() =~ m!^Cache-Control: ([\w]*)$!;
            #$cachecontrol = $1;
            #print {*STDOUT} " Cache-Control: $cachecontrol\n";


        } ## end while

    } ## end foreach

    return;
}


#------------------------------------------------------------------
sub savepage {## save the page in a cache to enable auto substitution
   my $page = '';
   my $pagenameaction = '';
   my $pagename = '';
   my $pagefound = 'false';
   my $idx = 0; #For keeping track of index in foreach loop
   my $idfound = 0;
   my $idfoundflag = 'false';
   my $tempname = '';
   my $saveidx = 0;
   my $len = 0;
   my $count = 0;

   $page = $response->as_string;

   ## decide if we want to save this page - needs a method post action
   if ( ($page =~ m~method="post" action="(.*?)"~s) || ($page =~ m~action="(.*?)" method="post"~s) ) { ## look for the method post action
      $pagenameaction = $1;
      #print {*STDOUT} qq|\n ACTION $pagenameaction\n|;
      $pagefound = 'true'; ## we will only save the page if we actually found one
      #out print {*STDOUT} qq|\n|;
   } else {
      #out print {*STDOUT} qq|\n ACTION none\n\n|;
   }

   if ($pagefound eq 'true') { ## ok, so we save this page

      $pagename = $case{url};
      #out print {*STDOUT} qq| SAVING $pagename (BEFORE)\n|;
      if ($pagename =~ m~(.*?)\?~s) { ## we only want everything to the left of the ? mark
         $pagename = $1;
      }
      $pagename =~ s!http.?://!!s; ## remove http:// and https://
      #print {*STDOUT} qq| SAVING $pagename (AFTER)\n\n|;

      ## check to see if we already have this page
      $len = @pagenames; #number of elements in the array
      ## $count keeps track of the item number in the array - so $count = 1 means first element in the array
      ## $idx keeps track of the index, $idx = 0 means the first element in the array
      if ($pagenames[0]) {#if the array has something in it
         for ($count = 1; $count <= $len; $count++) {
            if (lc $pagenames[$idx] eq lc $pagename) { ## compare the pagenames in lowercase
               #out print {*STDOUT} qq| pagenames for $idx now $pagenames[$idx] \n|;
               if ($idfoundflag eq 'false') { ## we are only interested in the first (most recent) match
                 $idfound = $idx;
                 $idfoundflag = 'true'; ## do not look for it again
                 #out print {*STDOUT} qq| Found at position $idfound in array\n|;
               }
            }
            $idx++; ## keep track of where we are in the loop
            #out print {*STDOUT} qq| idx now $idx \n|;
         }
      } else {
         #out print {*STDOUT} qq| NOTHING in the array \n|;
      }


      my $maxindexsize = 5;
      ## decide where to store the page in the cache - 1. new cache entry, 2. update existing cache entry for same page, 3. overwrite the oldest page in the cache
      if ($idfoundflag eq 'false') { ## the page is not in the cache
            if ($idx>=$maxindexsize) {## the cache is full - so we need to overwrite the oldest page in the cache
               my $oldestindex = 0;
               my $oldestpagetime = $pageupdatetimes[0];
               for (my $i=1; $i < $maxindexsize; $i++) {
                    if ($pageupdatetimes[$i] < $oldestpagetime) { $oldestindex = $i; $oldestpagetime = $pageupdatetimes[$i]; }
               }
               $saveidx = $oldestindex;
               #print {*STDOUT} qq|\n Overwriting - Oldest Page Index: $oldestindex\n\n|; #debug
            } else {
               $saveidx = $idx;
               #out print {*STDOUT} qq| Last Index position is $idx, saving at $saveidx \n\n|;
            }
      } else {## we already have this page in the cache - so we just overwrite it with the latest version
         #out print {*STDOUT} qq| Found page at $idfound, we will overwrite \n\n|;
         $saveidx = $idfound;
      }

      ## update the global variables
      $pageupdatetimes[$saveidx] = time(); ## save time so we overwrite oldest when cache is full
      $pagenames[$saveidx] = $pagename; ## save page name
      $pages[$saveidx] = $page; ## save page source

      #my $i=0; ## debug - write out the contents of the cache
      #foreach my $cachedpage (@pagenames) {
      #    print {*STDOUT} qq| $i:$pageupdatetimes[$i]:$cachedpage \n|; #debug
      #    $i++;
      #}

   }

   return;
}

#------------------------------------------------------------------
sub autosub {## auto substitution - {DATA} and {NAME}
## {DATA} finds .NET field value from a previous test case and puts it in the postbody - no need for manual parseresponse
## Example: postbody="txtUsername=testuser&txtPassword=123&__VIEWSTATE={DATA}"
##
## {NAME} matches a dynamic component of a field name by looking at the page source of a previous test step
##        This is very useful if the field names change after a recompile, or a Content Management System is in use.
## Example: postbody="txtUsername{NAME}=testuser&txtPassword=123&__VIEWSTATE=456"
##          In this example, the actual user name field may have been txtUsername_xpos5_ypos8_33926509
##

    my ($postbody, $posttype, $posturl) = @_;

    my @postfields;
    my $fieldname;
    my $len=0;
    my $count=0;
    my $idx=0;
    my $pageid=0;
    my $pagefoundflag = 'false';
    my $fieldid=0;
    my $fieldfoundflag = 'false';
    my $data;
    my $datafound = 'false';
    my $startsubtimer=0;
    my $startlooptimer=0;
    my $endlooptimer=0;
    my $looplatency=0;
    my $sublatency=0;

    my $nameid=0;
    my $namefoundflag = 'false';
    my $lhsname='';
    my $rhsname='';
    my $name='';
    my $realnamefound='false';

    $startsubtimer = time();


    ## separate the fields
    if ($posttype eq "normalpost") {
       @postfields = split(/\&/, $postbody); ## & is separator
    } else {
       ## assumes that double quotes on the outside, internally single qoutes
       ## enhancements needed
       ##   1. subsitute out blank space first between the field separators
       @postfields = split(/\'\,/, $postbody); #separate the fields
    }

    ## debug - print the array
    $len = @postfields; #number of items in the array
    #print {*STDOUT} qq| \n There are $len fields in the postbody: \n |; #debug

    for ($count = 1; $count <= $len; $count++) {
        #print {*STDOUT} qq| Field $count: $postfields[$idx] \n|; #debug
        $idx++;
    }

    ## work out pagename to use for matching purposes
    if ($posturl =~ m~(.*?)\?~s) { ## we only want everything to the left of the ? mark
       $posturl = $1;
    }
    $posturl =~ s!http.?://!!s; ## remove http:// and https://
    #print {*STDOUT} qq| POSTURL $posturl \n|; #debug

    ## see if we have stored this page
    ## $count keeps track of the item number in the array - so $count = 1 means first element in the array
    ## $idx keeps track of the index, $idx = 0 means the first element in the array
    $len = @pagenames; #number of elements in the array
    $idx = 0;
    if ($pagenames[0]) {#if the array has something in it
       for ($count = 1; $count <= $len; $count++) {
          if (lc $pagenames[$idx] eq lc $posturl) { ## do the comparison in lowercase
             if ($pagefoundflag eq 'false') { ## we are only interested in the first (most recent) match
                $pageid = $idx;
                $pagefoundflag = 'true'; #do not look for it again
                #print {*STDOUT} qq| MATCH at position $pageid\n|; #debug
             }
          } else {
                #print {*STDOUT} qq| NO MATCH on $idx:$pagenames[$idx]\n|; #debug
          }

          $idx++; ## keep track of where we are in the loop
       }
    } else {
       #print {*STDOUT} qq| NO CACHED PAGES! \n|; #debug
    }

    $startlooptimer = time();

    ## time for substitutions
    if ($pagefoundflag eq 'true') {

       $len = @postfields; ## number of items in the array
       $idx = 0;
       for ($count = 1; $count <= $len; $count++) {
          ## is there anything to subsitute

          $nameid=0;
          $namefoundflag = 'false';
          $lhsname='';
          $rhsname='';
          $name='';
          $realnamefound='false';
          $datafound='false';
          my $dotx='false';
          my $doty='false';

          if ($postfields[$idx] =~ m~\.x[\=\']~) { ## does it end in .x?
             #out print {*STDOUT} qq| DOTX found in $postfields[$idx] \n|;
             $dotx = 'true';
             $postfields[$idx] =~ s~\.x~~; ## get rid of the .x, we'll have to put it back later
          }

          if ($postfields[$idx] =~ m~\.y[\=\']~) { ## does it end in .y?
             #out print {*STDOUT} qq| DOTY found in $postfields[$idx] \n|;
             $doty = 'true';
             $postfields[$idx] =~ s~\.y~~; ## get rid of the .y, we'll have to put it back later
          }

          if ($postfields[$idx] =~ m~([^']{0,70}?)\{NAME\}~s) { ## ' was *?, {0,70}? much quicker
             $lhsname = $1;
             $lhsname =~ s~\$~\\\$~g;
             $lhsname =~ s~\.~\\\.~g;
             #out print {*STDOUT} qq| LHS $lhsname has {NAME} \n|;
             $namefoundflag = 'true';
          }

          if ($postfields[$idx] =~ m~\{NAME\}([^=']{0,70})~s) { ## '
             $rhsname = $1;
             $rhsname =~ s~%24~\$~g; ## change any encoding for $ (i.e. %24) back to a literal $ - this is what we'll really find in the html source
             $rhsname =~ s~\$~\\\$~g; ## protect the $ with a \ in further regexs
             $rhsname =~ s~\.~\\\.~g; ## same for the .
             #out print {*STDOUT} qq| RHS $rhsname has {NAME} \n|;
             $namefoundflag = 'true';
          }

          ## time to find out what to substitute it with
          if ($namefoundflag eq 'true') {
             if ($pages[$pageid] =~ m~name=['"]$lhsname([^'"]{0,70}?)$rhsname['"]~s) { ## "
                $name = $1;
                $realnamefound = 'true';
                #out print {*STDOUT} qq| NAME is $name \n|;
             }
          }

          ## now to substitute in the data
          if ($realnamefound eq 'true') {
             if ($postfields[$idx] =~ s~{NAME}~$name~) {
                #out print {*STDOUT} qq| SUBBED_NAME is $postfields[$idx] \n|;
             }
          }

          ## did we take out the .x or .y? we need to put it back
          if ($dotx eq 'true') {
             if ($posttype eq "normalpost") {
                $postfields[$idx] =~ s~\=~\.x\=~;
             } else {
                $postfields[$idx] =~ s~\'[ ]?\=~\.x\' \=~; #[ ]? means match 0 or 1 space
             }
             #out print {*STDOUT} qq| DOTX restored to $postfields[$idx] \n|;
          }

          ## did we take out the .x or .y? we need to put it back
          if ($doty eq 'true') {
             if ($posttype eq "normalpost") {
                $postfields[$idx] =~ s~\=~\.y\=~;
             } else {
                $postfields[$idx] =~ s~\'[ ]?\=~\.y\' \=~;
             }
             #out print {*STDOUT} qq| DOTY restored to $postfields[$idx] \n|;
          }

          $fieldid=0;
          $fieldfoundflag = 'false';

          if ($posttype eq "normalpost") {
             if ($postfields[$idx] =~ m~(.{0,70}?)\=\{DATA\}~s) {
                $fieldname = $1;
                #print {*STDOUT} qq| Normal Field $fieldname has {DATA} \n|; #debug
                $fieldfoundflag = 'true';
             }
          }

          if ($posttype eq "multipost") {
             if ($postfields[$idx] =~ m~\'(.{0,70}?)\'.{0,70}?{DATA\}~s) {
                $fieldname = $1;
                #print {*STDOUT} qq| Multi Field $fieldname has {DATA} \n|; #debug
                $fieldfoundflag = 'true';
             }
          }

          ## time to find out what to substitute it with
          if ($fieldfoundflag eq 'true') {
             $fieldname =~ s~\$~\\\$~; #replace $ with \$
             $fieldname =~ s~\.~\\\.~; #replace . with \.
             if ($pages[$pageid] =~ m~="$fieldname" [^\>]*value="(.*?)"~s) {
                $data = $1;
                $datafound = 'true';
                #print {*STDOUT} qq| DATA is $data \n|; #debug
             }
          }

          ## now to substitute in the data
          if ($datafound eq 'true') {
             if ($posttype eq 'normalpost') {## normal post must be escaped
                $data = url_escape($data);
                #print {*STDOUT} qq| URLESCAPE!! \n|; #debug
             }
             if ($postfields[$idx] =~ s~{DATA}~$data~) {
                #print {*STDOUT} qq| SUBBED_FIELD is $postfields[$idx] \n|; #debug
             }
          }

          $idx++;
          #print {*STDOUT} qq| idx now $idx for field $postfields[$idx] \n|; #debug
       }
    }

    ## done all the substitutions, now put it all together again
    if ($posttype eq "normalpost") {
       $postbody = join("&", @postfields);
    } else {
       ## assumes that double quotes on the outside, internally single qoutes
       ## enhancements needed
       ##   1. subsitute out blank space first between the field separators
       $postbody = join("',", @postfields);
    }
    #out print {*STDOUT} qq|\n\n POSTBODY is $postbody \n|;

    $endlooptimer = time();
    $looplatency = (int(1000 * ($endlooptimer - $startlooptimer)) / 1000);  ## elapsed time rounded to thousandths
    $sublatency = (int(1000 * ($endlooptimer - $startsubtimer)) / 1000);  ## elapsed time rounded to thousandths

    ## debug - make sure all the regular expressions are efficient
    #print {*STDOUT} qq| Looping took $looplatency \n|; #debug
    #print {*STDOUT} qq| All     took $sublatency \n|; #debug

    return $postbody;
}

#------------------------------------------------------------------
sub httpget {  #send http request and read response

    $request = HTTP::Request->new('GET',"$case{url}");

    #1.42 Moved cookie management up above addheader as per httppost_form_data
    $cookie_jar->add_cookie_header($request);
    #print $request->as_string; print "\n\n";

    addcookie (); ## append additional cookies rather than overwriting with add header

    if ($case{addheader}) {  #add an additional HTTP Header if specified
        my @addheaders = split(/\|/, $case{addheader});  #can add multiple headers with a pipe delimiter
        foreach (@addheaders) {
            $_ =~ m~(.*): (.*)~;
            $request->header($1 => $2);  #using HTTP::Headers Class
        }
    }


    $starttimer = time();
    $response = $useragent->request($request);
    $endtimer = time();
    $latency = (int(1000 * ($endtimer - $starttimer)) / 1000);  #elapsed time rounded to thousandths
    #print $response->as_string; print "\n\n";

    $cookie_jar->extract_cookies($response);
    #print $cookie_jar->as_string; print "\n\n";

    savepage (); ## save page in the cache for the auto substitutions

    return;
}

#------------------------------------------------------------------
sub httppost {  #post request based on specified encoding

    if ($case{posttype}) {
         if (($case{posttype} =~ m~application/x-www-form-urlencoded~) or ($case{posttype} =~ m~application/json~)) { httppost_form_urlencoded(); } ## application/json support
         elsif ($case{posttype} =~ m~multipart/form-data~) { httppost_form_data(); }
         elsif (($case{posttype} =~ m~text/xml~) or ($case{posttype} =~ m~application/soap+xml~)) { httppost_xml(); }
         else { print STDERR qq|ERROR: Bad Form Encoding Type, I only accept "application/x-www-form-urlencoded", "application/json", "multipart/form-data", "text/xml", "application/soap+xml" \n|; }
       }
    else {
        $case{posttype} = 'application/x-www-form-urlencoded';
        httppost_form_urlencoded();  #use "x-www-form-urlencoded" if no encoding is specified
    }

    savepage (); ## for auto substitutions

    return;
}

#------------------------------------------------------------------
sub httppost_form_urlencoded {  #send application/x-www-form-urlencoded or application/json HTTP request and read response

    my $substituted_postbody; ## auto substitution
    $substituted_postbody = autosub("$case{postbody}", "normalpost", "$case{url}");

    $request = HTTP::Request->new('POST',"$case{url}");
    $request->content_type("$case{posttype}");
    #$request->content("$case{postbody}");
    $request->content("$substituted_postbody");

    ## moved cookie management up above addheader as per httppost_form_data
    $cookie_jar->add_cookie_header($request);

    addcookie (); ## append to additional cookies rather than overwriting with add header

    if ($case{addheader}) {  # add an additional HTTP Header if specified
        my @addheaders = split(/\|/, $case{addheader});  #can add multiple headers with a pipe delimiter
        foreach (@addheaders) {
            $_ =~ m~(.*): (.*)~;
            $request->header($1 => $2);  #using HTTP::Headers Class
        }
        #$case{addheader} = ''; ## why is this line here? Fails with retry, so commented out
    }

    #print $request->as_string; print "\n\n";
    $starttimer = time();
    $response = $useragent->request($request);
    $endtimer = time();
    $latency = (int(1000 * ($endtimer - $starttimer)) / 1000);  #elapsed time rounded to thousandths
    #print $response->as_string; print "\n\n";

    $cookie_jar->extract_cookies($response);
    #print $cookie_jar->as_string; print "\n\n";

    return;
}

#------------------------------------------------------------------
sub httppost_xml{  #send text/xml HTTP request and read response

    my @parms;
    my $len;
    my $idx;
    my $fieldname;
    my $fieldvalue;
    my $subname;

    #read the xml file specified in the testcase
    $case{postbody} =~ m~file=>(.*)~i;
    open( my $XMLBODY, '<', "$dirname"."$1") or die "\nError: Failed to open text/xml file\n\n";  #open file handle
    my @xmlbody = <$XMLBODY>;  #read the file into an array
    close($XMLBODY);

    if ($case{parms}) { #is there a postbody for this testcase - if so need to subtitute in fields
       @parms = split(/\&/, $case{parms}); #& is separator
       $len = @parms; #number of items in the array
       #out print {*STDOUT} qq| \n There are $len fields in the parms \n|;

       #loop through each of the fields and substitute
       for ($idx = 1; $idx <= $len; $idx++) {
            $fieldname = '';
            #out print {*STDOUT} qq| \n parms $idx: $parms[$idx-1] \n |;
            if ($parms[$idx-1] =~ m~(.*?)\=~s) { #we only want everything to the left of the = sign
                $fieldname = $1;
                #out print {*STDOUT} qq| fieldname: $fieldname \n|;
            }
            $fieldvalue = '';
            if ($parms[$idx-1] =~ m~\=(.*)~s) { #we only want everything to the right of the = sign
                $fieldvalue = $1;
                #out print {*STDOUT} qq| fieldvalue: $fieldvalue \n\n|;
            }

            #make the substitution
            foreach (@xmlbody) {
                #non escaped fields
                $_ =~ s~\<$fieldname\>.*?\<\/$fieldname\>~\<$fieldname\>$fieldvalue\<\/$fieldname\>~;

                #escaped fields
                $_ =~ s~\&lt;$fieldname\&gt;.*?\&lt;\/$fieldname\&gt;~\&lt;$fieldname\&gt;$fieldvalue\&lt;\/$fieldname\&gt;~;

                #attributes
                # ([^a-zA-Z]) says there must be a non alpha so that bigid and id and treated separately
                # $1 will put it back - otherwise it'll be eaten
                $_ =~ s~([^a-zA-Z])$fieldname\=\".*?\"~$1$fieldname\=\"$fieldvalue\"~;

                #variable substitution
                $subname = $fieldname;
                if ($subname =~ s~__~~) {#if there are double underscores, like __salarymax__ then replace it
                    $_ =~ s~__$subname~$fieldvalue~g;
                }

            }

       }

    }

    $request = HTTP::Request->new('POST', "$case{url}");
    $request->content_type("$case{posttype}");
    $request->content(join(" ", @xmlbody));  #load the contents of the file into the request body

## moved cookie management up above addheader as per httppost_form_data
    $cookie_jar->add_cookie_header($request);

    if ($case{addheader}) {  #add an additional HTTP Header if specified
        my @addheaders = split(/\|/, $case{addheader});  #can add multiple headers with a pipe delimiter
        foreach (@addheaders) {
            $_ =~ m~(.*): (.*)~;
            $request->header($1 => $2);  #using HTTP::Headers Class
        }
        #$case{addheader} = ''; ## why is this line here? Fails with retry, so commented out
    }

    #print $request->as_string; print "\n\n";
    $starttimer = time();
    $response = $useragent->request($request);
    $endtimer = time();
    $latency = (int(1000 * ($endtimer - $starttimer)) / 1000);  #elapsed time rounded to thousandths
    #print $response->as_string; print "\n\n";

    $cookie_jar->extract_cookies($response);
    #print $cookie_jar->as_string; print "\n\n";

    return;
}

#------------------------------------------------------------------
sub httppost_form_data {  #send multipart/form-data HTTP request and read response

    my $substituted_postbody; ## auto substitution
    $substituted_postbody = autosub("$case{postbody}", "multipost", "$case{url}");

    my %myContent_;
    eval "\%myContent_ = $substituted_postbody";  ## no critic
    $request = POST "$case{url}",
               Content_Type => "$case{posttype}",
               Content => \%myContent_;
    $cookie_jar->add_cookie_header($request);
    #print $request->as_string; print "\n\n";

    addcookie (); ## append additional cookies rather than overwriting with add header

    if ($case{addheader}) {  #add an additional HTTP Header if specified
        my @addheaders = split(/\|/, $case{addheader});  #can add multiple headers with a pipe delimiter
        foreach (@addheaders) {
            $_ =~ m~(.*): (.*)~;
            $request->header($1 => $2);  #using HTTP::Headers Class
        }
    }

    $starttimer = time();
    $response = $useragent->request($request);
    $endtimer = time();
    $latency = (int(1000 * ($endtimer - $starttimer)) / 1000);  #elapsed time rounded to thousandths
    #print $response->as_string; print "\n\n";

    $cookie_jar->extract_cookies($response);
    #print $cookie_jar->as_string; print "\n\n";

    return;
}

#------------------------------------------------------------------
sub cmd {  ## send terminal command and read response

    my $combinedresp='';
    $request = HTTP::Request->new('GET',"CMD");
    $starttimer = time();

    for (qw/command command1 command2 command3 command4 command5 command6 command7 command8 command9 command10 command11 command12 command13 command14 command15 command16 command17 command18 command19 command20/) {
        if ($case{$_}) {#perform command

            my $cmd = $case{$_};
            $cmd =~ s/\%20/ /g; ## turn %20 to spaces for display in log purposes
            #$request = new HTTP::Request('GET',$cmd);  ## pretend it is a HTTP GET request - but we won't actually invoke it
            $cmdresp = (`$cmd 2>\&1`); ## run the cmd through the backtick method - 2>\&1 redirects error output to standard output
            $combinedresp =~ s!$!<$_>$cmd</$_>\n$cmdresp\n\n\n!; ## include it in the response
        }
    }
    $combinedresp =~ s!^!HTTP/1.1 100 OK\n!; ## pretend this is an HTTP response - 100 means continue
    $response = HTTP::Response->parse($combinedresp); ## pretend the response is a http response - inject it into the object
    $endtimer = time();
    $latency = (int(1000 * ($endtimer - $starttimer)) / 1000);  ## elapsed time rounded to thousandths

    return;
}

#------------------------------------------------------------------
sub commandonerror {  ## command only gets run on error - it does not count as part of the test
                      ## intended for scenarios when you want to give something a kick - e.g. recycle app pool

    my $combinedresp = $response->as_string; ## take the existing test response

    for (qw/commandonerror/) {
        if ($case{$_}) {## perform command

            my $cmd = $case{$_};
            $cmd =~ s/\%20/ /g; ## turn %20 to spaces for display in log purposes
            $cmdresp = (`$cmd 2>\&1`); ## run the cmd through the backtick method - 2>\&1 redirects error output to standard output
            $combinedresp =~ s!$!<$_>$cmd</$_>\n$cmdresp\n\n\n!; ## include it in the response
        }
    }
    $response = HTTP::Response->parse($combinedresp); ## put the test response along with the command on error response back in the response

    return;
}


#------------------------------------------------------------------
sub searchimage {  ## search for images in the actual result

    my $unmarked = "true";
    my $imagecopy;

    for (qw/searchimage searchimage1 searchimage2 searchimage3 searchimage4 searchimage5/) {
        if ($case{$_}) {
            if (-e "$cwd$opt_basefolder$case{$_}") { ## imageinimage bigimage smallimage markimage
                if ($unmarked eq "true") {
                   $imagecopy = (`copy $cwd\\$output$testnumlog$jumpbacksprint$retriesprint.png $cwd\\$output$testnumlog$jumpbacksprint$retriesprint-marked.png`);
                   $unmarked = "false";
                }
                my $siresp = (`imageinimage.py $cwd\\$output$testnumlog$jumpbacksprint$retriesprint.png "$cwd$opt_basefolder$case{$_}" $cwd\\$output$testnumlog$jumpbacksprint$retriesprint-marked.png`);
                $siresp =~ m~primary confidence (\d+)~s;
                my $primaryconfidence = $1;
                $siresp =~ m~alternate confidence (\d+)~s;
                my $alternateconfidence = $1;
                $siresp =~ m~min_loc (.*?)X~s;
                my $location = $1;

                if ($siresp =~ m~was found~s) { ## was the image found?
                    print {$RESULTS} qq|<span class="found">Found image: $case{$_}</span><br />\n|;
                    print {$RESULTSXML} qq|            <$_-success>true</$_-success>\n|;
                    print {$RESULTSXML} qq|            <$_-name>$case{$_}</$_-name>\n|;
                    print {*STDOUT} "Found: $case{$_}\n   $primaryconfidence primary confidence\n   $alternateconfidence alternate confidence\n   $location location\n";
                    $passedcount++;
                    $retrypassedcount++;
                }
                else { #the image was not found within the bigger image
                    print {$RESULTS} qq|<span class="notfound">Image not found: $case{$_}</span><br />\n|;
                    print {$RESULTSXML} qq|            <$_-success>false</$_-success>\n|;
                    print {$RESULTSXML} qq|            <$_-name>$case{$_}</$_-name>\n|;
                    print {*STDOUT} "Not found: $case{$_}\n   $primaryconfidence primary confidence\n   $alternateconfidence alternate confidence\n   $location location\n";
                    $failedcount++;
                    $retryfailedcount++;
                    $isfailure++;
                }
            } else {#We were not able to find the image to search for
                print {*STDOUT} "SearchImage error - Was the filename correct?\n";
            }
        } ## end first if
    } ## end for

    if ($unmarked eq "false") {
       #keep an unmarked image, make the marked the actual result
       $imagecopy = (`move $cwd\\$output$testnumlog$jumpbacksprint$retriesprint.png $cwd\\$output$testnumlog$jumpbacksprint$retriesprint-unmarked.png`);
       $imagecopy = (`move $cwd\\$output$testnumlog$jumpbacksprint$retriesprint-marked.png $cwd\\$output$testnumlog$jumpbacksprint$retriesprint.png`);
    }

    return;
} ## end sub



#------------------------------------------------------------------
sub verify {  #do verification of http response and print status to HTML/XML/STDOUT/UI
    my $verifynum; ##
    my $count; ##
    my $tempstring; ##
    my $assertionskips = 0;
    my $assertionskipsmessage = ""; ## support tagging an assertion as disabled with a message

    ## auto assertions
    if ($entrycriteriaok && !$case{ignoreautoassertions}) {
        ## autoassertion, autoassertion1, ..., autoassertion4, ..., autoassertion10000 (or more)
        foreach my $configAttrib ( sort keys %{ $userconfig->{autoassertions} } ) {
            if ( substr($configAttrib, 0, 13) eq "autoassertion" ) {
                $verifynum = $configAttrib; ## determine index verifypositive index
                $verifynum =~ s/\D//g; #Remove all text from string - example 'verifypositive3'
                if (!$verifynum) {$verifynum = '0';} #In case of autoassertion, need to treat as 0
                @verifyparms = split(/\|\|\|/, $userconfig->{autoassertions}{$configAttrib}); #index 0 contains the actual string to verify, 1 the message to show if the assertion fails, 2 the tag that it is a known issue
                if ($verifyparms[2]) { ## assertion is being ignored due to known production bug or whatever
                    print {$RESULTS} qq|<span class="skip">Skipped Auto Assertion $verifynum - $verifyparms[2]</span><br />\n|;
                    print {*STDOUT} "Skipped Auto Assertion $verifynum - $verifyparms[2] \n";
                    $assertionskips++;
                    $assertionskipsmessage = $assertionskipsmessage . "[" . $verifyparms[2] . "]";
                }
                else {
                    #print {*STDOUT} "$verifyparms[0]\n"; ##DEBUG
                    if ($response->as_string() =~ m~$verifyparms[0]~si) {  ## verify existence of string in response
                        #print {$RESULTS} qq|<span class="pass">Passed Auto Assertion</span><br />\n|; ## Do not print out all the auto assertion passes
                        print {$RESULTSXML} qq|            <$configAttrib-success>true</$configAttrib-success>\n|;
                        #print {*STDOUT} "Passed Auto Assertion \n"; ## Do not print out all the auto assertion passes
                        #print {*STDOUT} $verifynum." Passed Auto Assertion \n"; ##DEBUG
                        $passedcount++;
                        $retrypassedcount++;
                    }
                    else {
                        print {$RESULTS} qq|<span class="fail">Failed Auto Assertion:</span>$verifyparms[0]<br />\n|;
                        print {$RESULTSXML} qq|            <$configAttrib-success>false</$configAttrib-success>\n|;
                        if ($verifyparms[1]) { ## is there a custom assertion failure message?
                           print {$RESULTS} qq|<span class="fail">$verifyparms[1]</span><br />\n|;
                           print {$RESULTSXML} qq|            <$configAttrib-message>$verifyparms[1]</$configAttrib-message>\n|;
                        }
                        print {*STDOUT} "Failed Auto Assertion \n";
                        if ($verifyparms[1]) {
                           print {*STDOUT} "$verifyparms[1] \n";
                        }
                        $failedcount++;
                        $retryfailedcount++;
                        $isfailure++;
                    }
                }
            }
        }
    }

    ## smart assertions
    if ($entrycriteriaok && !$case{ignoresmartassertions}) {
        foreach my $configAttrib ( sort keys %{ $userconfig->{smartassertions} } ) {
            if ( substr($configAttrib, 0, 14) eq "smartassertion" ) {
                $verifynum = $configAttrib; ## determine index verifypositive index
                $verifynum =~ s/\D//g; #Remove all text from string - example 'verifypositive3'
                if (!$verifynum) {$verifynum = '0';} #In case of smartassertion, need to treat as 0
                @verifyparms = split(/\|\|\|/, $userconfig->{smartassertions}{$configAttrib}); #index 0 contains the pre-condition assertion, 1 the actual assertion, 3 the tag that it is a known issue
                if ($verifyparms[3]) { ## assertion is being ignored due to known production bug or whatever
                    print {$RESULTS} qq|<span class="skip">Skipped Smart Assertion $verifynum - $verifyparms[3]</span><br />\n|;
                    print {*STDOUT} "Skipped Smart Assertion $verifynum - $verifyparms[2] \n";
                    $assertionskips++;
                    $assertionskipsmessage = $assertionskipsmessage . "[" . $verifyparms[2] . "]";
                }
                else {
                    #print {*STDOUT} "$verifyparms[0]\n"; ##DEBUG
                    if ($response->as_string() =~ m~$verifyparms[0]~si) {  ## pre-condition for smart assertion - first regex must pass
                        if ($response->as_string() =~ m~$verifyparms[1]~si) {  ## verify existence of string in response
                            #print {$RESULTS} qq|<span class="pass">Passed Smart Assertion</span><br />\n|; ## Do not print out all the auto assertion passes
                            print {$RESULTSXML} qq|            <$configAttrib-success>true</$configAttrib-success>\n|;
                            #print {*STDOUT} "Passed Smart Assertion \n"; ## Do not print out the Smart Assertion passes
                            $passedcount++;
                            $retrypassedcount++;
                        }
                        else {
                            print {$RESULTS} qq|<span class="fail">Failed Smart Assertion:</span>$verifyparms[0]<br />\n|;
                            print {$RESULTSXML} qq|            <$configAttrib-success>false</$configAttrib-success>\n|;
                            if ($verifyparms[2]) { ## is there a custom assertion failure message?
                               print {$RESULTS} qq|<span class="fail">$verifyparms[2]</span><br />\n|;
                               print {$RESULTSXML} qq|            <$configAttrib-message>$verifyparms[2]</$configAttrib-message>\n|;
                            }
                            print {*STDOUT} "Failed Smart Assertion";
                            if ($verifyparms[2]) {
                               print {*STDOUT} ": $verifyparms[2]";
                            }
                            print {*STDOUT} "\n";
                            $failedcount++;
                            $retryfailedcount++;
                            $isfailure++;
                        }
                    } ## end if - is pre-condition for smart assertion met?
                }
            }
        }
    }

    ## verify positive
    if ($entrycriteriaok) {
        ## verifypositive, verifypositive1, ..., verifypositive25, ..., verifypositive10000 (or more)
        foreach my $testAttrib ( sort keys %{ $xmltestcases->{case}->{$testnum} } ) {
            if ( substr($testAttrib, 0, 14) eq "verifypositive" ) {
                $verifynum = $testAttrib; ## determine index verifypositive index
                $verifynum =~ s/\D//g; #Remove all text from string - example 'verifypositive3'
                if (!$verifynum) {$verifynum = '0';} #In case of verifypositive, need to treat as 0
                @verifyparms = split(/\|\|\|/, $case{$testAttrib}); #index 0 contains the actual string to verify, 1 the message to show if the assertion fails, 2 the tag that it is a known issue
                if ($verifyparms[2]) { ## assertion is being ignored due to known production bug or whatever
                    print {$RESULTS} qq|<span class="skip">Skipped Positive Verification $verifynum - $verifyparms[2]</span><br />\n|;
                    print {*STDOUT} "Skipped Positive Verification $verifynum - $verifyparms[2] \n";
                    $assertionskips++;
                    $assertionskipsmessage = $assertionskipsmessage . "[" . $verifyparms[2] . "]";
                }
                else {
                    if ($response->as_string() =~ m~$verifyparms[0]~si) {  ## verify existence of string in response
                        print {$RESULTS} qq|<span class="pass">Passed Positive Verification</span><br />\n|;
                        print {$RESULTSXML} qq|            <$testAttrib-success>true</$testAttrib-success>\n|;
                        print {*STDOUT} "Passed Positive Verification \n";
                        #print {*STDOUT} $verifynum." Passed Positive Verification \n"; ##DEBUG
                        $lastpositive[$verifynum] = 'pass'; ## remember fact that this verifypositive passed
                        $passedcount++;
                        $retrypassedcount++;
                    }
                    else {
                        print {$RESULTS} qq|<span class="fail">Failed Positive Verification:</span>$verifyparms[0]<br />\n|;
                        print {$RESULTSXML} qq|            <$testAttrib-success>false</$testAttrib-success>\n|;
                        if ($verifyparms[1]) { ## is there a custom assertion failure message?
                           print {$RESULTS} qq|<span class="fail">$verifyparms[1]</span><br />\n|;
                           print {$RESULTSXML} qq|            <$testAttrib-message>$verifyparms[1]</$testAttrib-message>\n|;
                        }
                        print {*STDOUT} "Failed Positive Verification \n";
                        if ($verifyparms[1]) {
                           print {*STDOUT} "$verifyparms[1] \n";
                        }
                        $lastpositive[$verifynum] = 'fail'; ## remember fact that this verifypositive failed
                        $failedcount++;
                        $retryfailedcount++;
                        $isfailure++;
                    }
                }
            }
        }
    }

    ## verify negative
    if ($entrycriteriaok) {
        ## verifynegative, verifynegative1, ..., verifynegative25, ..., verifynegative10000 (or more)
        foreach my $testAttrib ( sort keys %{ $xmltestcases->{case}->{$testnum} } ) {
            if ( substr($testAttrib, 0, 14) eq "verifynegative" ) {
                $verifynum = $testAttrib; ## determine index verifypositive index
                #print {*STDOUT} "$testAttrib\n"; ##DEBUG
                $verifynum =~ s/\D//g; ## remove all text from string - example 'verifypositive3'
                if (!$verifynum) {$verifynum = '0';} ## in case of verifypositive, need to treat as 0
                @verifyparms = split(/\|\|\|/, $case{$testAttrib}); #index 0 contains the actual string to verify
                if ($verifyparms[2]) { ## assertion is being ignored due to known production bug or whatever
                    print {$RESULTS} qq|<span class="skip">Skipped Negative Verification $verifynum - $verifyparms[2]</span><br />\n|;
                    print {*STDOUT} "Skipped Negative Verification $verifynum - $verifyparms[2] \n";
                    $assertionskips++;
                    $assertionskipsmessage = $assertionskipsmessage . "[" . $verifyparms[2] . "]";
                }
                else {
                    if ($response->as_string() =~ m~$verifyparms[0]~si) {  #verify existence of string in response
                        print {$RESULTS} qq|<span class="fail">Failed Negative Verification</span><br />\n|;
                        print {$RESULTSXML} qq|            <$testAttrib-success>false</$testAttrib-success>\n|;
                        if ($verifyparms[1]) {
                           print {$RESULTS} qq|<span class="fail">$verifyparms[1]</span><br />\n|;
                             print {$RESULTSXML} qq|            <$testAttrib-message>$verifyparms[1]</$testAttrib-message>\n|;
                        }
                        print {*STDOUT} "Failed Negative Verification \n";
                        if ($verifyparms[1]) {
                           print {*STDOUT} "$verifyparms[1] \n";
                        }
                        $lastnegative[$verifynum] = 'fail'; ## remember fact that this verifynegative failed
                        $failedcount++;
                        $retryfailedcount++;
                        $isfailure++;
                        if ($retry > 0) { print {*STDOUT} "==> Won't retry - a verifynegative failed \n"; }
                        $retry=0; ## we won't retry if any of the verifynegatives fail
                        $verifynegativefailed = "true";
                    }
                    else {
                        print {$RESULTS} qq|<span class="pass">Passed Negative Verification</span><br />\n|;
                        print {$RESULTSXML} qq|            <$testAttrib-success>true</$testAttrib-success>\n|;
                        print {*STDOUT} "Passed Negative Verification \n";
                        $lastnegative[$verifynum] = 'pass'; ## remember fact that this verifynegative passed
                        $passedcount++;
                        $retrypassedcount++;
                    }
                }
            }
        }
    }

    ## assert count
    if ($entrycriteriaok) {
        foreach my $testAttrib ( sort keys %{ $xmltestcases->{case}->{$testnum} } ) {
            if ( substr($testAttrib, 0, 11) eq "assertcount" ) {
                $verifynum = $testAttrib; ## determine index verifypositive index
                #print {*STDOUT} "$testAttrib\n"; ##DEBUG
                $verifynum =~ s/\D//g; ## remove all text from string - example 'verifypositive3'
                if (!$verifynum) {$verifynum = '0';} ## in case of verifypositive, need to treat as 0
                @verifycountparms = split(/\|\|\|/, $case{$testAttrib});
                $count=0;
                $tempstring=$response->as_string(); #need to put in a temporary variable otherwise it gets stuck in infinite loop

                while ($tempstring =~ m|$verifycountparms[0]|ig) { $count++;} ## count how many times string is found

                if ($verifycountparms[3]) { ## assertion is being ignored due to known production bug or whatever
                    print {$RESULTS} qq|<span class="skip">Skipped Assertion Count - $verifycountparms[3]</span><br />\n|;
                    print {*STDOUT} "Skipped Assertion Count - $verifycountparms[2] \n";
                    $assertionskips++;
                    $assertionskipsmessage = $assertionskipsmessage . "[" . $verifyparms[2] . "]";
                }
                else {
                    if ($count == $verifycountparms[1]) {
                        print {$RESULTS} qq|<span class="pass">Passed Count Assertion of $verifycountparms[1]</span><br />\n|;
                        print {$RESULTSXML} qq|            <$testAttrib-success>true</$testAttrib-success>\n|;
                        print {*STDOUT} "Passed Count Assertion of $verifycountparms[1] \n";
                        $passedcount++;
                        $retrypassedcount++;
                    }
                    else {
                        print {$RESULTSXML} qq|            <$testAttrib-success>false</$testAttrib-success>\n|;
                        if ($verifycountparms[2]) {## if there is a custom message, write it out
                            print {$RESULTS} qq|<span class="fail">Failed Count Assertion of $verifycountparms[1], got $count</span><br />\n|;
                            print {$RESULTS} qq|<span class="fail">$verifycountparms[2]</span><br />\n|;
                            print {$RESULTSXML} qq|            <$testAttrib-message>$verifycountparms[2] [got $count]</$testAttrib-message>\n|;
                        }
                        else {# we make up a standard message
                            print {$RESULTS} qq|<span class="fail">Failed Count Assertion of $verifycountparms[1], got $count</span><br />\n|;
                            print {$RESULTSXML} qq|            <$testAttrib-message>Failed Count Assertion of $verifycountparms[1], got $count</$testAttrib-message>\n|;
                        }
                        print {*STDOUT} "Failed Count Assertion of $verifycountparms[1], got $count \n";
                        if ($verifycountparms[2]) {
                            print {*STDOUT} "$verifycountparms[2] \n";
                        }
                        $failedcount++;
                        $retryfailedcount++;
                        $isfailure++;
                    } ## end else verifycountparms[2]
                } ## end else verifycountparms[3]
            } ## end if assertcount
        } ## end foreach
    } ## end if entrycriteriaOK

    if ($entrycriteriaok) {
         if ($case{verifyresponsetime}) { ## verify that the response time is less than or equal to given amount in seconds
             if ($latency <= $case{verifyresponsetime}) {
                    print {$RESULTS} qq|<span class="pass">Passed Response Time Verification</span><br />\n|;
                    print {$RESULTSXML} qq|            <verifyresponsetime-success>true</verifyresponsetime-success>\n|;
                    print {*STDOUT} "Passed Response Time Verification \n";
                    $passedcount++;
                    $retrypassedcount++;
             }
             else {
                    print {$RESULTS} qq|<span class="fail">Failed Response Time Verification - should be at most $case{verifyresponsetime}, got $latency</span><br />\n|;
                    print {$RESULTSXML} qq|            <verifyresponsetime-success>false</verifyresponsetime-success>\n|;
                    print {$RESULTSXML} qq|            <verifyresponsetime-message>Latency should be at most $case{verifyresponsetime} seconds</verifyresponsetime-message>\n|;
                    print {*STDOUT} "Failed Response Time Verification - should be at most $case{verifyresponsetime}, got $latency \n";
                    $failedcount++;
                    $retryfailedcount++;
                    $isfailure++;
            }
         }
    }

    if ($entrycriteriaok) {
        $forcedretry="false";
        if ($case{retryresponsecode}) {## retryresponsecode - retry on a certain response code, normally we would immediately fail the case
            if ($case{retryresponsecode} == $response->code()) { ## verify returned HTTP response code matches retryresponsecode set in test case
                print {$RESULTS} qq|<span class="pass">Will retry on response code </span><br />\n|;
                print {$RESULTSXML} qq|            <retryresponsecode-success>true</retryresponsecode-success>\n|;
                print {$RESULTSXML} qq|            <retryresponsecode-message>Found Retry HTTP Response Code</retryresponsecode-message>\n|;
                print {*STDOUT} qq|Found Retry HTTP Response Code \n|;
                $forcedretry="true"; ## force a retry even though we received a potential error code
            }
        }
    }

    $lastresponsecode = $response->code(); ## remember the last response code for checking entry criteria for the next test case
    #print "\n\n\ DEBUG    $lastresponsecode \n\n";
    if ($case{verifyresponsecode}) {
        if ($case{verifyresponsecode} == $response->code()) { #verify returned HTTP response code matches verifyresponsecode set in test case
            print {$RESULTS} qq|<span class="pass">Passed HTTP Response Code Verification </span><br />\n|;
            print {$RESULTSXML} qq|            <verifyresponsecode-success>true</verifyresponsecode-success>\n|;
            print {$RESULTSXML} qq|            <verifyresponsecode-message>Passed HTTP Response Code Verification</verifyresponsecode-message>\n|;
            print {*STDOUT} qq|Passed HTTP Response Code Verification \n|;
            $passedcount++;
            $retrypassedcount++;
            $retry=0; ## we won't retry if the response code is invalid since it will probably never work
            }
        else {
            print {$RESULTS} qq|<span class="fail">Failed HTTP Response Code Verification (received | . $response->code() .  qq|, expecting $case{verifyresponsecode})</span><br />\n|;
            print {$RESULTSXML} qq|            <verifyresponsecode-success>false</verifyresponsecode-success>\n|;
            print {$RESULTSXML} qq|            <verifyresponsecode-message>Failed HTTP Response Code Verification (received | . $response->code() .  qq|, expecting $case{verifyresponsecode})</verifyresponsecode-message>\n|;
            print {*STDOUT} qq|Failed HTTP Response Code Verification (received | . $response->code() .  qq|, expecting $case{verifyresponsecode}) \n|;
            $failedcount++;
            $retryfailedcount++;
            $isfailure++;
        }
    }
    else { #verify http response code is in the 100-399 range
        if (($response->as_string() =~ /HTTP\/1.(0|1) (1|2|3)/i) || $case{ignorehttpresponsecode}) {  #verify existance of string in response - unless we are ignore error codes
            print {$RESULTS} qq|<span class="pass">Passed HTTP Response Code Verification</span><br />\n|;
            print {$RESULTSXML} qq|            <verifyresponsecode-success>true</verifyresponsecode-success>\n|;
            print {$RESULTSXML} qq|            <verifyresponsecode-message>Passed HTTP Response Code Verification</verifyresponsecode-message>\n|;
            print {*STDOUT} qq|Passed HTTP Response Code Verification \n|;
            #succesful response codes: 100-399
            $passedcount++;
            $retrypassedcount++;
        }
        else {
            $response->as_string() =~ /(HTTP\/1.)(.*)/i;
            if (!$entrycriteriaok){ ## test wasn't run due to entry criteria not being met
                print {$RESULTS} qq|<span class="fail">Failed - Entry criteria not met</span><br />\n|; #($1$2) is HTTP response code
                print {$RESULTSXML} qq|            <verifyresponsecode-success>false</verifyresponsecode-success>\n|;
                print {$RESULTSXML} qq|            <verifyresponsecode-message>Failed - Entry criteria not met</verifyresponsecode-message>\n|;
                print {*STDOUT} "Failed - Entry criteria not met \n"; #($1$2) is HTTP response code
            }
            elsif ($1) {  #this is true if an HTTP response returned
                print {$RESULTS} qq|<span class="fail">Failed HTTP Response Code Verification ($1$2)</span><br />\n|; #($1$2) is HTTP response code
                print {$RESULTSXML} qq|            <verifyresponsecode-success>false</verifyresponsecode-success>\n|;
                print {$RESULTSXML} qq|            <verifyresponsecode-message>($1$2)</verifyresponsecode-message>\n|;
                print {*STDOUT} "Failed HTTP Response Code Verification ($1$2) \n"; #($1$2) is HTTP response code
            }
            else {  #no HTTP response returned.. could be error in connection, bad hostname/address, or can not connect to web server
                print {$RESULTS} qq|<span class="fail">Failed - No Response</span><br />\n|; #($1$2) is HTTP response code
                print {$RESULTSXML} qq|            <verifyresponsecode-success>false</verifyresponsecode-success>\n|;
                print {$RESULTSXML} qq|            <verifyresponsecode-message>Failed - No Response</verifyresponsecode-message>\n|;
                print {*STDOUT} "Failed - No Response \n"; #($1$2) is HTTP response code
            }
            if ($forcedretry eq "false") {
                $failedcount++;
                $retryfailedcount++;
                $isfailure++;
                if ($retry > 0) { print {*STDOUT} "==> Won't retry - received HTTP error code\n"; }
                $retry=0; # we won't try again if we can't connect
            }
        }
    }

    if ($assertionskips > 0) {
        $totalassertionskips = $totalassertionskips + $assertionskips;
        print {$RESULTSXML} qq|            <assertionskips>true</assertionskips>\n|;
        print {$RESULTSXML} qq|            <assertionskips-message>$assertionskipsmessage</assertionskips-message>\n|;
    }

    if (($case{commandonerror}) && ($isfailure > 0)) { ## if the test case failed, check if we want to run a command to help sort out any problems
        commandonerror();
    }

    return;
}

#------------------------------------------------------------------
sub parseresponse {  #parse values from responses for use in future request (for session id's, dynamic URL rewriting, etc)

    my ($resptoparse, @parseargs);
    my ($leftboundary, $rightboundary, $escape);

    foreach my $testAttrib ( sort keys %{ $xmltestcases->{case}->{$testnum} } ) {

        if ( substr($testAttrib, 0, 13) eq "parseresponse" ) {

            @parseargs = split(/\|/, $case{$testAttrib});

            $leftboundary = $parseargs[0]; $rightboundary = $parseargs[1]; $escape = $parseargs[2];

            $resptoparse = $response->as_string;

            $parsedresult{$testAttrib} = undef; ## clear out any old value first

            if ($rightboundary eq 'regex') {## custom regex feature
                if ($resptoparse =~ m~$leftboundary~s) {
                    $parsedresult{$testAttrib} = $1;
                }
            } else {
                if ($resptoparse =~ m~$leftboundary(.*?)$rightboundary~s) {
                    $parsedresult{$testAttrib} = $1;
                }
            }

            if ($escape) {
                if ($escape eq 'escape') {
                    $parsedresult{$testAttrib} = url_escape($parsedresult{$testAttrib});
                }
            }

            ## decode html entities - e.g. convert &amp; to & and &lt; to <
            if ($escape) {
                if ($escape eq 'decode') {
                    $parsedresult{$testAttrib} = decode_entities($parsedresult{$testAttrib});
                }
            }

            #print "\n\nParsed String: $parsedresult{$_}\n\n";
        }
    }

    return;
}

#------------------------------------------------------------------
sub processcasefile {  #get test case files to run (from command line or config file) and evaluate constants
                       #parse config file and grab values it sets

    my @configfile;
    my $comment_mode;
    my $firstparse;
    my $filename;
    my $xpath;
    my $setuseragent;
    my $CONFIG;
    my $configfilepath;

    undef @casefilelist; #empty the array of test case filenames
    undef @configfile;

    #process the config file
    if ($opt_configfile) {  #if -c option was set on command line, use specified config file
        $configfilepath = "$dirname"."$opt_configfile";
    }
    elsif (-e "$dirname"."config.xml") {  #if config.xml exists, read it
        $configfilepath = "$dirname".'config.xml';
        $opt_configfile = "config.xml"; ## we have defaulted to config.xml in the current folder
    }

    if (-e "$configfilepath") {  #if we have a config file, use it

        ## read the XML config into an array for parsing using regex (WebInject 1.41 method)
        open( $CONFIG, '<', "$configfilepath" ) or die "\nERROR: Failed to open $configfilepath \n\n";
        my @precomment = <$CONFIG>;  #read the config file into an array
        close( $CONFIG );

        $userconfig = XMLin("$configfilepath"); ## Parse as XML for the user defined config

        #remove any commented blocks from config file
         foreach (@precomment) {
            unless (m~<comment>.*</comment>~) {  #single line comment
                #multi-line comments
                if (/<comment>/) {
                    $comment_mode = 1;
                }
                elsif (m~</comment>~) {
                    $comment_mode = 0;
                }
                elsif (!$comment_mode) {
                    push(@configfile, $_);
                }
            }
        }
    }

    if (($#ARGV + 1) < 1) {  #no command line args were passed
        #if testcase filename is not passed on the command line, use files in config.xml
        #parse test case file names from config.xml and build array
        foreach (@configfile) {

            if (/<testcasefile>/) {
                $firstparse = $';  #print "$' \n\n"; ## " doublequote for text editor display fix
                $firstparse =~ m~</testcasefile>~;
                $filename = $`;  #string between tags will be in $filename
                #print "\n$filename \n\n";
                push @casefilelist, $filename;  #add next filename we grab to end of array
            }
        }

        unless ($casefilelist[0]) {
            if (-e "$dirname".'testcases.xml') {
                #not appending a $dirname here since we append one when we open the file
                push @casefilelist, "testcases.xml";  #if no files are specified in config.xml, default to testcases.xml
            }
            else {
                die "\nERROR: I can't find any test case files to run.\nYou must either use a config file or pass a filename " .
                    "on the command line if you are not using the default testcase file (testcases.xml).\n";
            }
        }
    }

    elsif (($#ARGV + 1) == 1) {  #one command line arg was passed
        #use testcase filename passed on command line (config.xml is only used for other options)
        push @casefilelist, $ARGV[0];  #first commandline argument is the test case file, put this on the array for processing
    }

    elsif (($#ARGV + 1) == 2) {  #two command line args were passed

        undef $xnode; #reset xnode
        undef $xpath; #reset xpath

        $xpath = $ARGV[1];

        if ($xpath =~ /\/(.*)\[/) {  #if the argument contains a "/" and "[", it is really an XPath
            $xpath =~ /(.*)\/(.*)\[(.*?)\]/;  #if it contains XPath info, just grab the file name
            $xnode = $3;  #grab the XPath Node value.. (from inside the "[]")
            #print "\nXPath Node is: $xnode \n";
        }
        else {
            print STDERR "\nSorry, $xpath is not in the XPath format I was expecting, I'm ignoring it...\n";
        }

        #use testcase filename passed on command line (config.xml is only used for other options)
        push @casefilelist, $ARGV[0];  #first command line argument is the test case file, put this on the array for processing
    }

    elsif (($#ARGV + 1) > 2) {  #too many command line args were passed
        die "\nERROR: Too many arguments\n\n";
    }

    #print "\ntestcase file list: @casefilelist\n\n";


    #grab values for constants in config file:
    foreach (@configfile) {
        for my $config_const (qw/baseurl baseurl1 baseurl2 proxy timeout
                globalretry globaljumpbacks testonly autocontrolleronly/) {
            if (/<$config_const>/) {
                $_ =~ m~<$config_const>(.*)</$config_const>~;
                $config{$config_const} = $1;
                #print "\n$_ : $config{$_} \n\n";
            }
        }

        if (/<useragent>/) {
            $_ =~ m~<useragent>(.*)</useragent>~;
            $setuseragent = $1;
            if ($setuseragent) { #http useragent that will show up in webserver logs
                $useragent->agent($setuseragent);
            }
            #print "\nuseragent : $setuseragent \n\n";
        }

        if (/<httpauth>/) {
                #each time we see an <httpauth>, we set @authentry to be the
                #array of values, then we use [] to get a reference to that array
                #and push that reference onto @httpauth.
        my @authentry;
            $_ =~ m~<httpauth>(.*)</httpauth>~;
            @authentry = split(/:/, $1);
            if ($#authentry != 4) {
                print STDERR "\nError: httpauth should have 5 fields delimited by colons\n\n";
            }
            else {
        push(@httpauth, [@authentry]);
        }
            #print "\nhttpauth : @httpauth \n\n";
        }

    }

    if (not defined $config{globaljumpbacks}) { ## default the globaljumpbacks if it isn't in the config file
        $config{globaljumpbacks} = 20;
    }

    if ($opt_ignoreretry) { ##
        $config{globalretry} = -1;
        $config{globaljumpbacks} = 0;
    }

    return;
}

#------------------------------------------------------------------
sub convtestcases {
    #here we do some pre-processing of the test case file and write it out to a temp file.
    #we convert certain chars so xml parser doesn't puke.

    my @xmltoconvert;

    open( my $XMLTOCONVERT, '<', "$dirname"."$currentcasefile" ) or die "\nError: Failed to open test case file\n\n";  #open file handle
    @xmltoconvert = <$XMLTOCONVERT>;  #read the file into an array
    close( $XMLTOCONVERT );

    $casecount = 0;

    foreach (@xmltoconvert){

        #convert escaped chars and certain reserved chars to temporary values that the parser can handle
        #these are converted back later in processing
        s/&/{AMPERSAND}/g;
        s/\\</{LESSTHAN}/g;

        #count cases while we are here
        if ($_ =~ /<case/) {  #count test cases based on '<case' tag
            $casecount++;
        }
    }

    open( my $CONVERTEDXML, '>', "$outputfolder"."$currentcasefilename".".$$".'.tmp' ) or die "\nERROR: Failed to open temp file for writing\n\n";  #open file handle to temp file
    print $CONVERTEDXML @xmltoconvert;  #overwrite file with converted array
    close( $CONVERTEDXML );

    return;
}

#------------------------------------------------------------------
sub fixsinglecase{ #xml parser creates a hash in a different format if there is only a single testcase.
                   #add a dummy testcase to fix this situation

    my @xmltoconvert;

    if ($casecount == 1) {

        open( my$ XMLTOCONVERT, '<', "$outputfolder"."$currentcasefilename".".$$".'.tmp' ) or die "\nError: Failed to open temp file\n\n";  #open file handle
        @xmltoconvert = <$XMLTOCONVERT>;  #read the file into an array

        for(@xmltoconvert) {
            s/<\/testcases>/<case id="2" description1="dummy test case"\/><\/testcases>/g;  #add dummy test case to end of file
        }
        close( $XMLTOCONVERT );

        open( my $CONVERTEDXML, '>', "$outputfolder"."$currentcasefilename".".$$".'.tmp') or die "\nERROR: Failed to open temp file for writing\n\n";  #open file handle
        print $CONVERTEDXML @xmltoconvert;  #overwrite file with converted array
        close( $CONVERTEDXML );
    }

    return;
}

#------------------------------------------------------------------
## no critic (RequireArgUnpacking)
sub convertbackxml() {  #converts replaced xml with substitutions


## length feature for returning the size of the response
    my $mylength;
    if (defined $response) {#It will not be defined for the first test
        $mylength = length($response->as_string);
    }

    $_[0] =~ s~{JUMPBACKS}~$jumpbacks~g; #Number of times we have jumped back due to failure

## hostname, testnum, concurrency, teststeptime
    $_[0] =~ s~{HOSTNAME}~$hostname~g; #of the computer currently running webinject
    $_[0] =~ s~{TESTNUM}~$testnumlog~g;
    $_[0] =~ s~{TESTFILENAME}~$testfilename~g;
    $_[0] =~ s~{LENGTH}~$mylength~g; #length of the previous test step response
    $_[0] =~ s~{AMPERSAND}~&~g;
    $_[0] =~ s~{LESSTHAN}~<~g;
    $_[0] =~ s~{SINGLEQUOTE}~'~g; #'
    $_[0] =~ s~{TIMESTAMP}~$timestamp~g;
    $_[0] =~ s~{STARTTIME}~$starttime~g;
    $_[0] =~ s~{OPT_PROXYRULES}~$opt_proxyrules~g;
    $_[0] =~ s~{OPT_PROXY}~$opt_proxy~g;

    $_[0] =~ m~{TESTSTEPTIME:(\d+)}~s;
    if ($1)
    {
     $_[0] =~ s~{TESTSTEPTIME:(\d+)}~$teststeptime{$1}~g; #latency for test step number; example usage: {TESTSTEPTIME:5012}
    }

## day month year constant support #+{DAY}.{MONTH}.{YEAR}+{HH}:{MM}:{SS}+ - when execution started
    $_[0] =~ s~{DAY}~$DAYOFMONTH~g;
    $_[0] =~ s~{MONTH}~$MONTHS[$MONTH]~g;
    $_[0] =~ s~{YEAR}~$YEAR~g; #4 digit year
    $_[0] =~ s~{YY}~$YY~g; #2 digit year
    $_[0] =~ s~{HH}~$HOUR~g;
    $_[0] =~ s~{MM}~$MINUTE~g;
    $_[0] =~ s~{SS}~$SECOND~g;
    $_[0] =~ s~{WEEKOFMONTH}~$WEEKOFMONTH~g;
    $_[0] =~ s~{DATETIME}~$YEAR$MONTHS[$MONTH]$DAYOFMONTH$HOUR$MINUTE$SECOND~g;
    my $underscore = "_";
    $_[0] =~ s~{FORMATDATETIME}~$DAYOFMONTH\/$MONTHS[$MONTH]\/$YEAR$underscore$HOUR:$MINUTE:$SECOND~g;
    $_[0] =~ s~{COUNTER}~$counter~g;
    $_[0] =~ s~{CONCURRENCY}~$concurrency~g; #name of the temporary folder being used - not full path
    $_[0] =~ s~{OUTPUT}~$output~g;
    $_[0] =~ s~{OUTSUM}~$outsum~g;
## CWD Current Working Directory
    $_[0] =~ s~{CWD}~$cwd~g;

## parsedresults moved before config so you can have a parsedresult of {BASEURL2} say that in turn gets turned into the actual value

    ##substitute all the parsed results back
    ##parseresponse = {}, parseresponse5 = {5}, parseresponseMYVAR = {MYVAR}
    foreach my $testAttrib ( sort keys %{parsedresult} ) {
       my $parseVAR = substr($testAttrib, 13);
       $_[0] =~ s~{$parseVAR}~$parsedresult{$testAttrib}~g;
    }

    $_[0] =~ s~{BASEURL}~$config{baseurl}~g;
    $_[0] =~ s~{BASEURL1}~$config{baseurl1}~g;
    $_[0] =~ s~{BASEURL2}~$config{baseurl2}~g;

## perform arbirtary user defined config substituions
    my ($value, $KEY);
    foreach my $key (keys %{ $userconfig->{userdefined} } ) {
        $value = $userconfig->{userdefined}{$key};
        if (ref($value) eq 'HASH') { ## if we found a HASH, we treat it as blank
            $value = '';
        }
        $KEY = uc $key; ## convert to uppercase
        $_[0] =~ s~{$KEY}~$value~g;
    }

    return;
}

#------------------------------------------------------------------
sub convertbackxmldynamic() {## some values need to be updated after each retry

    my $retriessub = $retries-1;

    my $elapsedseconds = int(time() - $starttime) + 1; ## elapsed time rounded to seconds - increased to the next whole number
    my $elapsedminutes = int($elapsedseconds / 60) + 1; ## elapsed time rounded to seconds - increased to the next whole number

    $_[0] =~ s~{RETRY}~$retriessub~g;
    $_[0] =~ s~{ELAPSED_SECONDS}~$elapsedseconds~g; ## always rounded up
    $_[0] =~ s~{ELAPSED_MINUTES}~$elapsedminutes~g; ## always rounded up

    ## put the current date and time into variables
    my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
    my $year = 1900 + $yearOffset;
    my @months = qw(01 02 03 04 05 06 07 08 09 10 11 12);
    $month = $months[$month];
    my $day = sprintf("%02d", $dayOfMonth);
    $hour = sprintf("%02d", $hour); #put in up to 2 leading zeros
    $minute = sprintf("%02d", $minute);
    $second = sprintf("%02d", $second);

    my $underscore = "_";
    $_[0] =~ s~{NOW}~$day\/$month\/$year$underscore$hour:$minute:$second~g;

    return;
}

#------------------------------------------------------------------
sub convertback_variables() { ## e.g. postbody="time={RUNSTART}"
    foreach my $testAttrib ( sort keys %{varvar} ) {
       my $subVAR = substr($testAttrib, 3);
       $_[0] =~ s~{$subVAR}~$varvar{$testAttrib}~g;
    }

    return;
}

## use critic
#------------------------------------------------------------------
sub set_variables() { ## e.g. varRUNSTART="{HH}{MM}{SS}"
    foreach my $testAttrib ( sort keys %{ $xmltestcases->{case}->{$testnum} } ) {
       if ( substr($testAttrib, 0, 3) eq "var" ) {
            $varvar{$testAttrib} = $case{$testAttrib}; ## assign the variable
        }
    }

    return;
}

#------------------------------------------------------------------
sub url_escape {  #escapes difficult characters with %hexvalue
    #LWP handles url encoding already, but use this to escape valid chars that LWP won't convert (like +)

    my @a = @_;  #make a copy of the arguments

## escape change - changed the mapping around so / would be escaped
    map { s/[^-\w.,!~'()\/ ]/sprintf "%%%02x", ord $&/eg } @a;  ## no critic ## changed escape to prevent problems with __VIEWSTATE #'
#   map { s¦[-,^+!~()\\/' ]¦sprintf "%%%02x", ord $&¦eg } @a; #(1.41 version of escape)
    return wantarray ? @a : $a[0];
}

#------------------------------------------------------------------
sub httplog {  #write requests and responses to http.log file

    ## show a single space instead of %20 in the http.log
    my $textrequest = '';
    my $formatresponse = '';
    $textrequest = $request->as_string;
    $textrequest =~ s|%20| |g; #Replace %20 with a single space for clarity in the log file
    #print "http request ---- ", $textrequest, "\n\n";

## log separator enhancement
## from version 1.42 log separator is now written before each test case along with case number and test description
    print {$HTTPLOGFILE} "\n************************* LOG SEPARATOR *************************\n\n\n";
    print {$HTTPLOGFILE} "       Test: $currentcasefile - $testnumlog$jumpbacksprint$retriesprint \n";
    ## log descrption1 and description2
    print {$HTTPLOGFILE} "<desc1>$desc1log</desc1>\n";
    if ($desc2log) {
       print {$HTTPLOGFILE} "<desc2>$desc2log</desc2>\n";
    }

    print {$HTTPLOGFILE} "\n";
    for (qw/searchimage searchimage1 searchimage2 searchimage3 searchimage4 searchimage5/) {
        if ($case{$_}) {
            print {$HTTPLOGFILE} "<searchimage>$case{$_}</searchimage>\n";
        }
    }
    print {$HTTPLOGFILE} "\n";

    if ($case{logastext} || $case{command} || $case{command1} || $case{command2} || $case{command3} || $case{command4} || $case{command5} || $case{command6} || $case{command7} || $case{command8} || $case{command9} || $case{command10} || $case{command11} || $case{command12} || $case{command13} || $case{command14} || $case{command15} || $case{command16} || $case{command17} || $case{command18} || $case{command19} || $case{command20} || !$entrycriteriaok) { #Always log as text when a selenium command is present, or entry criteria not met
        print {$HTTPLOGFILE} "<logastext> \n";
    }
    print {$HTTPLOGFILE} "\n\n";

    if ($case{formatxml}) {
         ## makes an xml response easier to read by putting in a few carriage returns
         $formatresponse = $response->as_string; ## get the response output
         ## put in carriage returns
         $formatresponse =~ s~\>\<~\>\x0D\n\<~g; ## insert a CR between every ><
         $response = HTTP::Response->parse($formatresponse); ## inject it back into the response
    }

    if ($case{formatjson}) {
         ## makes a JSON response easier to read by putting in a few carriage returns
         $formatresponse = $response->as_string; #get the response out
         ## put in carriage returns
         $formatresponse =~ s~",~",\x0D\n~g;    ## insert a CR after  every ",
         $formatresponse =~ s~\},~\},\x0D\n~g;  ## insert a CR after  every },
         $formatresponse =~ s~\["~\x0D\n\["~g;  ## insert a CR before every ["
         $formatresponse =~ s~\\n\\tat~\x0D\n\\tat~g;  ## make java exceptions inside JSON readable - when \n\tat is seen, eat the \n and put \ CR before the \tat
         $response = HTTP::Response->parse($formatresponse); ## inject it back into the response
    }

    if ($case{logresponseasfile}) {  #Save the http response to a file - e.g. for file downloading, css
        my $responsefoldername = dirname($output."dummy"); ## output folder supplied by command line might include a filename prefix that needs to be discarded, dummy text needed due to behaviour of dirname function
        open( my $RESPONSEASFILE, '>', "$responsefoldername/$case{logresponseasfile}" );  #open in clobber mode
        binmode $RESPONSEASFILE; ## set binary mode
        print $RESPONSEASFILE $response->content, ""; #content just outputs the content, whereas as_string includes the response header
        close( $RESPONSEASFILE );
    }

    print {$HTTPLOGFILE} $textrequest, "\n\n";
    print {$HTTPLOGFILE} $response->as_string, "\n\n";

    if ($case{logastext} || $case{command} || $case{command1} || $case{command2} || $case{command3} || $case{command4} || $case{command5} || $case{command6} || $case{command7} || $case{command8} || $case{command9} || $case{command10} || $case{command11} || $case{command12} || $case{command13} || $case{command14} || $case{command15} || $case{command16} || $case{command17} || $case{command18} || $case{command19} || $case{command20} || !$entrycriteriaok) { #Always log as text when a selenium command is present, or entry criteria not met
        print {$HTTPLOGFILE} "</logastext> \n";
    }

    return;
}

#------------------------------------------------------------------
sub finaltasks {  #do ending tasks

    writefinalhtml();  #write summary and closing tags for results file

    unless ($xnode) { #skip regular STDOUT output if using an XPath
        writefinalstdout();  #write summary and closing tags for STDOUT
    }

    writefinalxml();  #write summary and closing tags for XML results file

    print {$HTTPLOGFILE} "\n************************* LOG SEPARATOR *************************\n\n\n";
    close( $HTTPLOGFILE );
    close( $RESULTS );
    close( $RESULTSXML );

    return;
}

#------------------------------------------------------------------
sub whackoldfiles {  #delete any files leftover from previous run if they exist

    ## delete tmp files in the output folder
    if (glob("$outputfolder"."*.xml.*.tmp")) { unlink glob("$output"."*.xml.*.tmp"); }

    return;
}

#------------------------------------------------------------------
sub startseleniumbrowser {     ## start Selenium Remote Control browser if applicable
    if ($opt_port) ## if -p is used, we need to start up a selenium server
    {
        if (defined $sel) { #shut down any existing selenium browser session
            $selresp = $sel->quit();
            sleep( 2.1 ); ## Sleep for 2.1 seconds, give system a chance to settle before starting new browser
        }
        print {*STDOUT} "\nStarting Selenium Remote Control server on port $opt_port \n";

        ## connecting to the Selenium server is done in a retry loop in case of slow startup
        ## see http://www.perlmonks.org/?node_id=355817
        my $max = 30;
        my $try = 0;

        ## --load-extension Loads an extension from the specified directory
        ## --whitelisted-extension-id
        ## http://rdekleijn.nl/functional-test-automation-over-a-proxy/
        ## http://bmp.lightbody.net/
        ATTEMPT:
        {
            eval
            {

                ## Phantomjs
                if ($opt_driver eq "phantomjs") {
                    $sel = Selenium::Remote::Driver->new('remote_server_addr' => 'localhost',
                                                        'port' => $opt_port,
                                                        'browser_name' => 'phantomjs',
                                                        );
                }

                ## Firefox
                if ($opt_driver eq "firefox") {
                    print {*STDOUT} qq|opt_proxy $opt_proxy\n|;
                    $sel = Selenium::Remote::Driver->new('remote_server_addr' => 'localhost',
                                                        'port' => $opt_port,
                                                        'browser_name' => 'firefox',
                                                        'proxy' => {'proxyType' => 'manual', 'httpProxy' => $opt_proxy, 'sslProxy' => $opt_proxy },
                                                        );
                 }

                ## Chrome
                if ($opt_driver eq "chrome") {
                    print {*STDOUT} qq|opt_proxy $opt_proxy\n|;
                    $sel = Selenium::Remote::Driver->new('remote_server_addr' => 'localhost',
                                                        'port' => $opt_port,
                                                        'browser_name' => 'chrome',
                                                        'proxy' => {'proxyType' => 'manual', 'httpProxy' => $opt_proxy, 'sslProxy' => $opt_proxy },
                                                        'extra_capabilities' => {'chromeOptions' => {'args' => ['window-size=1260,968']}}
                                                        );
                 }

                                                       #'extra_capabilities' => {'chrome.switches' => ['--proxy-server="http://127.0.0.1:$opt_proxy" --incognito --window-size=1260,460'],},
                                                       #'extra_capabilities' => {'chrome.switches' => ['--incognito --window-size=1260,960']}
                                                       #'extra_capabilities' => {'chromeOptions' => {'args' => ['incognito','window-size=1260,960']}}

                                                       #'extra_capabilities'
                                                       #   => {'chromeOptions' => {'args'  =>         ['window-size=1260,960','incognito'],
                                                       #                           'prefs' => {'session' => {'restore_on_startup' =>4, 'urls_to_restore_on_startup' => ['http://www.google.com','http://www.example.com']},
                                                       #                                       'first_run_tabs' => ['http://www.mywebsite.com','http://www.google.de']
                                                       #                                      }
                                                       #                          }
                                                       #      }

            }; ## end eval

            if ( $@ and $try++ < $max )
            {
                print "\nError: $@ Failed try $try to connect to Selenium Server on port $opt_port, retrying...\n";
                sleep( 4 ); ## sleep for 4 seconds, Selenium Server may still be starting up
                redo ATTEMPT;
            }
        } ## end ATTEMPT

        if ($@)
            {
                print "\nError: $@ Failed to connect on port $opt_port after $max tries\n\n";
                die "WebInject Aborted - could not connect to Selenium Server\n";
            }

        ## this block finds out the Windows window handle of the chrome window so that we can do a very fast screenshot (as opposed to full page grab which is slow)
        my $thetime = time();
        $sel->get("http://127.0.0.1:87/?windowidentify_$thetime-time"); ## we put the current time stamp in the window title, so this is multi-thread safe
        #Set timeout as 5 seconds (was 140)
        $sel->set_timeout(5000);
        my $allchromehandle = (`GetWindows.exe`); ## this is a separate simple .NET C# program that lists all open windows and what their title is
        #print {*STDOUT} qq|$allchromehandle\n|;
        $allchromehandle =~ m~(\d+), http:..127.0.0.1:87..windowidentify_$thetime~s;
        if ($1)
        {
            $chromehandle = $1;
        }
        else
        {
            $chromehandle = 0;
        }
        print {*STDOUT} qq|CHROME HANDLE THIS SESSION\n$chromehandle\n|;

        #$sel->set_implicit_wait_timeout(10); ## wait specified number of seconds before failing - but proceed immediately if possible
        $sel->set_window_size(968, 1260); ## y,x
    }

    return;
}

#------------------------------------------------------------------
sub startsession {     ## creates the webinject user agent
    #contsruct objects
    ## Authen::NTLM change allows ntlm authentication
    #$useragent = LWP::UserAgent->new; ## 1.41 version
    $useragent = LWP::UserAgent->new(keep_alive=>1);
    $cookie_jar = HTTP::Cookies->new;
    $useragent->agent('WebInject');  ## http useragent that will show up in webserver logs
    #$useragent->timeout(200); ## it is possible to override the default timeout of 360 seconds
    $useragent->max_redirect('0');  #don't follow redirects for GET's (POST's already don't follow, by default)
    eval
    {
       $useragent->ssl_opts(verify_hostname=>0); ## stop SSL Certs from being validated - only works on newer versions of of LWP so in an eval
       $useragent->ssl_opts(SSL_verify_mode=>SSL_VERIFY_NONE); ## from Perl 5.16.3 need this to prevent ugly warnings
    };

    return;
}

#------------------------------------------------------------------
sub getdirname {  #get the directory webinject engine is running from

    $dirname = $0;
    $dirname =~ s{(.*/).*}{$1};  #for nix systems
    $dirname =~ s{(.*\\).*}{$1}; #for windoz systems
    if ($dirname eq $0) {
        $dirname = q{./};
    }

    return;
}
#------------------------------------------------------------------
sub getoptions {  #shell options

    Getopt::Long::Configure('bundling');
    GetOptions(
        'v|V|version'   => \$opt_version,
        'c|config=s'    => \$opt_configfile,
        'o|output=s'    => \$opt_output,
        'a|autocontroller'    => \$opt_autocontroller,
        'p|port=s'    => \$opt_port,
        'x|proxy=s'   => \$opt_proxy,
        'b|basefolder=s'   => \$opt_basefolder,
        'd|driver=s'   => \$opt_driver,
        'r|proxyrules=s'   => \$opt_proxyrules,
        'i|ignoreretry'   => \$opt_ignoreretry,
        'h|help'   => \$opt_help,
        )
        or do {
            print_usage();
            exit;
        };

    if ($opt_version) {
        print_version();
        exit;
    }

    if ($opt_help) {
        print_version();
        print_usage();
        exit;
    }

    if ($opt_output) {  #use output location if it is passed from the command line
        $output = $opt_output;
    }
    else {
        $output = $dirname.'output/'; ## default to the output folder under the current folder
    }
    $outputfolder = dirname($output.'dummy'); ## output folder supplied by command line might include a filename prefix that needs to be discarded, dummy text needed due to behaviour of dirname function

    return;
}

sub print_version {
    print "\nWebInject version $VERSION\nFor more info: https://github.com/Qarj/WebInject\n\n";

    return;
}

sub print_usage {
        print <<'EOB'
Usage: webinject.pl <<options>>

-c|--config config_file                             -c config.xml
-o|--output output_location                         -o output/
-A|--autocontroller                                 -a
-p|--port selenium_port                             -p 8325
-x|--proxy proxy_server                             -x localhost:9222
-b|--basefolder baselined image folder              -b examples/basefoler/
testcase_file [XPath]                               examples/simple.xml testcases/case[20]
-d|--driver chromedriver OR phantomjs OR firefox    -d chromedriver
-r|--proxyrules                                     -r true
-i|--ignoreretry                                    -i

or

webinject.pl --version|-v
webinject.pl --help|-h
EOB
    ;

    return;
}
#------------------------------------------------------------------

## References
##
## http://www.kichwa.com/quik_ref/spec_variables.html