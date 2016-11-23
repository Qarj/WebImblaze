#!/usr/bin/perl

# $Id$
# $Revision$
# $Date$

use strict;
use warnings;
use vars qw/ $VERSION /;

$VERSION = '2.4.1';

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

use File::Basename;
use File::Spec;
use File::Slurp;
use LWP;
use HTTP::Request::Common;
use XML::Simple;
use Time::HiRes 'time','sleep';
use Getopt::Long;
local $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 'false';
use Socket qw( PF_INET SOCK_STREAM INADDR_ANY sockaddr_in );
use File::Copy qw(copy), qw(move);
use File::Path qw(make_path remove_tree);

local $| = 1; #don't buffer output to STDOUT

## Variable declarations
my ($timestamp, $testfilename);
my (%parsedresult);
my (%varvar);
my ($useragent, $request, $response);
my ($latency, $verification_latency, $screenshot_latency);
my (%test_step_time); ## record in a hash the latency for every step for later use
my ($cookie_jar, @http_auth);
my ($run_count, $total_run_count, $case_passed_count, $case_failed_count, $passed_count, $failed_count);
my ($total_response, $avg_response, $max_response, $min_response);
my ($current_case_file, $current_case_filename, $case_count, $is_failure, $fast_fail_invoked);
my (%case, %case_save);
my (%config);
my ($current_date_time, $total_run_time, $start_timer, $end_timer);
my ($opt_configfile, $opt_version, $opt_output, $opt_autocontroller, $opt_port, $opt_proxy);
my ($opt_driver, $opt_ignoreretry, $opt_no_output, $opt_verbose, $opt_help, $opt_chromedriver_binary, $opt_selenium_binary, $opt_publish_full);
my ($selenium_port);

my ($report_type); ## 'standard' and 'nagios' supported
my ($return_message); ## error message to return to nagios
my ($testnum, $xml_test_cases, $step_index, @test_steps);
my ($testnum_display, $previous_test_step, $delayed_file_full, $delayed_html); ## individual step file html logging
my ($retry, $retries, $globalretries, $retry_passed_count, $retry_failed_count, $retries_print, $jumpbacks, $jumpbacks_print); ## retry failed tests
my ($sanity_result); ## if a sanity check fails, execution will stop (as soon as all retries are exhausted on the current test case)
my ($start_time); ## to store a copy of $start_run_timer in a global variable
my ($output, $output_folder, $output_prefix); ## output path including possible filename prefix, output path without filename prefix, output prefix only
my ($outsum); ## outsum is a checksum calculated on the output directory name. Used to help guarantee test data uniqueness where two WebInject processes are running in parallel.
my ($user_config); ## support arbirtary user defined config
my ($convert_back_ports, $convert_back_ports_null); ## turn {:4040} into :4040 or null
my $total_assertion_skips = 0;
my (@visited_pages); ## page source of previously visited pages
my (@visited_page_names); ## page name of previously visited pages
my (@page_update_times); ## last time the page was updated in the cache
my $assertion_skips = 0;
my $assertion_skips_message = q{}; ## support tagging an assertion as disabled with a message
my (@hrefs, @srcs, @bg_images); ## keep an array of all grabbed assets to substitute them into the step results html (for results visualisation)
my $session_started; ## only start up http sesion if http is being used
my ($selresp, $driver); ## support for Selenium WebDriver test cases
my ($testfile_contains_selenium); ## so we know if Selenium Browser Session needs to be started

## put the current date and time into variables - startdatetime - for recording the start time in a format an xsl stylesheet can process
my @MONTHS = qw(01 02 03 04 05 06 07 08 09 10 11 12);
my @MONTHS_TEXT = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my @WEEKDAYS = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
my ($SECOND, $MINUTE, $HOUR, $DAYOFMONTH, $MONTH, $YEAROFFSET, $DAYOFWEEK, $DAYOFYEAR, $DAYLIGHTSAVINGS) = localtime;
my $YEAR = 1900 + $YEAROFFSET;
my $YY = substr $YEAR, 2; #year as 2 digits
my $MONTH_TEXT = $MONTHS_TEXT[$MONTH];
$DAYOFMONTH = sprintf '%02d', $DAYOFMONTH;
my $WEEKOFMONTH = int(($DAYOFMONTH-1)/7)+1;
my $STARTDATE = "$YEAR-$MONTHS[$MONTH]-$DAYOFMONTH";
$MINUTE = sprintf '%02d', $MINUTE; #put in up to 2 leading zeros
$SECOND = sprintf '%02d', $SECOND;
$HOUR = sprintf '%02d', $HOUR;
my $TIMESECONDS = ($HOUR * 60 * 60) + ($MINUTE * 60) + $SECOND;
$current_date_time = "$WEEKDAYS[$DAYOFWEEK] $DAYOFMONTH $MONTH_TEXT $YEAR, $HOUR:$MINUTE:$SECOND";

my $this_script_folder_full = dirname(__FILE__);
chdir $this_script_folder_full;

my $counter = 0; ## keeping track of the loop we are up to

my $concurrency = 'null'; ## current working directory - not full path
my $png_base64; ## Selenium full page grab screenshot

my ( $results_stdout, $results_html, $results_xml, $results_xml_file_name );
my ($start_run_timer, $end_run_timer, $repeat, $start);

my $hostname = `hostname`; ##no critic(ProhibitBacktickOperators) ## hostname should work on Linux and Windows
$hostname =~ s/\r|\n//g; ## strip out any rogue linefeeds or carriage returns

my $is_windows = $^O eq 'MSWin32' ? 1 : 0;

## Startup
get_options();  #get command line options
process_config_file();
write_initial_stdout();  #write opening tags for STDOUT.

_whack($opt_publish_full.'http.txt');
_whack($opt_publish_full.'results.html');

write_initial_xml();
write_initial_html();  #write opening tags for results file

$total_run_count = 0;
$case_passed_count = 0;
$case_failed_count = 0;
$passed_count = 0;
$failed_count = 0;
$total_response = 0;
$avg_response = 0;
$max_response = 0;
$min_response = 10_000_000; #set to large value so first minresponse will be less

$globalretries=0; ## total number of retries for this run across all test cases

$start_run_timer = time;  #timer for entire test run
$start_time = $start_run_timer; ## need a global variable to make a copy of the start run timer

$current_case_filename = basename($current_case_file); ## with extension
$testfilename = fileparse($current_case_file, '.xml'); ## without extension

read_test_case_file();
#start_session(); #starts, or restarts the webinject session - now started immediately before executing the test step if needed

$repeat = $xml_test_cases->{repeat};  #grab the number of times to iterate test case file
if (!$repeat) { $repeat = 1; }  #set to 1 in case it is not defined in test case file

$start = $xml_test_cases->{start};  #grab the start for repeating (for restart)
if (!$start) { $start = 1; }  #set to 1 in case it is not defined in test case file

$counter = $start - 1; #so starting position and counter are aligned

$results_stdout .= "-------------------------------------------------------\n";

## Repeat Loop
foreach ($start .. $repeat) {

    $counter = $counter + 1;
    $run_count = 0;
    $jumpbacks_print = q{}; ## we do not indicate a jump back until we actually jump back
    $jumpbacks = 0;

    @test_steps = sort {$a<=>$b} keys %{$xml_test_cases->{case}};
    my $numsteps = scalar @test_steps;

    ## Loop over each of the test cases (test steps) with C Style for loop (due to need to update $step_index in a non standard fashion)
    TESTCASE:   for ($step_index = 0; $step_index < $numsteps; $step_index++) {  ## no critic(ProhibitCStyleForLoops)

        $testnum = $test_steps[$step_index];

        $testnum_display = get_testnum_display($testnum, $counter);

        $is_failure = 0;
        $retries = 1; ## we increment retries after writing to the log
        $retries_print = q{}; ## the printable value is used before writing the results to the log, so it is one behind, 0 being printed as null

        my $skip_message = get_test_step_skip_message();
        if ( $skip_message ) {
            $results_stdout .= "Skipping Test Case $testnum... ($skip_message)\n";
            $results_stdout .= qq|------------------------------------------------------- \n|;
            next TESTCASE; ## skip running this test step
        }

        # populate variables with values from testcase file, do substitutions, and revert converted values back
        substitute_variables();

        $retry = get_number_of_times_to_retry_this_test_step(); # 0 means do not retry this step

        do ## retry loop
        {
            substitute_retry_variables(); ## for each retry, there are a few substitutions that we need to redo - like the retry number
            set_var_variables(); ## finally set any variables after doing all the static and dynamic substitutions
            substitute_var_variables();

            set_retry_to_zero_if_global_limit_exceeded();

            $is_failure = 0;
            $fast_fail_invoked = 'false';
            $retry_passed_count = 0;
            $retry_failed_count = 0;

            if ($case{description1} and $case{description1} =~ /dummy test case/) {  ## if we hit the dummy record, skip it (this is a hack for test case files with only one step)
                next;
            }

            output_test_step_description();
            output_assertions();

            execute_test_step();
            display_request_response();

            decode_quoted_printable();

            verify(); #verify result from http response

            gethrefs(); ## get specified web page href assets
            getsrcs(); ## get specified web page src assets
            getbackgroundimages(); ## get specified web page src assets

            parseresponse();  #grab string from response to send later

            httplog();  #write to http.txt file

            pass_fail_or_retry();

            output_test_step_latency();
            output_test_step_results();

            increment_run_count();
            update_latency_statistics();

            restart_browser();

            sleep_before_next_step();

            $retry = $retry - 1;
        } ## end of retry loop
        until ($retry < 0); ## no critic(ProhibitNegativeExpressionsInUnlessAndUntilConditions])

        if ($case{sanitycheck} && ($case_failed_count > 0)) { ## if sanitycheck fails (i.e. we have had any error at all after retries exhausted), then execution is aborted
            $results_stdout .= qq|SANITY CHECK FAILED ... Aborting \n|;
            last;
        }
    } ## end of test case loop

    $testnum = 1;  #reset testcase counter so it will reprocess test case file if repeat is set
} ## end of repeat loop

$end_run_timer = time;
$total_run_time = (int(1000 * ($end_run_timer - $start_run_timer)) / 1000);  #elapsed time rounded to thousandths
$avg_response = (int(1000 * ($total_response / $total_run_count)) / 1000);  #avg response rounded to thousandths

final_tasks();  #do return/cleanup tasks

## shut down the Selenium session and Selenium Server last - it is less important than closing the files
shutdown_selenium();
shutdown_selenium_server($selenium_port);

my $status = $case_failed_count cmp 0;
exit $status;
## End main code

#------------------------------------------------------------------
#  SUBROUTINES
#------------------------------------------------------------------

sub display_request_response {

    if (not $opt_verbose) { return; }

    $results_stdout .= "\n\nREQUEST ===>\n".$request->as_string."\n<=== END REQUEST\n\n";
    $results_stdout .= "\n\nRESPONSE ===>\n".$response->as_string."\n<=== END RESPONSE\n\n";

    return;
}

sub get_testnum_display {
    my ($_testnum, $_counter) = @_;

    ## use $testnum_display for all testnum output, add 10,000 in case of repeat loop
    my $_testnum_display = $_testnum + ($_counter*10_000) - 10_000;
    $_testnum_display = sprintf '%.2f', $_testnum_display; ## maximul of 2 decimal places
    $_testnum_display =~ s/0+\z// if $_testnum_display =~ /[.]/; ## remove trailing non significant zeros
    if (not ($_testnum_display =~ s/[.]\z//) ) { ## remove decimal point if nothing after
        $_testnum_display = sprintf '%.2f', $_testnum_display; ## put back the non significant zero if we have a decimal point
    }

    return $_testnum_display;
}

#------------------------------------------------------------------
sub set_useragent {
    my ($_useragent) = @_;

    if (not $_useragent) { return; }

    $useragent->agent($_useragent);

    return;
}

#------------------------------------------------------------------
sub set_max_redirect {
    my ($_max_redirect) = @_;

    if (not $_max_redirect) { return; }

    $useragent->max_redirect($_max_redirect);

    return;
}

#------------------------------------------------------------------
sub get_test_step_skip_message {

    $case{runon} = $xml_test_cases->{case}->{$testnum}->{runon}; ## skip test cases not flagged for this environment
    if ($case{runon}) { ## is this test step conditional on the target environment?
        if ( _run_this_step($case{runon}) ) {
            ## run this test case as normal since it is allowed
        }
        else {
            return "run on $case{runon}";
        }
    }

    $case{donotrunon} = $xml_test_cases->{case}->{$testnum}->{donotrunon}; ## skip test cases flagged not to run on this environment
    if ($case{donotrunon}) { ## is this test step conditional on the target environment?
        if ( not _run_this_step($case{donotrunon}) ) {
            ## run this test case as normal since it is allowed
        }
        else {
            return "do not run on $case{donotrunon}";
        }
    }

    $case{autocontrolleronly} = $xml_test_cases->{case}->{$testnum}->{autocontrolleronly}; ## only run this test case on the automation controller, e.g. test case may involve a test virus which cannot be run on a regular corporate desktop
    if ($case{autocontrolleronly}) { ## is the autocontrolleronly value set for this testcase?
        if ($opt_autocontroller) { ## if so, was the auto controller option specified?
            ## run this test case as normal since it is allowed
        }
        else {
              return 'This is not the automation controller';
        }
    }

    $case{firstlooponly} = $xml_test_cases->{case}->{$testnum}->{firstlooponly}; ## only run this test case on the first loop
    if ($case{firstlooponly}) { ## is the firstlooponly value set for this testcase?
        if ($counter == 1) { ## counter keeps track of what loop number we are on
            ## run this test case as normal since it is the first pass
        }
        else {
              return 'firstlooponly';
        }
    }

    $case{lastlooponly} = $xml_test_cases->{case}->{$testnum}->{lastlooponly}; ## only run this test case on the last loop
    if ($case{lastlooponly}) { ## is the lastlooponly value set for this testcase?
        if ($counter == $repeat) { ## counter keeps track of what loop number we are on
            ## run this test case as normal since it is the first pass
        }
        else {
              return 'lastlooponly';
        }
    }

    return;
}

#------------------------------------------------------------------
sub substitute_variables {

    ## "method", "description1", "description2", "url", "postbody", "posttype", "addheader", "command", "command1", ... "command20", "parms", "verifytext",
    ## "verifypositive", "verifypositive1", ... "verifypositive9999",
    ## "verifynegative", "verifynegative1", ... "verifynegative9999",
    ## "parseresponse", "parseresponse1", ... , "parseresponse40", ... , "parseresponse9999", "parseresponseORANYTHING", "verifyresponsecode",
    ## "verifyresponsetime", "sleep", "errormessage", "ignorehttpresponsecode", "ignoreautoassertions", "ignoresmartassertions",
    ## "retry", "sanitycheck", "logastext", "section", "assertcount", "searchimage", ... "searchimage5", "formatxml", "formatjson",
    ## "logresponseasfile", "addcookie", "restartbrowseronfail", "restartbrowser", "commandonerror", "gethrefs", "getsrcs", "getbackgroundimages",
    ## "firstlooponly", "lastlooponly", "decodequotedprintable"

    $timestamp = time;  #used to replace parsed {timestamp} with real timestamp value

    undef %case_save; ## we need a clean array for each test case
    undef %case; ## do not allow values from previous test cases to bleed over
    foreach my $_case_attribute ( keys %{ $xml_test_cases->{case}->{$testnum} } ) {
        #print "DEBUG: $_case_attribute", ": ", $xml_test_cases->{case}->{$testnum}->{$_case_attribute};
        #print "\n";
        $case{$_case_attribute} = $xml_test_cases->{case}->{$testnum}->{$_case_attribute};
        convert_back_xml($case{$_case_attribute});
        $case_save{$_case_attribute} = $case{$_case_attribute}; ## in case we have to retry, some parms need to be resubbed
    }

    return;
}

#------------------------------------------------------------------
sub get_number_of_times_to_retry_this_test_step {

    $case{retryfromstep} = $xml_test_cases->{case}->{$testnum}->{retryfromstep}; ## retry from a [previous] step
    if ($case{retryfromstep}) { ## retryfromstep parameter found
        return 0; ## we will not do a regular retry
    }

    my $_retry;
    $case{retry} = $xml_test_cases->{case}->{$testnum}->{retry}; ## optional retry of a failed test case
    if ($case{retry}) { ## retry parameter found
        $_retry = $case{retry}; ## assume we can retry as many times as specified
        if ($config{globalretry}) { ## ensure that the global retry limit won't be exceeded
            if ($_retry > ($config{globalretry} - $globalretries)) { ## we can't retry that many times
                $_retry =  $config{globalretry} - $globalretries; ## this is the most we can retry
                if ($_retry < 0) {
                    return 0; ## if less than 0 then make 0
                }
            }
        }
        $results_stdout .= qq|Retry $_retry times\n|;
        return $_retry;
    }
    else {
        return 0; #no retry parameter found, don't retry this case
    }

    return; ## impossible to execute this statement
}

#------------------------------------------------------------------
sub substitute_retry_variables {

    foreach my $_case_attribute ( keys %{ $xml_test_cases->{case}->{$testnum} } ) {
        if (defined $case_save{$_case_attribute}) ## defaulted parameters like posttype may not have a saved value on a subsequent loop
        {
            $case{$_case_attribute} = $case_save{$_case_attribute}; ## need to restore to the original partially substituted parameter
            convert_back_xml_dynamic($case{$_case_attribute}); ## now update the dynamic components
        }
    }

    return;
}

#------------------------------------------------------------------
sub set_retry_to_zero_if_global_limit_exceeded {

    if ($config{globalretry}) {
        if ($globalretries >= $config{globalretry}) {
            $retry = 0; ## globalretries value exceeded - not retrying any more this run
        }
    }

    return;
}

#------------------------------------------------------------------
sub output_test_step_description {

    $results_html .= qq|<b>Test:  $current_case_file - <a href="$output_prefix$testnum_display$jumpbacks_print$retries_print.html"> $testnum_display$jumpbacks_print$retries_print </a> </b><br />\n|;
    $results_stdout .= qq|Test:  $current_case_file - $testnum_display$jumpbacks_print$retries_print \n|;
    $results_xml .= qq|        <testcase id="$testnum_display$jumpbacks_print$retries_print">\n|;

    for (qw/section description1 description2/) { ## support section breaks
        next unless defined $case{$_};
        $results_html .= qq|$case{$_} <br />\n|;
        $results_stdout .= qq|$case{$_} \n|;
        $results_xml .= qq|            <$_>|._sub_xml_special($case{$_}).qq|</$_>\n|;
    }

    $results_html .= qq|<br />\n|;

    return;
}

#------------------------------------------------------------------
sub output_assertions {

    ## display and log the verifications to do to stdout and html - xml output is done with the verification itself
    ## verifypositive, verifypositive1, ..., verifypositive9999 (or even higher)
    ## verifynegative, verifynegative2, ..., verifynegative9999 (or even higher)
    foreach my $_case_attribute ( sort keys %{ $xml_test_cases->{case}->{$testnum} } ) {
        if ( (substr $_case_attribute, 0, 14) eq 'verifypositive' || (substr $_case_attribute, 0, 14) eq 'verifynegative') {
            my $_verifytype = substr $_case_attribute, 6, 8; ## so we get the word positive or negative
            $_verifytype = ucfirst $_verifytype; ## change to Positive or Negative
            my @_verifyparms = split /[|][|][|]/, $case{$_case_attribute} ; ## index 0 contains the actual string to verify
            $results_html .= qq|Verify $_verifytype: "$_verifyparms[0]" <br />\n|;
            $results_stdout .= qq|Verify $_verifytype: "$_verifyparms[0]" \n|;
        }
    }

    if ($case{verifyresponsecode}) {
        $results_html .= qq|Verify Response Code: "$case{verifyresponsecode}" <br />\n|;
        $results_stdout .= qq|Verify Response Code: "$case{verifyresponsecode}" \n|;
        $results_xml .= qq|            <verifyresponsecode>$case{verifyresponsecode}</verifyresponsecode>\n|;
    }

    if ($case{verifyresponsetime}) {
        $results_html .= qq|Verify Response Time: at most "$case{verifyresponsetime} seconds" <br />\n|;
        $results_stdout .= qq|Verify Response Time: at most "$case{verifyresponsetime}" seconds\n|;
        $results_xml .= qq|            <verifyresponsetime>$case{verifyresponsetime}</verifyresponsetime>\n|;
    }

    return;
}

#------------------------------------------------------------------
sub execute_test_step {

    if (not $opt_no_output) { print {*STDOUT} $results_stdout; }
    undef $results_stdout;

    if ($case{method}) {
        if ($case{method} eq 'cmd') { cmd(); return; }
    }

    if (not $session_started) {
        start_session();
    }

    if ($case{method}) {
        if ($case{method} eq 'selenium') { selenium(); return; }
    }

    set_useragent($xml_test_cases->{case}->{$testnum}->{useragent});
    set_max_redirect($xml_test_cases->{case}->{$testnum}->{maxredirect});

    if ($case{method}) {
        if ($case{method} eq 'get') { httpget(); return;}
        if ($case{method} eq 'post') { httppost(); return;}
        if ($case{method} eq 'delete') { httpdelete(); return;}
        if ($case{method} eq 'put') { httpput(); return;}
    }
    else {
        httpget();  #use "get" if no method is specified
    }

    return;
}

#------------------------------------------------------------------
sub pass_fail_or_retry {

    ## check max jumpbacks - globaljumpbacks - i.e. retryfromstep usages before we give up - otherwise we risk an infinite loop
    if ( (($is_failure > 0) && ($retry < 1) && !($case{retryfromstep})) || (($is_failure > 0) && ($case{retryfromstep}) && ($jumpbacks > ($config{globaljumpbacks}-1) )) || ($fast_fail_invoked eq 'true')) {
        ## if any verification fails, test case is considered a failure UNLESS there is at least one retry available, or it is a retryfromstep case
        ## however if a verifynegative fails then the case is always a failure
        $results_xml .= qq|            <success>false</success>\n|;
        if ($case{errormessage}) { #Add defined error message to the output
            $results_html .= qq|<b><span class="fail">TEST CASE FAILED : $case{errormessage}</span></b><br />\n|;
            $results_xml .= '            <result-message>'._sub_xml_special($case{errormessage})."</result-message>\n";
            $results_stdout .= qq|TEST CASE FAILED : $case{errormessage}\n|;
            if (not $return_message) {
                $return_message = $case{errormessage}; ## only return the first error message to nagios
            }
        }
        else { #print regular error output
            $results_html .= qq|<b><span class="fail">TEST CASE FAILED</span></b><br />\n|;
            $results_xml .= qq|            <result-message>TEST CASE FAILED</result-message>\n|;
            $results_stdout .= qq|TEST CASE FAILED\n|;
            if (not $return_message) {
                $return_message = "Test case number $testnum failed"; ## only return the first test case failure to nagios
            }
        }
        $case_failed_count++;
    }
    elsif (($is_failure > 0) && ($retry > 0)) {#Output message if we will retry the test case
        $results_html .= qq|<b><span class="pass">RETRYING... $retry to go</span></b><br />\n|;
        $results_stdout .= qq|RETRYING... $retry to go \n|;
        $results_xml .= qq|            <success>false</success>\n|;
        $results_xml .= qq|            <result-message>RETRYING... $retry to go</result-message>\n|;

        ## all this is for ensuring correct behaviour when retries occur
        $retries_print = ".$retries";
        $retries++;
        $globalretries++;
        $passed_count = $passed_count - $retry_passed_count;
        $failed_count = $failed_count - $retry_failed_count;
    }
    elsif (($is_failure > 0) && $case{retryfromstep}) {#Output message if we will retry the test case from step
        my $_jump_backs_left = $config{globaljumpbacks} - $jumpbacks;
        $results_html .= qq|<b><span class="pass">RETRYING FROM STEP $case{retryfromstep} ... $_jump_backs_left tries left</span></b><br />\n|;
        $results_stdout .= qq|RETRYING FROM STEP $case{retryfromstep} ...  $_jump_backs_left tries left\n|;
        $results_xml .= qq|            <success>false</success>\n|;
        $results_xml .= qq|            <result-message>RETRYING FROM STEP $case{retryfromstep} ...  $_jump_backs_left tries left</result-message>\n|;
        $jumpbacks++; ## increment number of times we have jumped back - i.e. used retryfromstep
        $jumpbacks_print = "-$jumpbacks";
        $globalretries++;
        $passed_count = $passed_count - $retry_passed_count;
        $failed_count = $failed_count - $retry_failed_count;

        ## find the index for the test step we are retrying from
        $step_index = 0;
        my $_found_index = 'false';
        foreach (@test_steps) {
            if ($test_steps[$step_index] eq $case{retryfromstep}) {
                $_found_index = 'true';
                last;
            }
            $step_index++
        }
        if ($_found_index eq 'false') {
            $results_stdout .= qq|ERROR - COULD NOT FIND STEP $case{retryfromstep} - TESTING STOPS \n|;
        }
        else
        {
            $step_index--; ## since we increment it at the start of the next loop / end of this loop
        }
    }
    else {
        $results_html .= qq|<b><span class="pass">TEST CASE PASSED</span></b><br />\n|;
        $results_stdout .= qq|TEST CASE PASSED \n|;
        $results_xml .= qq|            <success>true</success>\n|;
        $results_xml .= qq|            <result-message>TEST CASE PASSED</result-message>\n|;
        $case_passed_count++;
        $retry = 0; # no need to retry when test case passes
    }

    return;
}

#------------------------------------------------------------------
sub output_test_step_latency {

    $results_html .= qq|Response Time = $latency sec <br />\n|;
    $results_stdout .= qq|Response Time = $latency sec \n|;
    $results_xml .= qq|            <responsetime>$latency</responsetime>\n|;

    if ($case{method} eq 'selenium') {
        $results_html .= qq|Verification Time = $verification_latency sec <br />\n|;
        $results_html .= qq|Screenshot Time = $screenshot_latency sec <br />\n|;

        $results_stdout .= qq|Verification Time = $verification_latency sec \n|;
        $results_stdout .= qq|Screenshot Time = $screenshot_latency sec \n|;

        $results_xml .= qq|            <verificationtime>$verification_latency</verificationtime>\n|;
        $results_xml .= qq|            <screenshottime>$screenshot_latency</screenshottime>\n|;
    }

    return;
}

#------------------------------------------------------------------
sub output_test_step_results {

    $results_xml .= qq|        </testcase>\n\n|;
    _write_xml (\$results_xml);
    undef $results_xml;

    $results_html .= qq|<br />\n------------------------------------------------------- <br />\n\n|;
    _write_html (\$results_html);
    undef $results_html;

    $results_stdout .= qq|------------------------------------------------------- \n|;
    if (not $opt_no_output) { print {*STDOUT} $results_stdout; }
    undef $results_stdout;

    return;
}

#------------------------------------------------------------------
sub increment_run_count {

    if ( ( ($is_failure > 0) && ($retry > 0) && !($case{retryfromstep}) ) ||
         ( ($is_failure > 0) && $case{retryfromstep} && ($jumpbacks < $config{globaljumpbacks} ) && ($fast_fail_invoked eq 'false') )
       ) {
        ## do not count this in run count if we are retrying
    }
    else {
        $run_count++;
        $total_run_count++;
    }

    return;
}

#------------------------------------------------------------------
sub update_latency_statistics {

    if ($latency > $max_response) { $max_response = $latency; }  #set max response time
    if ($latency < $min_response) { $min_response = $latency; }  #set min response time
    $total_response = ($total_response + $latency);  #keep total of response times for calculating avg

    $test_step_time{$testnum_display}=$latency; ## store latency for step

    return;
}

#------------------------------------------------------------------
sub restart_browser {

    if ($case{restartbrowseronfail} && ($is_failure > 0)) { ## restart the Selenium browser session and also the WebInject session
        $results_stdout .= qq|RESTARTING SESSION DUE TO FAIL ... \n|;
        start_session();
    }

    if ($case{restartbrowser}) { ## restart the Selenium browser session and also the WebInject session
        $results_stdout .= qq|RESTARTING SESSION ... \n|;
        start_session();
    }

    return;
}

#------------------------------------------------------------------
sub sleep_before_next_step {

    if ( (($is_failure < 1) && ($case{retry})) || (($is_failure < 1) && ($case{retryfromstep})) )
    {
        ## ignore the sleep if the test case worked and it is a retry test case
    }
    else
    {
        if ($case{sleep})
        {
            if ( (($is_failure > 0) && ($retry < 1)) || (($is_failure > 0) && ($jumpbacks > ($config{globaljumpbacks}-1))) )
            {
                ## do not sleep if the test case failed and we have run out of retries or jumpbacks
            }
            else
            {
                ## if a sleep value is set in the test case, sleep that amount
                sleep $case{sleep};
            }
        }
    }

    return;
}

#------------------------------------------------------------------
sub write_initial_html {  #write opening tags for results file

    $results_html .= qq|<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"\n|;
    $results_html .= qq|    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">\n\n|;

    $results_html .= qq|<html xmlns="http://www.w3.org/1999/xhtml">\n|;
    $results_html .= qq|<head>\n|;
    $results_html .= qq|    <title>WebInject Test Results</title>\n|;
    $results_html .= qq|    <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />\n|;
    $results_html .= qq|    <style type="text/css">\n|;
    $results_html .= qq|        body {\n|;
    $results_html .= qq|            background-color: #F5F5F5;\n|;
    $results_html .= qq|            color: #000000;\n|;
    $results_html .= qq|            font-family: Verdana, Arial, Helvetica, sans-serif;\n|;
    $results_html .= qq|            font-size: 10px;\n|;
    $results_html .= qq|        }\n|;
    $results_html .= qq|        .pass {\n|;
    $results_html .= qq|            color: green;\n|;
    $results_html .= qq|        }\n|;
    $results_html .= qq|        .fail {\n|;
    $results_html .= qq|            color: red;\n|;
    $results_html .= qq|        }\n|;
    $results_html .= qq|        .skip {\n|;
    $results_html .= qq|            color: orange;\n|;
    $results_html .= qq|        }\n|;
    $results_html .= qq|    </style>\n|;
    $results_html .= qq|</head>\n|;
    $results_html .= qq|<body>\n|;
    $results_html .= qq|<hr />\n|;
    $results_html .= qq|-------------------------------------------------------<br />\n\n|;

    return;
}

#------------------------------------------------------------------
sub _whack {
    my ($_goner) = @_;

    if (-e $_goner ) {
        unlink $_goner or die "Could not unlink $_goner\n";
    }

    return;
}

#------------------------------------------------------------------
sub write_initial_xml {  #write opening tags for results file

    # put a reference to the stylesheet in the results file
    my $_results_xml = '<?xml version="1.0" encoding="ISO-8859-1"?>'."\n";
    $_results_xml .= '<?xml-stylesheet type="text/xsl" href="../../../../../../../content/Results.xsl"?>'."\n";
    $_results_xml .= "<results>\n\n";
    $results_xml_file_name = 'results.xml';
    if ( defined $user_config->{wif}->{dd} && defined $user_config->{wif}->{run_number} ) { # presume if this info is present, webinject.pl has been called by wif.pl
        $results_xml_file_name = 'results_'.$user_config->{wif}->{run_number}.'.xml';
        $_results_xml .= "    <wif>\n";
        $_results_xml .= "        <environment>$user_config->{wif}->{environment}</environment>\n";
        $_results_xml .= "        <yyyy>$user_config->{wif}->{yyyy}</yyyy>\n";
        $_results_xml .= "        <mm>$user_config->{wif}->{mm}</mm>\n";
        $_results_xml .= "        <dd>$user_config->{wif}->{dd}</dd>\n";
        $_results_xml .= "        <batch>$user_config->{wif}->{batch}</batch>\n";
        $_results_xml .= "    </wif>\n";
    }

    $_results_xml .= qq|\n    <testcases file="$current_case_file">\n\n|;

    _whack($opt_publish_full.$results_xml_file_name);
    _write_xml(\$_results_xml);

    return;
}

#------------------------------------------------------------------
sub _write_xml {
    my ($_xml) = @_;

    if (not $opt_no_output) {
        open my $_RESULTS_XML, '>>', "$opt_publish_full".$results_xml_file_name or die "\nERROR: Failed to open results.xml file\n\n";
        print {$_RESULTS_XML} ${$_xml};
        close $_RESULTS_XML or die "\nCould not close xml results file\n\n";
    }

    return;
}

#------------------------------------------------------------------
sub _write_html {
    my ($_html) = @_;

    if (not $opt_no_output) {
        open my $_RESULTS_HTML, '>>', $opt_publish_full.'results.html' or die "\nERROR: Failed to open results.html file\n\n";
        print {$_RESULTS_HTML} ${$_html};
        close $_RESULTS_HTML or die "\nCould not close html results file\n\n";
    }

    return;
}

#------------------------------------------------------------------
sub write_initial_stdout {  #write initial text for STDOUT

    $results_stdout .= "\n";
    $results_stdout .= "Starting WebInject Engine...\n\n";

    return;
}

#------------------------------------------------------------------
sub write_final_html {  #write summary and closing tags for results file

    $results_html .= qq|<br /><hr /><br />\n|;
    $results_html .= qq|<b>\n|;
    $results_html .= qq|Start Time: $current_date_time <br />\n|;
    $results_html .= qq|Total Run Time: $total_run_time seconds <br />\n|;
    $results_html .= qq|Total Response Time: $total_response seconds <br />\n|;
    $results_html .= qq|<br />\n|;
    $results_html .= qq|Test Cases Run: $total_run_count <br />\n|;
    $results_html .= qq|Test Cases Passed: $case_passed_count <br />\n|;
    $results_html .= qq|Test Cases Failed: $case_failed_count <br />\n|;
    $results_html .= qq|Verifications Passed: $passed_count <br />\n|;
    $results_html .= qq|Verifications Failed: $failed_count <br />\n|;
    $results_html .= qq|<br />\n|;
    $results_html .= qq|Average Response Time: $avg_response seconds <br />\n|;
    $results_html .= qq|Max Response Time: $max_response seconds <br />\n|;
    $results_html .= qq|Min Response Time: $min_response seconds <br />\n|;
    $results_html .= qq|</b>\n|;
    $results_html .= qq|<br />\n\n|;

    $results_html .= qq|</body>\n|;
    $results_html .= qq|</html>\n|;

    _write_html(\$results_html);
    undef $results_html;

    return;
}

#------------------------------------------------------------------
sub write_final_xml {  #write summary and closing tags for XML results file

    if ($case{sanitycheck} && ($case_failed_count > 0)) { ## sanitycheck
        $sanity_result = 'false';
    }
    else {
        $sanity_result = 'true';
    }

    $results_xml .= qq|    </testcases>\n\n|;

    $results_xml .= qq|    <test-summary>\n|;
    $results_xml .= qq|        <start-time>$current_date_time</start-time>\n|;
    $results_xml .= qq|        <start-seconds>$TIMESECONDS</start-seconds>\n|;
    $results_xml .= qq|        <start-date-time>$STARTDATE|;
    $results_xml .= qq|T$HOUR:$MINUTE:$SECOND</start-date-time>\n|;
    $results_xml .= qq|        <total-run-time>$total_run_time</total-run-time>\n|;
    $results_xml .= qq|        <total-response-time>$total_response</total-response-time>\n|;
    $results_xml .= qq|        <test-cases-run>$total_run_count</test-cases-run>\n|;
    $results_xml .= qq|        <test-cases-passed>$case_passed_count</test-cases-passed>\n|;
    $results_xml .= qq|        <test-cases-failed>$case_failed_count</test-cases-failed>\n|;
    $results_xml .= qq|        <verifications-passed>$passed_count</verifications-passed>\n|;
    $results_xml .= qq|        <verifications-failed>$failed_count</verifications-failed>\n|;
    $results_xml .= qq|        <assertion-skips>$total_assertion_skips</assertion-skips>\n|;
    $results_xml .= qq|        <average-response-time>$avg_response</average-response-time>\n|;
    $results_xml .= qq|        <max-response-time>$max_response</max-response-time>\n|;
    $results_xml .= qq|        <min-response-time>$min_response</min-response-time>\n|;
    $results_xml .= qq|        <sanity-check-passed>$sanity_result</sanity-check-passed>\n|;
    $results_xml .= qq|        <test-file-name>$testfilename</test-file-name>\n|;
    $results_xml .= qq|    </test-summary>\n\n|;

    $results_xml .= qq|</results>\n|;

    _write_xml(\$results_xml);
    undef $results_xml;

    return;
}

#------------------------------------------------------------------
sub write_final_stdout {  #write summary and closing text for STDOUT

    $results_stdout .= qq|Start Time: $current_date_time\n|;
    $results_stdout .= qq|Total Run Time: $total_run_time seconds\n\n|;
    $results_stdout .= qq|Total Response Time: $total_response seconds\n\n|;

    $results_stdout .= qq|Test Cases Run: $total_run_count\n|;
    $results_stdout .= qq|Test Cases Passed: $case_passed_count\n|;
    $results_stdout .= qq|Test Cases Failed: $case_failed_count\n|;
    $results_stdout .= qq|Verifications Passed: $passed_count\n|;
    $results_stdout .= qq|Verifications Failed: $failed_count\n\n|;

    if ($opt_publish_full eq $output) {
        $results_stdout .= qq|Results at: $opt_publish_full|.'results.html'.qq|\n|;
    }

    if (not $opt_no_output) { print {*STDOUT} $results_stdout; }
    undef $results_stdout;

    #plugin modes
    if ($report_type && $report_type ne 'standard') {  #return value is set which corresponds to a monitoring program

        #Nagios plugin compatibility
        my %_exit_codes;
        if ($report_type eq 'nagios') { #report results in Nagios format 
            #predefined exit codes for Nagios
            %_exit_codes  = ('UNKNOWN' ,-1,
                            'OK'      , 0,
                            'WARNING' , 1,
                            'CRITICAL', 2,);

	    my $_end = defined $user_config->{globaltimeout} ? "$user_config->{globaltimeout};;0" : ';;0';

            if ($case_failed_count > 0) {
	        print "WebInject CRITICAL - $return_message |time=$total_response;$_end\n";
                exit $_exit_codes{'CRITICAL'};
            }
            elsif ( ($user_config->{globaltimeout}) && ($total_response > $user_config->{globaltimeout}) ) {
                print "WebInject WARNING - All tests passed successfully but global timeout ($user_config->{globaltimeout} seconds) has been reached |time=$total_response;$_end\n";
                exit $_exit_codes{'WARNING'};
            }
            else {
                print "WebInject OK - All tests passed successfully in $total_response seconds |time=$total_response;$_end\n";
                exit $_exit_codes{'OK'};
            }
        }

        else {
            print {*STDERR} "\nError: only 'nagios' or 'standard' are supported reporttype values\n\n";
        }

    }

    return;
}

#------------------------------------------------------------------
sub _run_this_step {
    my ($_runon_parm) = @_;

    my @_run_on = split /[|]/, $_runon_parm; ## get the list of environments that this test step can be run on
    foreach (@_run_on) {
        if (defined $user_config->{wif}->{environment}) {
            if ( $_ eq $user_config->{wif}->{environment} ) {
                return 'true';
            }
        }
    }

    return;
}

## Selenium server support
#------------------------------------------------------------------
sub selenium {  ## send Selenium command and read response
    require Selenium::Remote::Driver;
    require Selenium::Chrome;
    require Data::Dumper;

    $start_timer = time;

    my $_combined_response = q{};
    $request = HTTP::Request->new('GET','WebDriver');

    ## commands must be run in this order
    for (qw/command command1 command2 command3 command4 command5 command6 command7 command8 command9 command10  command11 command12 command13 command14 command15 command16 command17 command18 command19 command20/) {
        if ($case{$_}) {#perform command
            my $_command = $case{$_};
            undef $selresp;
            my $_eval_response = eval { eval "$_command"; if ($@) { print "\nSelenium Exception: $@\n"; } }; ## no critic(ProhibitStringyEval)
            
             #$results_stdout .= "EVALRESP:$_eval_response\n";
            if (defined $selresp) { ## phantomjs does not return a defined response sometimes
                if (($selresp =~ m/(^|=)HASH\b/) || ($selresp =~ m/(^|=)ARRAY\b/)) { ## check to see if we have a HASH or ARRAY object returned
                    my $_dumper_response = Data::Dumper::Dumper($selresp);
                    $results_stdout .= "SELRESP: DUMPED:\n$_dumper_response";
                    $selresp = "selresp:DUMPED:$_dumper_response";
                } else {
                    $results_stdout .= "SELRESP:$selresp\n";
                    $selresp = "selresp:$selresp";
                }
            } else {
                $results_stdout .= "SELRESP:<undefined>\n";
                $selresp = 'selresp:<undefined>';
            }
            $_combined_response =~ s{$}{<$_>$_command</$_>\n$selresp\n\n\n}; ## include it in the response
        }
    }
    $selresp = $_combined_response;

    if ($selresp =~ /^ERROR/) { ## Selenium returned an error
       $selresp =~ s{^}{HTTP/1.1 500 Selenium returned an error\n\n}; ## pretend this is an HTTP response - 100 means continue
    }
    else {
       $selresp =~ s{^}{HTTP/1.1 100 OK\n\n}; ## pretend this is an HTTP response - 100 means continue
    }

    $end_timer = time; ## we only want to measure the time it took for the commands, not to do the screenshots and verification
    $latency = (int(1000 * ($end_timer - $start_timer)) / 1000);  ## elapsed time rounded to thousandths

    _get_verifytext(); ## will be injected into $selresp
    $response = HTTP::Response->parse($selresp); ## pretend the response is an http response - inject it into the object

    _screenshot();

    return;
} ## end sub

sub _get_verifytext {
    $start_timer = time; ## measure latency for the verification
    sleep 0.020; ## Sleep for 20 milliseconds

    ## multiple verifytexts are separated by commas
    if ($case{verifytext}) {
        my @_parse_verify = split /,/, $case{verifytext} ;
        foreach (@_parse_verify) {
            my $_verify_text = $_;
            $results_stdout .= "$_verify_text\n";
            my @_verify_response;

            if ($_verify_text eq 'get_body_text') {
                print "GET_BODY_TEXT:$_verify_text\n";
                eval { @_verify_response =  $driver->find_element('body','tag_name')->get_text(); };
            } else {
                eval { @_verify_response = $driver->$_verify_text(); }; ## sometimes Selenium will return an array
            }

            $selresp =~ s{$}{\n\n\n\n}; ## put in a few carriage returns after any Selenium server message first
            my $_idx = 0;
            foreach my $_vresp (@_verify_response) {
                $_vresp =~ s/[^[:ascii:]]+//g; ## get rid of non-ASCII characters in the string element
                $_idx++; ## we number the verifytexts from 1 onwards to tell them apart in the tags
                $selresp =~ s{$}{<$_verify_text$_idx>$_vresp</$_verify_text$_idx>\n}; ## include it in the response
                if (($_vresp =~ m/(^|=)HASH\b/) || ($_vresp =~ m/(^|=)ARRAY\b/)) { ## check to see if we have a HASH or ARRAY object returned
                    my $_dumper_response = Data::Dumper::Dumper($_vresp);
                    my $_dumped = 'dumped';
                    $selresp =~ s{$}{<$_verify_text$_dumped$_idx>$_dumper_response</$_verify_text$_dumped$_idx>\n}; ## include it in the response
                    ## ^ means match start of string, $ end of string
                }
            }
        }
    }

    $end_timer = time; ## we only want to measure the time it took for the commands, not to do the screenshots and verification
    $verification_latency = (int(1000 * ($end_timer - $start_timer)) / 1000);  ## elapsed time rounded to thousandths

    return;
}

sub _screenshot {
    $start_timer = time; ## measure latency for the screenshot

    my $_abs_screenshot_full = File::Spec->rel2abs( "$opt_publish_full$testnum_display$jumpbacks_print$retries_print.png" );

    ## do the screenshot, needs to be in eval in case modal popup is showing (screenshot not possible)
    eval { $png_base64 = $driver->screenshot(); };

    ## if there was an error in taking the screenshot, $@ will have content
    if ($@) {
        $results_stdout .= "Selenium full page grab failed.\n";
        $results_stdout .= "ERROR:$@";
    } else {
        require MIME::Base64;
        open my $_FH, '>', slash_me($_abs_screenshot_full) or die "\nCould not open $_abs_screenshot_full for writing\n";
        binmode $_FH; ## set binary mode
        print {$_FH} MIME::Base64::decode_base64($png_base64);
        close $_FH or die "\nCould not close page capture file handle\n";
    }

    $end_timer = time; ## we only want to measure the time it took for the commands, not to do the screenshots and verification
    $screenshot_latency = (int(1000 * ($end_timer - $start_timer)) / 1000);  ## elapsed time rounded to thousandths

    return;
}

sub helper_select_by_text { ## usage: helper_select_by_text(Search Target, Locator, Label);
                            ##        helper_select_by_text('candidateProfileDetails_ddlCurrentSalaryPeriod','id','Daily Rate');

    my ($_search_target, $_locator, $_labeltext) = @_;

    my $_element = $driver->find_element("$_search_target", "$_locator");
    my $_child = $driver->find_child_element($_element, "./option[. = '$_labeltext']")->click();

    return $_child;
}

sub helper_clear_and_send_keys { ## usage: helper_clear_and_send_keys(Search Target, Locator, Keys);
                                 ##        helper_clear_and_send_keys('candidateProfileDetails_txtPostCode','id','WC1X 8TG');

    my ($_search_target, $_locator, $_keys) = @_;

    my $_element = $driver->find_element("$_search_target", "$_locator")->clear();
    my $_response = $driver->find_element("$_search_target", "$_locator")->send_keys("$_keys");

    return $_response;
}

sub helper_mouse_move_to_location { ## usage: helper_mouse_move_to_location(Search Target, Locator, xoffset, yoffset);
                                    ##        helper_mouse_move_to_location('closeBtn','id',3,4);
                                    ##        helper_mouse_move_to_location('closeBtn','id'); # offsets are optional 

    my ($_search_target, $_locator, $_xoffset, $_yoffset) = @_;
    $_xoffset = int $_xoffset;
    $_yoffset = int $_yoffset;

    my $_element = $driver->find_element("$_search_target", "$_locator");
    my $_child = $driver->mouse_move_to_location(element => $_element, xoffset => $_xoffset, yoffset => $_yoffset);

    return $_child;
}

sub helper_switch_to_window { ## usage: helper_switch_to_window(window number);
                              ##        helper_switch_to_window(0);
                              ##        helper_switch_to_window(1);
    my ($_window_number) = @_;

    require Data::Dumper;

    my $_handles = $driver->get_window_handles;
    print Data::Dumper::Dumper($_handles);
    my $_response =  $driver->switch_to_window($_handles->[$_window_number]);

    return $_response;
}

sub helper_keys_to_element_after { ## usage: helper_keys_to_element_after(anchor,keys,tag);
                                   ##        helper_keys_to_element_after('Where','London');               # will default to 'INPUT'
                                   ##        helper_keys_to_element_after('Job Type','Contract','SELECT');

    my ($_anchor,$_keys,$_tag) = @_;
    $_tag //= 'INPUT';

    print "Got to helper_keys_to_element_after\n";
    return _helper_keys_to_element($_anchor,1,$_tag,1,$_keys);
}

sub helper_keys_to_element_before { ## usage: helper_keys_to_element_before(anchor,keys,tag);
                                    ##        helper_keys_to_element_before('Where','London');               # will default tag to 'INPUT'
                                    ##        helper_keys_to_element_before('Job Type','Contract','SELECT');

    my ($_anchor,$_keys,$_tag) = @_;
    $_tag //= 'INPUT';

    return _helper_keys_to_element($_anchor,1,$_tag,-1,$_keys);
}

sub _helper_keys_to_element {

    my ($_anchor,$_anchor_instance,$_tag,$_tag_instance,$_keys) = @_;

    #print "Got to helper_keys_to_element BEFORE call to _helper_click_element\n";
    my $_response = _helper_focus_element($_anchor,$_anchor_instance,$_tag,$_tag_instance);
    #print "Got to helper_keys_to_element AFTER call to _helper_click_element\n";

    if ($_response =~ m/Could not find/) { return $_response; }
    #print "Got to helper_keys_to_element AFTER check for Could not find\n";

    if ($_tag eq 'SELECT') {
        my $_element = $driver->get_active_element();
        my $_child = $driver->find_child_element($_element, "./option[. = '$_keys']")->click();
    } else {
        my $_keys_response = $driver->get_active_element()->clear();
        #print "Got to helper_keys_to_element - clear active element\n";
        $_keys_response = $driver->send_keys_to_active_element($_keys);
        #print "Got to helper_keys_to_element - send keys to active element\n";
    }

    return $_response . ' then sent keys OK';
}

sub _helper_click_element { ## internal use only: _helper_click_element(anchor,anchor_instance,tag,tag_instance);

    my ($_anchor,$_anchor_instance,$_tag,$_tag_instance) = @_;

    return _helper_focus_element($_anchor,$_anchor_instance,$_tag,$_tag_instance);

    ## Unfortunately Selenium is over-thinking the clicking and in some cases refusing to click elements that are clickable, so the focus helper will also click with JavaScript
    #if ($_response =~ m/Could not find/) { return $_response; }
    #my $_click_response = $driver->get_active_element()->click();
    #return $_response . ' then clicked OK';
}

sub _helper_focus_element { ## internal use only: _helper_focus_element(anchor,anchor_instance,tag,tag_instance);

    my ($_anchor,$_anchor_instance,$_tag,$_tag_instance) = @_;
    $_anchor_instance //= 1; ## 1 means first instance of anchor
    $_tag //= '*'; ## * means click the tag found by the anchor, whatever it is
    $_tag_instance //= 0; ## -1 means search for the specified tag BEFORE, 1 means search for specified tag after, 0 is an error unless $_tag is '*' 

    my $_script = _helper_javascript_functions() . q`

        var anchor_ = arguments[0];
        var anchor_instance_ = arguments[1];
        var tag_ = arguments[2].split("|");
        var tag_instance_ = arguments[3];
        var _all_ = window.document.getElementsByTagName("*");
        var _debug_ = '';

        var info_ = search_for_element(anchor_,anchor_instance_);

        if (info_.elementIndex == -1) {
            return "Could not find anchor text" + _debug_;
        }

        var target_element_index_ = -1;
        var action_keyword_;
        if (tag_[0] === '*') {
            target_element_index_ = info_.elementIndex;
            action_keyword_ = 'WITH';
        } else if (tag_instance_ > 0) {

            for (var i=info_.elementIndex, max=_all_.length; i < max; i++) {
                target_element_index_ = is_element_at_index_a_match(tag_,i);
                if (target_element_index_ > -1) {
                    break;
                }
            }
            action_keyword_ = 'AFTER';

        } else {

            for (var i=info_.elementIndex, min=-1; i > min; i--) {
                target_element_index_ = is_element_at_index_a_match(tag_,i);
                if (target_element_index_ > -1) {
                    break;
                }
            }
            action_keyword_ = 'BEFORE';

        }

        if (target_element_index_ > -1) {
            _all_[target_element_index_].focus();
            _all_[target_element_index_].click();
        } else {
            return "Could not find " + tag_.toString() + " element before the anchor text" + _debug_;
        }

        return element_action_info("Focused and clicked",target_element_index_,action_keyword_,anchor_,info_.textIndex);
    `;
    my $_response = $driver->execute_script($_script,$_anchor,$_anchor_instance,$_tag,$_tag_instance);

    return $_response;
}


sub helper_keys_to_element { ## usage: helper_keys_to_element(anchor,keys);
                             ##        helper_keys_to_element('E.g. Regional Manager','Test Automation Architect');

    my ($_anchor,$_keys) = @_;

    return _helper_keys_to_element($_anchor,1,'*',0,$_keys);
}

sub helper_click { ## usage: helper_click(anchor[,instance]);
                   ## usage: helper_click('Yes');
                   ## usage: helper_click('Yes',2);

    my ($_anchor,$_anchor_instance) = @_;
    $_anchor_instance //= 1;

    return _helper_click_element($_anchor,$_anchor_instance,'*',0);
}

sub helper_click_before { ## usage: helper_click_before(anchor[,element,instance]);

    my ($_anchor,$_tag,$_anchor_instance) = @_;
    $_tag //= 'INPUT|BUTTON|SELECT|A';
    $_anchor_instance //= 1;

    return _helper_click_element($_anchor,$_anchor_instance,$_tag,-1);
}

sub helper_click_after { ## usage: helper_click_after(anchor[,element,instance]);

    my ($_anchor,$_tag,$_anchor_instance) = @_;
    $_tag //= 'INPUT|BUTTON|SELECT|A';
    $_anchor_instance //= 1;

    return _helper_click_element($_anchor,$_anchor_instance,$_tag,1);
}

sub _helper_javascript_functions {

    return q`
        function get_element_number_by_text(_anchor,_depth,_instance)
        {
            var _textIndex = -1;
            var _elementIndex = -1;
            var _found_instance = 0;
            for (var i=0, max=_all_.length; i < max; i++) {
                if (_all_[i].getAttribute('type') === 'hidden') { 
                    continue; // Ignore hidden elements
                }
                var _text = '';
                for (var j = 0; j < _all_[i].childNodes.length; ++j) {
                   if (_all_[i].childNodes[j].nodeType === 3) { // 3 means TEXT_NODE
                       _text += _all_[i].childNodes[j].textContent; // We only want the text immediately within the element, not any child elements
                   }
                }

                //_debug_ = _debug_ + ' ' + _all_[i].tagName;
                //if (_all_[i].id) {
                //    _debug_ = _debug_ + " id[" + _all_[i].id + "]";
                //}

                _textIndex = _text.indexOf(_anchor);
                if (_textIndex != -1 && _textIndex < _depth) {  // Need to target near start of string so Type can be targeted instead of Account Record Type
                    _found_instance = _found_instance + 1;
                    if (_instance === _found_instance) {
                        _elementIndex = i;
                        break;
                    } else {
                        continue;
                    }
                }
            }

            return {
                elementIndex : _elementIndex,
                textIndex : _textIndex
            }
        }

        function get_element_number_by_attribute(_anchor,_depth,_instance)
        {
            var _textIndex = -1;
            var _elementIndex = -1;
            var _found_instance = 0;
            for (var i=0, max=_all_.length; i < max; i++) {
                if (_all_[i].getAttribute('type') === 'hidden') { 
                    continue; // Ignore hidden elements
                }

                for (var j = 0; j < _all_[i].attributes.length; j++) {
                    var attrib = _all_[i].attributes[j];
                    if (attrib.specified) {

                        _textIndex = attrib.value.indexOf(_anchor);
                        if (_textIndex != -1 && _textIndex < _depth) {
                            _found_instance = _found_instance + 1;
                            if (_instance === _found_instance) {
                                _elementIndex = i;
                                break;
                            } else {
                                continue;
                            }
                        }
                    }
                }

                if (_elementIndex > -1) {
                    break;
                }

            }

            return {
                elementIndex : _elementIndex,
                textIndex : _textIndex
            }
        }

        function search_for_element(_anchor,_instance) {
            var _depth = [1,3,15,50];
    
            var _info;
            // An element match at text index 0 is preferable to text index 30, so we start off strict, then gradually relax our criteria
            for (var i=0; i < _depth.length; i++) {
                _info = get_element_number_by_text(_anchor,_depth[i],_instance);
                if (_info.elementIndex > -1) {
                    return {
                        elementIndex : _info.elementIndex,
                        textIndex : _info.textIndex
                    }
                }
            }
            for (var i=0; i < _depth.length; i++) {
                _info = get_element_number_by_attribute(_anchor,_depth[i],_instance);
                if (_info.elementIndex > -1) {
                    return {
                        elementIndex : _info.elementIndex,
                        textIndex : _info.textIndex
                    }
                }
            }
            return {
                elementIndex : -1,
                textIndex : -1
            }
        }


        function is_element_at_index_a_match(_tags,_i) {
            for (var j=0; j < _tags.length; j++) {
                if (_all_[_i].tagName == _tags[j] && !(_all_[_i].getAttribute('type') === 'hidden')) {
                    return _i;
                }
            }
            return -1;
        }

        function element_action_info(_action,_targetElementIndex,_anchor_info,_anchor,_textIndex) {
            var _id = '';
            if (_all_[_targetElementIndex].id) {
                _id=" id[" + _all_[_targetElementIndex].id + "]";
            } 
            return _action + " tag " + _all_[_targetElementIndex].tagName + " " + _anchor_info + "[" +_anchor + "] OK (text index " + _textIndex + ")" + _id + _debug_;
        }
    `; 
}

sub helper_get_attribute { ## usage: helper_get_attribute(Search Target, Locator, Target Attribute);
                           ##        helper_get_attribute(q|label[for='eligibilityUkYes']|,'css','class');

    my ($_search_target, $_locator, $_attribute) = @_;

    my $_element = $driver->find_element("$_search_target", "$_locator");

    my $_script = q|
        var _element = arguments[0];
        var _attribute = arguments[1];
        return _element.getAttribute(_attribute);
    |;

    my $_response = $driver->execute_script($_script,$_element,$_attribute);
    return $_response;
}

sub helper_get_element_value { ## usage: helper_get_element_value(Search Target, Locator);
                               ##        helper_get_element_value('currentJobTitle','id');

    my ($_search_target, $_locator) = @_;

    my $_element = $driver->find_element("$_search_target", "$_locator");

    my $_script = q|
        var _element = arguments[0];
        return _element.value;
    |;

    my $_response = $driver->execute_script($_script,$_element);
    return $_response;
}

sub helper_get_selection { ## usage: helper_get_selection(Search Target, Locator);
                           ##        helper_get_selection(q|select[id='ddlEducation']|,'css');

    my ($_search_target, $_locator) = @_;

    my $_element = $driver->find_element("$_search_target", "$_locator");

    my $_script = q|
        var _element = arguments[0];
        var _selectedValue = _element.options[_element.selectedIndex].value;
        var _selectedText = _element.options[_element.selectedIndex].text;
        return "[" + _selectedValue + "] " + _selectedText;
    |;

    my $_response = $driver->execute_script($_script,$_element);
    return $_response;
}

sub helper_is_checked { ## usage: helper_is_checked(Search Target, Locator);

    my ($_search_target, $_locator) = @_;

    my $_element = $driver->find_element("$_search_target", "$_locator");

    my $_script = q|
        var _element = arguments[0];
        var _return;
        if (_element.checked) {
            _return = 'Element is checked';
        } else {
            _return = 'Element is not checked';
        }
        return _return;
    |;

    my $_response = $driver->execute_script($_script,$_element);
    return $_response;
}

sub helper_js_click { ## usage: helper_js_click(id);
                      ##        helper_js_click('btnSubmit');

    my ($_id_to_click) = @_;

    my $_script = q{
        var arg1 = arguments[0];
        var elem = window.document.getElementById(arg1).click();
        return elem;
    };
    my $_response = $driver->execute_script($_script,$_id_to_click);

    return $_response;
}

sub helper_js_set_value {  ## usage: helper_js_set_value(id,value);
                           ##        helper_js_set_value('cvProvider_filCVUploadFile','{CWD}\testdata\MyCV.doc');
                           ##
                           ##        Single quotes will not treat \ as escape codes

    my ($_id_to_set_value, $_value_to_set) = @_;

    my $_script = q{
        var arg1 = arguments[0];
        var arg2 = arguments[1];
        var elem = window.document.getElementById(arg1).value=arg2;
        return elem;
    };
    my $_response = $driver->execute_script($_script,$_id_to_set_value,$_value_to_set);

    return $_response;
}

sub helper_js_make_field_visible_to_webdriver {     ## usage: helper_js_make_field_visible(id);
                                                    ##        helper_js_make_field_visible('cvProvider_filCVUploadFile');

    my ($_id_to_set_css) = @_;

    my $_script = q{
        var arg1 = arguments[0];
        window.document.getElementById(arg1).style.width = '5px';
        var elem = window.document.getElementById(arg1).style.height = '5px';
        return elem;
    };
    my $_response = $driver->execute_script($_script,$_id_to_set_css);

    return $_response;
}

sub helper_check_element_within_pixels {     ## usage: helper_check_element_within_pixels(searchTarget,id,xBase,yBase,pixelThreshold);
                                             ##        helper_check_element_within_pixels('txtEmail','id',193,325,30);

    my ($_search_target, $_locator, $_x_base, $_y_base, $_pixel_threshold) = @_;

    ## get_element_location will return a reference to a hash associative array
    ## http://www.troubleshooters.com/codecorn/littperl/perlscal.htm
    ## the array will look something like this
    # { 'y' => 325, 'hCode' => 25296896, 'x' => 193, 'class' => 'org.openqa.selenium.Point' };
    my ($_location) = $driver->find_element("$_search_target", "$_locator")->get_element_location();

    ## if the element doesn't exist, we get an empty output, so presumably this subroutine just dies and the program carries on

    ## we use the -> operator to get to the underlying values in the hash array
    my $_x = $_location->{x};
    my $_y = $_location->{y};

    my $_x_diff = abs $_x_base - $_x;
    my $_y_diff = abs $_y_base - $_y;

    my $_message = "Pixel threshold check passed - $_search_target is $_x_diff,$_y_diff (x,y) pixels removed from baseline of $_x_base,$_y_base; actual was $_x,$_y";

    if ($_x_diff > $_pixel_threshold || $_y_diff > $_pixel_threshold) {
        $_message = "Pixel threshold check failed - $_search_target is $_x_diff,$_y_diff (x,y) pixels removed from baseline of $_x_base,$_y_base; actual was $_x,$_y";
    }

    return $_message;
}

sub helper_wait_for_text_present { ## usage: helper_wait_for_text_present('Search Text',Timeout);
                                   ##        helper_wait_for_text_present('Job title',10);
                                   ##
                                   ## waits for text to appear in page source

    my ($_search_text, $_timeout) = @_;

    $results_stdout .= "SEARCHTEXT:$_search_text\n";

    my $_search_expression = '@_response = $driver->get_page_source();'; ## no critic(RequireInterpolationOfMetachars)
    my $_found_expression = 'if ($__response =~ m{$_search_text}si) { return q|true|; }  else { return; }'; ## no critic(RequireInterpolationOfMetachars)

    return _wait_for_item_present($_search_expression, $_found_expression, $_timeout, 'text in page source', $_search_text);

}

sub helper_wait_for_text_visible { ## usage: helper_wait_for_text_visible('Search Text','target', 'locator', Timeout);
                                   ##         helper_wait_for_text_visible('Job title', 'body', 'tag_name', 10);
                                   ##
                                   ## Waits for text to appear visible in the body text. This function can sometimes be very slow on some pages.

    my ($_search_text, $_target, $_locator, $_timeout) = @_;
    $_target //= 'body';
    $_locator //= 'tag_name';
    $_timeout //= 5;

    $results_stdout .= "VISIBLE SEARCH TEXT:$_search_text\n";

    my $_search_expression = '@_response = $driver->find_element($_target,$_locator)->get_text();'; ## no critic(RequireInterpolationOfMetachars)
    my $_found_expression = 'if ($__response =~ m{$_search_text}si) { return q|true|; }  else { return; }'; ## no critic(RequireInterpolationOfMetachars)

    return _wait_for_item_present($_search_expression, $_found_expression, $_timeout, 'text visible', $_search_text, $_target, $_locator);

}

sub helper_wait_for_element_present { ## usage: helper_wait_for_element_present(target,locator,timeout);
                                      ##        helper_wait_for_element_present('menu-search-icon','id',5);

    my ($_target, $_locator, $_timeout) = @_;

    $results_stdout .= "SEARCH TARGET[$_target], LOCATOR[$_locator], TIMEOUT[$_timeout]\n";

    my $_search_expression = '@_response = $driver->find_element("$_target","$_locator");'; ## no critic(RequireInterpolationOfMetachars)
    my $_found_expression = 'if ($__response) { return q|true|; }  else { return; }'; ## no critic(RequireInterpolationOfMetachars)

    return _wait_for_item_present($_search_expression, $_found_expression, $_timeout, 'element', 'NA', $_target, $_locator);

}

sub helper_wait_for_element_visible { ## usage: helper_wait_for_element_visible(target,locator,timeout);
                                      ##        helper_wait_for_element_visible('menu-search-icon','id',5);

    my ($_target, $_locator, $_timeout) = @_;

    $results_stdout .= "SEARCH TARGET VISIBLE[$_target], LOCATOR[$_locator], TIMEOUT[$_timeout]\n";

    my $_search_expression = '@_response = $driver->find_element("$_target","$_locator")->is_displayed();'; ## no critic(RequireInterpolationOfMetachars)
    my $_found_expression = 'if ($__response) { return q|true|; }  else { return; }'; ## no critic(RequireInterpolationOfMetachars)

    return _wait_for_item_present($_search_expression, $_found_expression, $_timeout, 'element visible', 'NA', $_target, $_locator);

}

sub _wait_for_item_present {

    my ($_search_expression, $_found_expression, $_timeout, $_message_fragment, $_search_text, $_target, $_locator) = @_;

    $results_stdout .= "TIMEOUT:$_timeout\n";

    my $_timestart = time;
    my @_response;
    my $_found_it;

    while ( (($_timestart + $_timeout) > time) && (not $_found_it) ) {
        eval { eval "$_search_expression"; }; ## no critic(ProhibitStringyEval)
        foreach my $__response (@_response) {
            if (eval { eval "$_found_expression";} ) { ## no critic(ProhibitStringyEval)
                $_found_it = 'true';
            }
        }
        if (not $_found_it) {
            sleep 0.5; # Sleep for 0.5 seconds
        }
    }
    my $_try_time = ( int( (time - $_timestart) *10 ) / 10);

    my $_message;
    if ($_found_it) {
        $_message = 'Found sought '.$_message_fragment." after $_try_time seconds";
    }
    else {
        $_message = 'Did not find sought '.$_message_fragment.", timed out after $_try_time seconds";
    }

    return $_message;
}

sub helper_wait_for_text_not_present { ## usage: helper_wait_for_text_not_present('Search Text',timeout);
                                       ##        helper_wait_for_text_not_present('Job title',10);
                                       ##
                                       ## waits for text to disappear from page source

    my ($_search_text, $_timeout) = @_;

    $results_stdout .= "DO NOT WANT TEXT:$_search_text\n";

    my $_search_expression = '@_response = $driver->get_page_source();'; ## no critic(RequireInterpolationOfMetachars)
    my $_found_expression = 'if ($__response =~ m{$_search_text}si) { return q|true|; }  else { return; }'; ## no critic(RequireInterpolationOfMetachars)

    return _wait_for_item_not_present($_search_expression, $_found_expression, $_timeout, 'text in page source', $_search_text);

}

sub helper_wait_for_text_not_visible { ## usage: helper_wait_for_text_not_visible('Search Text',timeout);
                                       ##        helper_wait_for_text_not_visible('This job has been emailed to',10);
                                       ##
                                       ## waits for text to be not visible in the body text - e.g. closing a JavaScript popup

    my ($_search_text, $_timeout) = @_;

    $results_stdout .= "NOT VISIBLE SEARCH TEXT:$_search_text\n";

    my $_search_expression = '@_response = $driver->find_element(q|body|,q|tag_name|)->get_text();'; ## no critic(RequireInterpolationOfMetachars)
    my $_found_expression = 'if ($__response =~ m{$_search_text}si) { return q|true|; }  else { return; }'; ## no critic(RequireInterpolationOfMetachars)

    return _wait_for_item_not_present($_search_expression, $_found_expression, $_timeout, 'text visible', $_search_text);

}

sub _wait_for_item_not_present {

    my ($_search_expression, $_found_expression, $_timeout, $_message_fragment, $_search_text, $_target, $_locator) = @_;

    $results_stdout .= "TIMEOUT:$_timeout\n";

    my $_timestart = time;
    my @_response;
    my $_found_it = 'true';

    while ( (($_timestart + $_timeout) > time) && ($_found_it) ) {
        eval { eval "$_search_expression"; }; ## no critic(ProhibitStringyEval)
        foreach my $__response (@_response) {
            if (not eval { eval "$_found_expression";} ) { ## no critic(ProhibitStringyEval)
                undef $_found_it;
            }
        }
        if ($_found_it) {
            sleep 0.5; # Sleep for 0.5 seconds
        }
    }
    my $_try_time = ( int( (time - $_timestart) *10 ) / 10);

    my $_message;
    if (not $_found_it) {
        $_message = 'SUCCESS: Sought '.$_message_fragment." not found after $_try_time seconds";
    }
    else {
        $_message = 'TIMEOUT: Still found '.$_message_fragment.", timed out after $_try_time seconds";
    }

    return $_message;
}

#------------------------------------------------------------------
sub addcookie { ## add a cookie like JBM_COOKIE=4830075
    if ($case{addcookie}) { ## inject in an additional cookie for this test step only if specified
        my $_cookies = $request->header('Cookie');
        if (defined $_cookies) {
            #print "[COOKIE] $_cookies\n";
            $request->header('Cookie' => "$_cookies; " . $case{addcookie});
            #print '[COOKIE UPDATED] ' . $request->header('Cookie') . "\n";
        } else {
            #print "[COOKIE] <UNDEFINED>\n";
            $request->header('Cookie' => $case{addcookie});
            #print "[COOKIE UPDATED] " . $request->header('Cookie') . "\n";
        }
        undef $_cookies;
    }

    return;
}

#------------------------------------------------------------------
sub gethrefs { ## get page href assets matching a list of ending patterns, separate multiple with |
               ## gethrefs=".less|.css"
    if ($case{gethrefs}) {
        my $_match = 'href=';
        my $_delim = q{"}; #"
        get_assets ($_match,$_delim,$_delim,$case{gethrefs}, 'hrefs');
    }

    return;
}

#------------------------------------------------------------------
sub getsrcs { ## get page src assets matching a list of ending patterns, separate multiple with |
              ## getsrcs=".js|.png|.jpg|.gif"
    if ($case{getsrcs}) {
        my $_match = 'src=';
        my $_delim = q{"}; #"
        get_assets ($_match, $_delim, $_delim, $case{getsrcs}, 'srcs');
    }

    return;
}

#------------------------------------------------------------------
sub getbackgroundimages { ## style="background-image: url( )"

    if ($case{getbackgroundimages}) {
        my $_match = 'style="background-image: url';
        my $_left_delim = '\(';
        my $_right_delim = '\)';
        get_assets ($_match,$_left_delim,$_right_delim,$case{getbackgroundimages}, 'bg-images');
    }

    return;
}

#------------------------------------------------------------------
sub get_assets { ## get page assets matching a list for a reference type
                ## get_assets ('href',q{"},q{"},'.less|.css')

    my ($_match, $_left_delim, $_right_delim, $assetlist, $_type) = @_;

    require URI::URL; ## So gethrefs can determine the absolute URL of an asset, and the asset name, given a page url and an asset href

    my ($_start_asset_request, $_end_asset_request, $_asset_latency);
    my ($_asset_ref, $_ur_url, $_asset_url, $_path, $_filename, $_asset_request, $_asset_response);

    my $_page = $response->as_string;

    my @_extensions = split /[|]/, $assetlist ;

    foreach my $_extension (@_extensions) {

        #while ($_page =~ m{$assettype="([^"]*$_extension)["\?]}g) ##" Iterate over all the matches to this extension
        print "\n $_match$_left_delim([^$_right_delim]*$_extension)[$_right_delim\?] \n";
        while ($_page =~ m{$_match$_left_delim([^$_right_delim]*$_extension)[$_right_delim?]}g) ##" Iterate over all the matches to this extension
        {
            $_start_asset_request = time;

            $_asset_ref = $1;
            #print "$_extension: $_asset_ref\n";

            $_ur_url = URI::URL->new($_asset_ref, $case{url}); ## join the current page url together with the href of the asset
            $_asset_url = $_ur_url->abs; ## determine the absolute address of the asset
            #print "$_asset_url\n\n";
            $_path = $_asset_url->path; ## get the path portion of the asset location
            $_filename = basename($_path); ## get the filename from the path
            $results_stdout .= "  GET Asset [$_filename] ...";

            $_asset_request = HTTP::Request->new('GET',"$_asset_url");
            $cookie_jar->add_cookie_header($_asset_request); ## session cookies will be needed

            $_asset_response = $useragent->request($_asset_request);

            open my $_RESPONSE_AS_FILE, '>', "$output_folder/$_filename" or die "\nCould not open asset file $output_folder/$_filename for writing\n"; #open in clobber mode
            binmode $_RESPONSE_AS_FILE; ## set binary mode
            print {$_RESPONSE_AS_FILE} $_asset_response->content, q{}; ## content just outputs the content, whereas as_string includes the response header
            close $_RESPONSE_AS_FILE or die "\nCould not close asset file\n";

            if ($_type eq 'hrefs') { push @hrefs, $_filename; }
            if ($_type eq 'srcs') { push @srcs, $_filename; }
            if ($_type eq 'bg-images') { push @bg_images, $_filename; }

            $_end_asset_request = time;
            $_asset_latency = (int(1000 * ($_end_asset_request - $_start_asset_request)) / 1000);  ## elapsed time rounded to thousandths
            $results_stdout .= " $_asset_latency s\n";

        } ## end while

    } ## end foreach

    return;
}

#------------------------------------------------------------------
sub save_page {## save the page in a cache to enable auto substitution of hidden fields like __VIEWSTATE and the dynamic component of variable names

    my $_page_action;
    my $_page_index; ## where to save the page in the cache (array of pages)

    ## decide if we want to save this page - needs a method post action
    if ( ($response->as_string =~ m{method="post" action="([^"]*)"}s) || ($response->as_string =~ m{action="([^"]*)" method="post"}s) ) { ## look for the method post action
        $_page_action = $1;
        #$results_stdout .= qq|\n ACTION $_page_action\n|;
    } else {
        #$results_stdout .= qq|\n ACTION none\n\n|;
    }

    if (defined $_page_action) { ## ok, so we save this page

        #$results_stdout .= qq| SAVING $_page_action (BEFORE)\n|;
        $_page_action =~ s{[?].*}{}si; ## we only want everything to the left of the ? mark
        $_page_action =~ s{http.?://}{}si; ## remove http:// and https://
        #$results_stdout .= qq| SAVING $_page_action (AFTER)\n\n|;

        ## we want to overwrite any page with the same name in the cache to prevent weird errors
        my $_match_url = $_page_action;
        $_match_url =~ s{^.*?/}{/}s; ## remove everything to the left of the first / in the path

        ## check to see if we already have this page in the cache, if so, just overwrite it
        $_page_index = _find_page_in_cache($_match_url);

        my $max_cache_size = 5; ## maximum size of the cache (counting starts at 0)
        ## decide if we need a new cache entry, or we must overwrite the oldest page in the cache
        if (not defined $_page_index) { ## the page is not in the cache
            if ($#visited_page_names == $max_cache_size) {## the cache is full - so we need to overwrite the oldest page in the cache
                $_page_index = _find_oldest_page_in_cache();
                #$results_stdout .= qq|\n Overwriting - Oldest Page Index: $_page_index\n\n|; #debug
            } else {
                $_page_index = $#visited_page_names + 1;
                #out $results_stdout .= qq| Index $_page_index available \n\n|;
            }
        }

        ## update the global variables
        $page_update_times[$_page_index] = time; ## save time so we overwrite oldest when cache is full
        $visited_page_names[$_page_index] = $_page_action; ## save page name
        $visited_pages[$_page_index] = $response->as_string; ## save page source

        #$results_stdout .= " Saved $page_update_times[$_page_index]:$visited_page_names[$_page_index] \n\n";

        ## debug - write out the contents of the cache
        #for my $i (0 .. $#visited_page_names) {
        #    $results_stdout .= " $i:$page_update_times[$i]:$visited_page_names[$i] \n"; #debug
        #}
        #$results_stdout .= "\n";

    } # end if - action found

    return;
}

sub _find_oldest_page_in_cache {

    ## assume the first page in the cache is the oldest
    my $_oldest_index = 0;
    my $_oldest_page_time = $page_update_times[0];

    ## if we find an older updated time, use that instead
    for my $i (0 .. $#page_update_times) {
        if ($page_update_times[$i] < $_oldest_page_time) { $_oldest_index = $i; $_oldest_page_time = $page_update_times[$i]; }
    }

    return $_oldest_index;
}

#------------------------------------------------------------------
sub auto_sub {## auto substitution - {DATA} and {NAME}
## {DATA} finds .NET field value from a previous test case and puts it in the postbody - no need for manual parseresponse
## Example: postbody="txtUsername=testuser&txtPassword=123&__VIEWSTATE={DATA}"
##
## {NAME} matches a dynamic component of a field name by looking at the page source of a previous test step
##        This is very useful if the field names change after a recompile, or a Content Management System is in use.
## Example: postbody="txtUsername{NAME}=testuser&txtPassword=123&__VIEWSTATE=456"
##          In this example, the actual user name field may have been txtUsername_xpos5_ypos8_33926509
##

    my ($_post_body, $_post_type, $_post_url) = @_;

    my @_post_fields;

    ## separate the fields
    if ($_post_type eq 'normalpost') {
        @_post_fields = split /\&/, $_post_body ; ## & is separator
    } else {
        ## assumes that double quotes on the outside, internally single qoutes
        ## enhancements needed
        ##   1. subsitute out blank space first between the field separators
        @_post_fields = split /\'\,/, $_post_body ; #separate the fields
    }

    ## debug - print the array
    #$results_stdout .= " \n There are ".($#postfields+1)." fields in the postbody: \n"; #debug
    #for my $_i (0 .. $#_post_fields) {
    #    $results_stdout .= ' Field '.($_i+1).": $_post_fields[$_i] \n";
    #}

    ## work out pagename to use for matching purposes
    $_post_url =~ s{[?].*}{}si; ## we only want everything to the left of the ? mark
    $_post_url =~ s{http.?://}{}si; ## remove http:// and https://
    $_post_url =~ s{^.*?/}{/}s; ## remove everything to the left of the first / in the path
    $results_stdout .= qq| POSTURL $_post_url \n|; #debug

    my $_page_id = _find_page_in_cache($_post_url.q{$});
    if (not defined $_page_id) {
        $_post_url =~ s{^.*/}{/}s; ## remove the path entirely, except for the leading slash
        #$results_stdout .= " TRY WITH PAGE NAME ONLY    : $_post_url".'$'."\n";
        $_page_id = _find_page_in_cache($_post_url.q{$}); ## try again without the full path
    }
    if (not defined $_page_id) {
        $_post_url =~ s{^.*/}{/}s; ## remove the path entirely, except for the page name itself
        #$results_stdout .= " REMOVE PATH                : $_post_url".'$'."\n";
        $_page_id = _find_page_in_cache($_post_url.q{$}); ## try again without the full path
    }
    if (not defined $_page_id) {
        $_post_url =~ s{^.*/}{}s; ## remove the path entirely, except for the page name itself
        #$results_stdout .= " REMOVE LEADING /           : $_post_url".'$'."\n";
        $_page_id = _find_page_in_cache($_post_url.q{$}); ## try again without the full path
    }
    if (not defined $_page_id) {
        #$results_stdout .= " DESPERATE MODE - NO ANCHOR : $_post_url\n";
        _find_page_in_cache($_post_url);
    }

    ## there is heavy use of regex in this sub, we need to ensure they are optimised
    #my $_start_loop_timer = time;

    ## time for substitutions
    if (defined $_page_id) { ## did we find match?
        #$results_stdout .= " ID MATCH $_page_id \n";
        for my $_i (0 .. $#_post_fields) { ## loop through each of the fields being posted
            ## substitute {NAME} for actual
            $_post_fields[$_i] = _substitute_name($_post_fields[$_i], $_page_id, $_post_type);

            ## substitute {DATA} for actual
            $_post_fields[$_i] = _substitute_data($_post_fields[$_i], $_page_id, $_post_type);
        }
    }

    ## done all the substitutions, now put it all together again
    if ($_post_type eq 'normalpost') {
        $_post_body = join q{&}, @_post_fields;
    } else {
        ## assumes that double quotes on the outside, internally single qoutes
        ## enhancements needed
        ##   1. subsitute out blank space first between the field separators
        $_post_body = join q{',}, @_post_fields; #'
    }
    #out $results_stdout .= qq|\n\n POSTBODY is $_post_body \n|;

    #my $_loop_latency = (int(1000 * (time - $_start_loop_timer)) / 1000);  ## elapsed time rounded to thousandths
    ## debug - make sure all the regular expressions are efficient
    #$results_stdout .= qq| Looping took $_loop_latency \n|; #debug

    return $_post_body;
}

sub _substitute_name {
    my ($_post_field, $_page_id, $_post_type) = @_;

    my $_dot_x;
    my $_dot_y;

    ## does the field name end in .x e.g. btnSubmit.x? The .x bit won't be in the saved page
    if ( $_post_field =~ m{[.]x[=']} ) { ## does it end in .x? #'
        #out $results_stdout .= qq| DOTX found in $_post_field \n|;
        $_dot_x = 'true';
        $_post_field =~ s{[.]x}{}; ## get rid of the .x, we'll have to put it back later
    }

    ## does the field name end in .y e.g. btnSubmit.y? The .y bit won't be in the saved page
    if ( $_post_field =~ m/[.]y[=']/ ) { ## does it end in .y? #'
        #out $results_stdout .= qq| DOTY found in $_post_field \n|;
        $_dot_y = 'true';
        $_post_field =~ s{[.]y}{}; ## get rid of the .y, we'll have to put it back later
    }

    ## look for characters to the left and right of {NAME} and save them
    if ( $_post_field =~ m/([^']{0,70}?)[{]NAME[}]([^=']{0,70})/s ) { ## ' was *?, {0,70}? much quicker
        my $_lhs_name = $1;
        my $_rhs_name = $2;

        $_lhs_name =~ s{\$}{\\\$}g; ## protect $ with \$
        $_lhs_name =~ s{[.]}{\\\.}g; ## protect . with \.
        #$results_stdout .= qq| LHS of {NAME}: [$_lhs_name] \n|;

        $_rhs_name =~ s{%24}{\$}g; ## change any encoding for $ (i.e. %24) back to a literal $ - this is what we'll really find in the html source
        $_rhs_name =~ s{\$}{\\\$}g; ## protect the $ with a \ in further regexs
        $_rhs_name =~ s{[.]}{\\\.}g; ## same for the .
        #$results_stdout .= qq| RHS of {NAME}: [$_rhs_name] \n|;

        ## find out what to substitute it with, then do the substitution
        ##
        ## saved page source will contain something like
        ##    <input name="pagebody_3$left_7$txtUsername" id="pagebody_3_left_7_txtUsername" />
        ## so this code will find that {NAME}Username will match pagebody_3$left_7$txt for {NAME}
        if ($visited_pages[$_page_id] =~ m/name=['"]$_lhs_name([^'"]{0,70}?)$_rhs_name['"]/s) { ## "
            my $_name = $1;
            #out $results_stdout .= qq| NAME is $_name \n|;

            ## substitute {NAME} for the actual (dynamic) value
            $_post_field =~ s/{NAME}/$_name/;
            #$results_stdout .= qq| SUBBED_NAME is $_post_field \n|;
        }
    }

    ## did we take out the .x? we need to put it back
    if (defined $_dot_x) {
        if ($_post_type eq 'normalpost') {
            $_post_field =~ s{[=]}{\.x\=};
        } else {
            $_post_field =~ s{['][ ]?\=}{\.x\' \=}; #[ ]? means match 0 or 1 space #'
        }
        #$results_stdout .= qq| DOTX restored to $_post_field \n|;
    }

    ## did we take out the .y? we need to put it back
    if (defined $_dot_y) {
     if ($_post_type eq 'normalpost') {
        $_post_field =~ s{[=]}{\.y\=};
     } else {
        $_post_field =~ s{['][ ]?\=}{\.y\' \=}; #'
     }
        #$results_stdout .= qq| DOTY restored to $_post_field \n|;
    }

    return $_post_field;
}

sub _substitute_data {
    my ($_post_field, $_page_id, $_post_type) = @_;

    my $_target_field;

    if ($_post_type eq 'normalpost') {
        if ($_post_field =~ m/(.{0,70}?)=[{]DATA}/s) {
            $_target_field = $1;
            #$results_stdout .= qq| Normal Field $_field_name has {DATA} \n|; #debug
        }
    }

    if ($_post_type eq 'multipost') {
        if ($_post_field =~ m/['](.{0,70}?)['].{0,70}?[{]DATA}/s) {
            $_target_field = $1;
            #$results_stdout .= qq| Multi Field $_field_name has {DATA} \n|; #debug
        }
    }

    ## find out what to substitute it with, then do the substitution
    if (defined $_target_field) {
        $_target_field =~ s{\$}{\\\$}; ## protect $ with \$ for final substitution
        $_target_field =~ s{[.]}{\\\.}; ## protect . with \. for final substitution
        if ($visited_pages[$_page_id] =~ m/="$_target_field" [^\>]*value="(.*?)"/s) {
            my $_data = $1;
            #$results_stdout .= qq| DATA is $_data \n|; #debug

            ## normal post must be escaped
            if ($_post_type eq 'normalpost') {
                $_data = uri_escape($_data);
                #$results_stdout .= qq| URLESCAPE!! \n|; #debug
            }

            ## substitute in the data
            if ($_post_field =~ s/{DATA}/$_data/) {
                #$results_stdout .= qq| SUBBED_FIELD is $_post_fields[$i] \n|; #debug
            }

        }
    }

    return $_post_field;
}

sub _find_page_in_cache {

    my ($_post_url) = @_;

    ## see if we have stored this page
    if ($visited_page_names[0]) { ## does the array contain at least one entry?
        for my $_i (0 .. $#visited_page_names) {
            if ($visited_page_names[$_i] =~ m/$_post_url/si) { ## can we find the post url within the current saved action url?
            #$results_stdout .= qq| MATCH at position $_i\n|; #debug
            return $_i;
            } else {
                #$results_stdout .= qq| NO MATCH on $_i:$visited_page_names[$_i]\n|; #debug
            }
        }
    } else {
        #$results_stdout .= qq| NO CACHED PAGES! \n|; #debug
    }

    return;
}
#------------------------------------------------------------------
sub httpget {  #send http request and read response

    $request = HTTP::Request->new('GET',"$case{url}");

    #1.42 Moved cookie management up above addheader as per httppost_form_data
    $cookie_jar->add_cookie_header($request);

    addcookie (); ## append additional cookies rather than overwriting with add header

    if ($case{addheader}) {  #add an additional HTTP Header if specified
        my @_add_headers = split /[|]/, $case{addheader} ;  #can add multiple headers with a pipe delimiter
        foreach (@_add_headers) {
            $_ =~ m/(.*): (.*)/;
            if ($1) {$request->header($1 => $2);}  #using HTTP::Headers Class
        }
    }


    $start_timer = time;
    $response = $useragent->request($request);
    $end_timer = time;
    $latency = (int(1000 * ($end_timer - $start_timer)) / 1000);  #elapsed time rounded to thousandths

    $cookie_jar->extract_cookies($response);
    #print $cookie_jar->as_string; print "\n\n";

    save_page (); ## save page in the cache for the auto substitutions

    return;
}

#------------------------------------------------------------------
sub httpdelete {

    httpsend('DELETE');

    return;
}

#------------------------------------------------------------------
sub httppost {

    httpsend('POST');

    return;
}

#------------------------------------------------------------------
sub httpput {

    httpsend('PUT');

    return;
}

#------------------------------------------------------------------
sub httpsend {  # send request based on specified encoding and method (verb)
    my ($_verb) = @_;

    if ($case{posttype}) {
         if (($case{posttype} =~ m{application/x-www-form-urlencoded}) or ($case{posttype} =~ m{application/json})) { httpsend_form_urlencoded($_verb); } ## application/json support
         elsif ($case{posttype} =~ m{multipart/form-data}) { httpsend_form_data($_verb); }
         elsif (($case{posttype} =~ m{text/xml}) or ($case{posttype} =~ m{application/soap+xml})) { httpsend_xml($_verb); }
         else { print {*STDERR} qq|ERROR: Bad Form Encoding Type, I only accept "application/x-www-form-urlencoded", "application/json", "multipart/form-data", "text/xml", "application/soap+xml" \n|; }
       }
    else {
        $case{posttype} = 'application/x-www-form-urlencoded';
        httpsend_form_urlencoded($_verb);  #use "x-www-form-urlencoded" if no encoding is specified
    }

    save_page (); ## for auto substitutions

    return;
}

#------------------------------------------------------------------
sub httpsend_form_urlencoded {  #send application/x-www-form-urlencoded or application/json HTTP request and read response
    my ($_verb) = @_;

    my $_substituted_postbody; ## auto substitution
    $_substituted_postbody = auto_sub("$case{postbody}", 'normalpost', "$case{url}");

    $request = HTTP::Request->new($_verb,"$case{url}");
    $request->content_type("$case{posttype}");
    #$request->content("$case{postbody}");
    $request->content("$_substituted_postbody");

    ## moved cookie management up above addheader as per httppost_form_data
    $cookie_jar->add_cookie_header($request);

    addcookie (); ## append to additional cookies rather than overwriting with add header

    if ($case{addheader}) {  # add an additional HTTP Header if specified
        my @_add_headers = split /[|]/, $case{addheader} ;  #can add multiple headers with a pipe delimiter
        foreach (@_add_headers) {
            $_ =~ m{(.*): (.*)};
            if ($1) {$request->header($1 => $2);}  #using HTTP::Headers Class
        }
        #$case{addheader} = q{}; ## why is this line here? Fails with retry, so commented out
    }

    $start_timer = time;
    $response = $useragent->request($request);
    $end_timer = time;
    $latency = (int(1000 * ($end_timer - $start_timer)) / 1000);  #elapsed time rounded to thousandths

    $cookie_jar->extract_cookies($response);
    #print $cookie_jar->as_string; print "\n\n";

    return;
}

#------------------------------------------------------------------
sub httpsend_xml{  #send text/xml HTTP request and read response
    my ($_verb) = @_;

    my @_parms;
    my $_len;
    #my $_idx;
    my $_field_name;
    my $_field_value;
    my $_sub_name;

    #read the xml file specified in the testcase
    my @_xml_body;
    if ( $case{postbody} =~ m/file=>(.*)/i ) {
        open my $_XML_BODY, '<', slash_me($1) or die "\nError: Failed to open text/xml file $1\n\n";  #open file handle
        @_xml_body = <$_XML_BODY>;  #read the file into an array
        close $_XML_BODY or die "\nCould not close xml file to be posted\n\n";
    }

    if ($case{parms}) { #is there a postbody for this testcase - if so need to subtitute in fields
       @_parms = split /\&/, $case{parms} ; #& is separator
       $_len = @_parms; #number of items in the array
       #out $results_stdout .= qq| \n There are $len fields in the parms \n|;

       #loop through each of the fields and substitute
       foreach my $_idx (1..$_len) {
            $_field_name = q{};
            #out $results_stdout .= qq| \n parms $_idx: $parms[$_idx-1] \n |;
            if ($_parms[$_idx-1] =~ m/(.*?)\=/s) { #we only want everything to the left of the = sign
                $_field_name = $1;
                #out $results_stdout .= qq| fieldname: $_field_name \n|;
            }
            $_field_value = q{};
            if ($_parms[$_idx-1] =~ m/\=(.*)/s) { #we only want everything to the right of the = sign
                $_field_value = $1;
                #out $results_stdout .= qq| fieldvalue: $_field_value \n\n|;
            }

            #make the substitution
            foreach (@_xml_body) {
                #non escaped fields
                $_ =~ s{\<$_field_name\>.*?\<\/$_field_name\>}{\<$_field_name\>$_field_value\<\/$_field_name\>};

                #escaped fields
                $_ =~ s{\&lt;$_field_name\&gt;.*?\&lt;\/$_field_name\&gt;}{\&lt;$_field_name\&gt;$_field_value\&lt;\/$_field_name\&gt;};

                #attributes
                # ([^a-zA-Z]) says there must be a non alpha so that bigid and id and treated separately
                # $1 will put it back - otherwise it'll be eaten
                $_ =~ s{([^a-zA-Z])$_field_name\=\".*?\"}{$1$_field_name\=\"$_field_value\"}; ## no critic(ProhibitEnumeratedClasses)

                #variable substitution
                $_sub_name = $_field_name;
                if ( $_sub_name =~ s{__}{} ) {#if there are double underscores, like __salarymax__ then replace it
                    $_ =~ s{__$_sub_name}{$_field_value}g;
                }

            }

       }

    }

    $request = HTTP::Request->new($_verb, "$case{url}");
    $request->content_type("$case{posttype}");
    $request->content(join q{ }, @_xml_body);  #load the contents of the file into the request body

## moved cookie management up above addheader as per httpsend_form_data
    $cookie_jar->add_cookie_header($request);

    if ($case{addheader}) {  #add an additional HTTP Header if specified
        my @_add_headers = split /[|]/, $case{addheader} ;  #can add multiple headers with a pipe delimiter
        foreach (@_add_headers) {
            $_ =~ m/(.*): (.*)/;
            if ($1) {$request->header($1 => $2);}  #using HTTP::Headers Class
        }
        #$case{addheader} = q{}; ## why is this line here? Fails with retry, so commented out
    }

    $start_timer = time;
    $response = $useragent->request($request);
    $end_timer = time;
    $latency = (int(1000 * ($end_timer - $start_timer)) / 1000);  #elapsed time rounded to thousandths

    $cookie_jar->extract_cookies($response);
    #print $cookie_jar->as_string; print "\n\n";

    return;
}

#------------------------------------------------------------------
sub httpsend_form_data {  #send multipart/form-data HTTP request and read response
    my ($_verb) = @_;

    my $_substituted_postbody; ## auto substitution
    $_substituted_postbody = auto_sub("$case{postbody}", 'multipost', "$case{url}");

    my %_my_content_;
    eval "\%_my_content_ = $_substituted_postbody"; ## no critic(ProhibitStringyEval)
    if ($_verb eq 'POST') {
        $request = POST "$case{url}", Content_Type => "$case{posttype}", Content => \%_my_content_;
    } elsif ($_verb eq 'PUT') {
        $request = PUT "$case{url}", Content_Type => "$case{posttype}", Content => \%_my_content_;
    } else {
        die "HTTP METHOD of DELETE not supported for multipart/form-data \n";
    }
    $cookie_jar->add_cookie_header($request);

    addcookie (); ## append additional cookies rather than overwriting with add header

    if ($case{addheader}) {  #add an additional HTTP Header if specified
        my @_add_headers = split /[|]/, $case{addheader} ;  #can add multiple headers with a pipe delimiter
        foreach (@_add_headers) {
            $_ =~ m/(.*): (.*)/;
            if ($1) {$request->header($1 => $2);}  #using HTTP::Headers Class
        }
    }

    $start_timer = time;
    $response = $useragent->request($request);
    $end_timer = time;
    $latency = (int(1000 * ($end_timer - $start_timer)) / 1000);  #elapsed time rounded to thousandths

    $cookie_jar->extract_cookies($response);

    return;
}

#------------------------------------------------------------------
sub cmd {  ## send terminal command and read response

    my $_combined_response=q{};
    $request = HTTP::Request->new('GET','CMD');
    $start_timer = time;

    for (qw/command command1 command2 command3 command4 command5 command6 command7 command8 command9 command10 command11 command12 command13 command14 command15 command16 command17 command18 command19 command20/) {
        if ($case{$_}) {#perform command
            my $_cmd = $case{$_};
            $_cmd =~ s/\%20/ /g; ## turn %20 to spaces for display in log purposes
            _shell_adjust(\$_cmd);
            #$request = new HTTP::Request('GET',$cmd);  ## pretend it is a HTTP GET request - but we won't actually invoke it
            my $_cmdresp = (`$_cmd 2>\&1`); ## run the cmd through the backtick method - 2>\&1 redirects error output to standard output
            $_combined_response =~ s{$}{<$_> $_cmd </$_>\n$_cmdresp\n\n\n}; ## include it in the response
        }
    }
    $_combined_response =~ s{^}{HTTP/1.1 100 OK\n}; ## pretend this is an HTTP response - 100 means continue
    $response = HTTP::Response->parse($_combined_response); ## pretend the response is a http response - inject it into the object
    $end_timer = time;
    $latency = (int(1000 * ($end_timer - $start_timer)) / 1000);  ## elapsed time rounded to thousandths

    return;
}

#------------------------------------------------------------------
sub _shell_adjust {
    my ($_parm) = @_;

    # {SLASH} will be a back slash if running on Windows, otherwise a forward slash
    if ($is_windows) {
        ${$_parm} =~ s{^[.]/}{.\\};
        ${$_parm} =~ s/{SLASH}/\\/g;
        ${$_parm} =~ s/{SHELL_ESCAPE}/\^/g;
    } else {
        ${$_parm} =~ s{^.\\}{./};
        ${$_parm} =~ s{\\}{\\\\}g; ## need to double back slashes in Linux, otherwise they vanish (unlike Windows shell)
        ${$_parm} =~ s/{SLASH}/\//g;
        ${$_parm} =~ s/{SHELL_ESCAPE}/\\/g;
    }

    return;
}

#------------------------------------------------------------------
sub commandonerror {  ## command only gets run on error - it does not count as part of the test
                      ## intended for scenarios when you want to give something a kick - e.g. recycle app pool

    my $_combined_response = $response->as_string; ## take the existing test response

    for (qw/commandonerror/) {
        if ($case{$_}) {## perform command

            my $_cmd = $case{$_};
            $_cmd =~ s/\%20/ /g; ## turn %20 to spaces for display in log purposes
            _shell_adjust(\$_cmd);
            my $_cmdresp = (`$_cmd 2>\&1`); ## run the cmd through the backtick method - 2>\&1 redirects error output to standard output
            $_combined_response =~ s{$}{<$_>$_cmd</$_>\n$_cmdresp\n\n\n}; ## include it in the response
        }
    }
    $response = HTTP::Response->parse($_combined_response); ## put the test response along with the command on error response back in the response

    return;
}


#------------------------------------------------------------------
sub searchimage {  ## search for images in the actual result

    my $_unmarked = 'true';

    for (qw/searchimage searchimage1 searchimage2 searchimage3 searchimage4 searchimage5/) {
        if ($case{$_}) {
            if (-e "$case{$_}") { ## imageinimage.py bigimage smallimage markimage
                if ($_unmarked eq 'true') {
                   copy "$opt_publish_full$testnum_display$jumpbacks_print$retries_print.png", "$opt_publish_full$testnum_display$jumpbacks_print$retries_print-marked.png";
                   $_unmarked = 'false';
                }

                my $_search_image_script = slash_me('plugins/search-image.py');
                my $_image_in_image_result = (`$_search_image_script $opt_publish_full$testnum_display$jumpbacks_print$retries_print.png "$case{$_}" $opt_publish_full$testnum_display$jumpbacks_print$retries_print-marked.png`);

                $_image_in_image_result =~ m/primary confidence (\d+)/s;
                my $_primary_confidence;
                if ($1) {$_primary_confidence = $1;}

                $_image_in_image_result =~ m/alternate confidence (\d+)/s;
                my $_alternate_confidence;
                if ($1) {$_alternate_confidence = $1;}

                $_image_in_image_result =~ m/min_loc (.*?)X/s;
                my $_location;
                if ($1) {$_location = $1;}

                $results_xml .= qq|            <$_>\n|;
                $results_xml .= qq|                <assert>$case{$_}</assert>\n|;

                if ($_image_in_image_result =~ m/was found/s) { ## was the image found?
                    $results_html .= qq|<span class="found">Found image: $case{$_}</span><br />\n|;
                    $results_xml .= qq|                <success>true</success>\n|;
                    $results_stdout .= "Found: $case{$_}\n   $_primary_confidence primary confidence\n   $_alternate_confidence alternate confidence\n   $_location location\n";
                    $passed_count++;
                    $retry_passed_count++;
                }
                else { #the image was not found within the bigger image
                    $results_html .= qq|<span class="notfound">Image not found: $case{$_}</span><br />\n|;
                    $results_xml .= qq|                <success>false</success>\n|;
                    $results_stdout .= "Not found: $case{$_}\n   $_primary_confidence primary confidence\n   $_alternate_confidence alternate confidence\n   $_location location\n";
                    $failed_count++;
                    $retry_failed_count++;
                    $is_failure++;
                }
                $results_xml .= qq|            </$_>\n|;
            } else {#We were not able to find the image to search for
                $results_html .= qq|<span class="notfound">SearchImage error - was the file path correct? $case{$_}</span><br />\n|;
                $results_xml .= qq|                <success>false</success>\n|;
                $results_stdout .= "SearchImage error - was the file path correct? $case{$_}\n";
                $failed_count++;
                $retry_failed_count++;
                $is_failure++;
            }
        } ## end first if
    } ## end for

    if ($_unmarked eq 'false') {
       #keep an unmarked image, make the marked the actual result
       move "$opt_publish_full$testnum_display$jumpbacks_print$retries_print.png", "$opt_publish_full$testnum_display$jumpbacks_print$retries_print-unmarked.png";
       move "$opt_publish_full$testnum_display$jumpbacks_print$retries_print-marked.png", "$opt_publish_full$testnum_display$jumpbacks_print$retries_print.png";
    }

    return;
} ## end sub

#------------------------------------------------------------------
sub decode_quoted_printable {

    require MIME::QuotedPrint;

	if ($case{decodequotedprintable}) {
		 my $_decoded = MIME::QuotedPrint::decode_qp($response->as_string); ## decode the response output
		 $response = HTTP::Response->parse($_decoded); ## inject it back into the response
	}

    return;
}

#------------------------------------------------------------------
sub verify {  #do verification of http response and print status to HTML/XML/STDOUT/UI

    searchimage(); ## search for images within actual screen or page grab

    ## reset the global variables
    $assertion_skips = 0;
    $assertion_skips_message = q{}; ## support tagging an assertion as disabled with a message

    ## auto assertions
    if (!$case{ignoreautoassertions}) {
        ## autoassertion, autoassertion1, ..., autoassertion4, ..., autoassertion10000 (or more)
        _verify_autoassertion();
    }

    ## smart assertions
    if (!$case{ignoresmartassertions}) {
        _verify_smartassertion();
    }

    ## verify positive
    ## verifypositive, verifypositive1, ..., verifypositive25, ..., verifypositive10000 (or more)
    _verify_verifypositive();

    ## verify negative
    ## verifynegative, verifynegative1, ..., verifynegative25, ..., verifynegative10000 (or more)
    _verify_verifynegative();

    ## assert count
    _verify_assertcount();

     if ($case{verifyresponsetime}) { ## verify that the response time is less than or equal to given amount in seconds
         if ($latency <= $case{verifyresponsetime}) {
                $results_html .= qq|<span class="pass">Passed Response Time Verification</span><br />\n|;
                $results_xml .= qq|            <verifyresponsetime-success>true</verifyresponsetime-success>\n|;
                $results_stdout .= "Passed Response Time Verification \n";
                $passed_count++;
                $retry_passed_count++;
         }
         else {
                $results_html .= qq|<span class="fail">Failed Response Time Verification - should be at most $case{verifyresponsetime}, got $latency</span><br />\n|;
                $results_xml .= qq|            <verifyresponsetime-success>false</verifyresponsetime-success>\n|;
                $results_xml .= qq|            <verifyresponsetime-message>Latency should be at most $case{verifyresponsetime} seconds</verifyresponsetime-message>\n|;
                $results_stdout .= "Failed Response Time Verification - should be at most $case{verifyresponsetime}, got $latency \n";
                $failed_count++;
                $retry_failed_count++;
                $is_failure++;
        }
     }

    if ($case{verifyresponsecode}) {
        if ($case{verifyresponsecode} == $response->code()) { #verify returned HTTP response code matches verifyresponsecode set in test case
            $results_html .= qq|<span class="pass">Passed HTTP Response Code Verification </span><br />\n|;
            $results_xml .= qq|            <verifyresponsecode-success>true</verifyresponsecode-success>\n|;
            $results_xml .= qq|            <verifyresponsecode-message>Passed HTTP Response Code Verification</verifyresponsecode-message>\n|;
            $results_stdout .= qq|Passed HTTP Response Code Verification \n|;
            $passed_count++;
            $retry_passed_count++;
            $retry=0; ## we won't retry if the response code is invalid since it will probably never work
            }
        else {
            $results_html .= '<span class="fail">Failed HTTP Response Code Verification (received ' . $response->code() .  qq|, expecting $case{verifyresponsecode})</span><br />\n|;
            $results_xml .= qq|            <verifyresponsecode-success>false</verifyresponsecode-success>\n|;
            $results_xml .=   '            <verifyresponsecode-message>Failed HTTP Response Code Verification (received ' . $response->code() .  qq|, expecting $case{verifyresponsecode})</verifyresponsecode-message>\n|;
            $results_stdout .= 'Failed HTTP Response Code Verification (received ' . $response->code() .  qq|, expecting $case{verifyresponsecode}) \n|;
            $failed_count++;
            $retry_failed_count++;
            $is_failure++;
        }
    }
    else { #verify http response code is in the 100-399 range
        if (not $case{ignorehttpresponsecode}) {
            if (($response->as_string() =~ /HTTP\/1.(0|1) (1|2|3)/i) || $case{ignorehttpresponsecode}) {  #verify existance of string in response - unless we are ignore error codes
                $results_html .= qq|<span class="pass">Passed HTTP Response Code Verification</span><br />\n|;
                $results_xml .= qq|            <verifyresponsecode-success>true</verifyresponsecode-success>\n|;
                $results_xml .= qq|            <verifyresponsecode-message>Passed HTTP Response Code Verification</verifyresponsecode-message>\n|;
                $results_stdout .= qq|Passed HTTP Response Code Verification \n|;
                #succesful response codes: 100-399
                $passed_count++;
                $retry_passed_count++;
            }
            else {
                $response->as_string() =~ /(HTTP\/1.)(.*)/i;
                if ($1) {  #this is true if an HTTP response returned
                    $results_html .= qq|<span class="fail">Failed HTTP Response Code Verification ($1$2)</span><br />\n|; #($1$2) is HTTP response code
                    $results_xml .= qq|            <verifyresponsecode-success>false</verifyresponsecode-success>\n|;
                    $results_xml .= qq|            <verifyresponsecode-message>($1$2)</verifyresponsecode-message>\n|;
                    $results_stdout .= "Failed HTTP Response Code Verification ($1$2) \n"; #($1$2) is HTTP response code
                }
                else {  #no HTTP response returned.. could be error in connection, bad hostname/address, or can not connect to web server
                    $results_html .= qq|<span class="fail">Failed - No Response</span><br />\n|; #($1$2) is HTTP response code
                    $results_xml .= qq|            <verifyresponsecode-success>false</verifyresponsecode-success>\n|;
                    $results_xml .= qq|            <verifyresponsecode-message>Failed - No Response</verifyresponsecode-message>\n|;
                    $results_stdout .= "Failed - No Response \n"; #($1$2) is HTTP response code
                }
                $failed_count++;
                $retry_failed_count++;
                $is_failure++;
            }
        } else {
            $results_stdout .= qq|Ignored HTTP Response Code Verification \n|;
        }
    }

    if ($assertion_skips > 0) {
        $total_assertion_skips = $total_assertion_skips + $assertion_skips;
        $results_xml .= qq|            <assertionskips>true</assertionskips>\n|;
        $results_xml .= qq|            <assertionskips-message>$assertion_skips_message</assertionskips-message>\n|;
    }

    if (($case{commandonerror}) && ($is_failure > 0)) { ## if the test case failed, check if we want to run a command to help sort out any problems
        commandonerror();
    }

    return;
}

sub _verify_autoassertion {

    foreach my $_config_attribute ( sort keys %{ $user_config->{autoassertions} } ) {
        if ( (substr $_config_attribute, 0, 13) eq 'autoassertion' ) {
            my $_verify_number = $_config_attribute; ## determine index verifypositive index
            $_verify_number =~ s/^autoassertion//g; ## remove autoassertion from string
            if (!$_verify_number) {$_verify_number = '0';} #In case of autoassertion, need to treat as 0
            my @_verifyparms = split /[|][|][|]/, $user_config->{autoassertions}{$_config_attribute} ; #index 0 contains the actual string to verify, 1 the message to show if the assertion fails, 2 the tag that it is a known issue
            if ($_verifyparms[2]) { ## assertion is being ignored due to known production bug or whatever
                $results_html .= qq|<span class="skip">Skipped Auto Assertion $_verify_number - $_verifyparms[2]</span><br />\n|;
                $results_stdout .= "Skipped Auto Assertion $_verify_number - $_verifyparms[2] \n";
                $assertion_skips++;
                $assertion_skips_message = $assertion_skips_message . '[' . $_verifyparms[2] . ']';
            }
            else {
                my $_results_xml = qq|            <$_config_attribute>\n|;
                $_results_xml .= qq|                <assert>$_verifyparms[0]</assert>\n|;
                #$results_stdout .= "$_verifyparms[0]\n"; ##DEBUG
                if ($response->as_string() =~ m/$_verifyparms[0]/si) {  ## verify existence of string in response
                    #$results_html .= qq|<span class="pass">Passed Auto Assertion</span><br />\n|; ## Do not print out all the auto assertion passes
                    $_results_xml .= qq|                <success>true</success>\n|;
                    #$results_stdout .= "Passed Auto Assertion \n"; ## Do not print out all the auto assertion passes
                    #$results_stdout .= $_verify_number." Passed Auto Assertion \n"; ##DEBUG
                    $passed_count++;
                    $retry_passed_count++;
                }
                else {
                    $results_html .= qq|<span class="fail">Failed Auto Assertion:</span>$_verifyparms[0]<br />\n|;
                    $_results_xml .= qq|                <success>false</success>\n|;
                    if ($_verifyparms[1]) { ## is there a custom assertion failure message?
                       $results_html .= qq|<span class="fail">$_verifyparms[1]</span><br />\n|;
                       $_results_xml .= qq|                <message>$_verifyparms[1]</message>\n|;
                    }
                    $results_stdout .= "Failed Auto Assertion \n";
                    if ($_verifyparms[1]) {
                       $results_stdout .= "$_verifyparms[1] \n";
                    }
                    $failed_count++;
                    $retry_failed_count++;
                    $is_failure++;
                }
                $_results_xml .= qq|            </$_config_attribute>\n|;

                # only log the auto assertion if it failed
                if ($_results_xml =~ m/success.false/) {
                    $results_xml .= $_results_xml;
                }
            }
        }
    }

    return;
}

sub _verify_smartassertion {

    foreach my $_config_attribute ( sort keys %{ $user_config->{smartassertions} } ) {
        if ( (substr $_config_attribute, 0, 14) eq 'smartassertion' ) {
            my $_verify_number = $_config_attribute; ## determine index verifypositive index
            $_verify_number =~ s/^smartassertion//g; ## remove smartassertion from string
            if (!$_verify_number) {$_verify_number = '0';} #In case of smartassertion, need to treat as 0
            my @_verifyparms = split /[|][|][|]/, $user_config->{smartassertions}{$_config_attribute} ; #index 0 contains the pre-condition assertion, 1 the actual assertion, 3 the tag that it is a known issue
            if ($_verifyparms[3]) { ## assertion is being ignored due to known production bug or whatever
                $results_html .= qq|<span class="skip">Skipped Smart Assertion $_verify_number - $_verifyparms[3]</span><br />\n|;
                $results_stdout .= "Skipped Smart Assertion $_verify_number - $_verifyparms[2] \n";
                $assertion_skips++;
                $assertion_skips_message = $assertion_skips_message . '[' . $_verifyparms[2] . ']';
                return;
            }

            ## note the return statement in the previous condition, this code is executed if the assertion is not being skipped
            #$results_stdout .= "$_verifyparms[0]\n"; ##DEBUG
            if ($response->as_string() =~ m/$_verifyparms[0]/si) {  ## pre-condition for smart assertion - first regex must pass
                $results_xml .= "            <$_config_attribute>\n";
                $results_xml .= '                <assert>'._sub_xml_special($_verifyparms[0])."</assert>\n";
                if ($response->as_string() =~ m/$_verifyparms[1]/si) {  ## verify existence of string in response
                    #$results_html .= qq|<span class="pass">Passed Smart Assertion</span><br />\n|; ## Do not print out all the auto assertion passes
                    $results_xml .= qq|                <success>true</success>\n|;
                    #$results_stdout .= "Passed Smart Assertion \n"; ## Do not print out the Smart Assertion passes
                    $passed_count++;
                    $retry_passed_count++;
                }
                else {
                    $results_html .= qq|<span class="fail">Failed Smart Assertion:</span>$_verifyparms[0]<br />\n|;
                    $results_xml .= qq|                <success>false</success>\n|;
                    if ($_verifyparms[2]) { ## is there a custom assertion failure message?
                       $results_html .= qq|<span class="fail">$_verifyparms[2]</span><br />\n|;
                       $results_xml .= '                <message>'._sub_xml_special($_verifyparms[2])."</message>\n";
                    }
                    $results_stdout .= 'Failed Smart Assertion';
                    if ($_verifyparms[2]) {
                       $results_stdout .= ": $_verifyparms[2]";
                    }
                    $results_stdout .= "\n";
                    $failed_count++;
                    $retry_failed_count++;
                    $is_failure++;
                }
                $results_xml .= qq|            </$_config_attribute>\n|;
            } ## end if - is pre-condition for smart assertion met?
        }
    }

    return;
}

sub _verify_verifypositive {

    foreach my $_case_attribute ( sort keys %{ $xml_test_cases->{case}->{$testnum} } ) {
        if ( (substr $_case_attribute, 0, 14) eq 'verifypositive' ) {
            my $_verify_number = $_case_attribute; ## determine index verifypositive index
            $_verify_number =~ s/^verifypositive//g; ## remove verifypositive from string
            if (!$_verify_number) {$_verify_number = '0';} #In case of verifypositive, need to treat as 0
            my @_verifyparms = split /[|][|][|]/, $case{$_case_attribute} ; #index 0 contains the actual string to verify, 1 the message to show if the assertion fails, 2 the tag that it is a known issue
            my $_fail_fast = _is_fail_fast(\$_verifyparms[0]); ## will strip off leading fail fast! if present
            if ($_verifyparms[2]) { ## assertion is being ignored due to known production bug or whatever
                $results_html .= qq|<span class="skip">Skipped Positive Verification $_verify_number - $_verifyparms[2]</span><br />\n|;
                $results_stdout .= "Skipped Positive Verification $_verify_number - $_verifyparms[2] \n";
                $assertion_skips++;
                $assertion_skips_message = $assertion_skips_message . '[' . $_verifyparms[2] . ']';
            }
            else {
                $results_xml .= "            <$_case_attribute>\n";
                $results_xml .= '                <assert>'._sub_xml_special($_verifyparms[0])."</assert>\n";
                if ($response->as_string() =~ m/$_verifyparms[0]/si) {  ## verify existence of string in response
                    $results_html .= qq|<span class="pass">Passed Positive Verification</span><br />\n|;
                    $results_xml .= qq|                <success>true</success>\n|;
                    $results_stdout .= "Passed Positive Verification \n";
                    #$results_stdout .= $_verify_number." Passed Positive Verification \n"; ##DEBUG
                    $passed_count++;
                    $retry_passed_count++;
                }
                else {
                    $results_html .= qq|<span class="fail">Failed Positive Verification:</span>$_verifyparms[0]<br />\n|;
                    $results_xml .= qq|                <success>false</success>\n|;
                    if ($_verifyparms[1]) { ## is there a custom assertion failure message?
                       $results_html .= qq|<span class="fail">$_verifyparms[1]</span><br />\n|;
                       $results_xml .= '                <message>'._sub_xml_special($_verifyparms[1])."</message>\n";
                    }
                    $results_stdout .= "Failed Positive Verification $_verify_number\n";
                    if ($_verifyparms[1]) {
                       $results_stdout .= "$_verifyparms[1] \n";
                    }
                    $failed_count++;
                    $retry_failed_count++;
                    $is_failure++;
                    if ($_fail_fast) {
                        if ($retry > 0) { $results_stdout .= "==> Won't retry - a fail fast was invoked \n"; }
                        $retry=0; ## we won't retry if a fail fast was invoked
                        $fast_fail_invoked = 'true';
                    }
                }
                $results_xml .= qq|            </$_case_attribute>\n|;
            }
        }
    }

    return;
}

sub _verify_verifynegative {

    foreach my $_case_attribute ( sort keys %{ $xml_test_cases->{case}->{$testnum} } ) {
        if ( (substr $_case_attribute, 0, 14) eq 'verifynegative' ) {
            my $_verify_number = $_case_attribute; ## determine index verifypositive index
            #$results_stdout .= "$_case_attribute\n"; ##DEBUG
            $_verify_number =~ s/^verifynegative//g; ## remove verifynegative from string
            if (!$_verify_number) {$_verify_number = '0';} ## in case of verifypositive, need to treat as 0
            my @_verifyparms = split /[|][|][|]/, $case{$_case_attribute} ; #index 0 contains the actual string to verify
            my $_fail_fast = _is_fail_fast(\$_verifyparms[0]); ## will strip off leading !!! if present
            if ($_verifyparms[2]) { ## assertion is being ignored due to known production bug or whatever
                $results_html .= qq|<span class="skip">Skipped Negative Verification $_verify_number - $_verifyparms[2]</span><br />\n|;
                $results_stdout .= "Skipped Negative Verification $_verify_number - $_verifyparms[2] \n";
                $assertion_skips++;
                $assertion_skips_message = $assertion_skips_message . '[' . $_verifyparms[2] . ']';
            }
            else {
                $results_xml .= "            <$_case_attribute>\n";
                $results_xml .= '                <assert>'._sub_xml_special($_verifyparms[0])."</assert>\n";
                if ($response->as_string() =~ m/$_verifyparms[0]/si) {  #verify existence of string in response
                    $results_html .= qq|<span class="fail">Failed Negative Verification</span><br />\n|;
                    $results_xml .= qq|                <success>false</success>\n|;
                    if ($_verifyparms[1]) {
                       $results_html .= qq|<span class="fail">$_verifyparms[1]</span><br />\n|;
                         $results_xml .= '            <message>'._sub_xml_special($_verifyparms[1])."</message>\n";
                    }
                    $results_stdout .= "Failed Negative Verification $_verify_number\n";
                    if ($_verifyparms[1]) {
                       $results_stdout .= "$_verifyparms[1] \n";
                    }
                    $failed_count++;
                    $retry_failed_count++;
                    $is_failure++;
                    if ($_fail_fast) {
                        if ($retry > 0) { $results_stdout .= "==> Won't retry - a fail fast was invoked \n"; }
                        $retry=0; ## we won't retry if a fail fast was invoked
                        $fast_fail_invoked = 'true';
                    }
                }
                else {
                    $results_html .= qq|<span class="pass">Passed Negative Verification</span><br />\n|;
                    $results_xml .= qq|            <success>true</success>\n|;
                    $results_stdout .= "Passed Negative Verification \n";
                    $passed_count++;
                    $retry_passed_count++;
                }
                $results_xml .= qq|            </$_case_attribute>\n|;
            }
        }
    }

    return;
}


sub _is_fail_fast {
    my ($_assertion) = @_;

    ## since a reference to the original variable has been passed, it will be stripped of the leading !!! if present
    if ( ${$_assertion} =~ s/^fail fast!// ) {
        return 1;
    }

    return;
}

sub _verify_assertcount {

    foreach my $_case_attribute ( sort keys %{ $xml_test_cases->{case}->{$testnum} } ) {
        if ( (substr $_case_attribute, 0, 11) eq 'assertcount' ) {
            my $_verify_number = $_case_attribute; ## determine index verifypositive index
            #$results_stdout .= "$_case_attribute\n"; ##DEBUG
            $_verify_number =~ s/^assertcount//g; ## remove assertcount from string
            if (!$_verify_number) {$_verify_number = '0';} ## in case of verifypositive, need to treat as 0
            my @_verify_count_parms = split /[|][|][|]/, $case{$_case_attribute} ;
            my $_count = 0;
            my $_temp_string=$response->as_string(); #need to put in a temporary variable otherwise it gets stuck in infinite loop

            while ($_temp_string =~ m/$_verify_count_parms[0]/ig) { $_count++;} ## count how many times string is found

            if ($_verify_count_parms[3]) { ## assertion is being ignored due to known production bug or whatever
                $results_html .= qq|<span class="skip">Skipped Assertion Count $_verify_number - $_verify_count_parms[3]</span><br />\n|;
                $results_stdout .= "Skipped Assertion Count $_verify_number - $_verify_count_parms[2] \n";
                $assertion_skips++;
                $assertion_skips_message = $assertion_skips_message . '[' . $_verify_count_parms[2] . ']';
            }
            else {
                if ($_count == $_verify_count_parms[1]) {
                    $results_html .= qq|<span class="pass">Passed Count Assertion of $_verify_count_parms[1]</span><br />\n|;
                    $results_xml .= qq|            <$_case_attribute-success>true</$_case_attribute-success>\n|;
                    $results_stdout .= "Passed Count Assertion of $_verify_count_parms[1] \n";
                    $passed_count++;
                    $retry_passed_count++;
                }
                else {
                    $results_xml .= qq|            <$_case_attribute-success>false</$_case_attribute-success>\n|;
                    if ($_verify_count_parms[2]) {## if there is a custom message, write it out
                        $results_html .= qq|<span class="fail">Failed Count Assertion of $_verify_count_parms[1], got $_count</span><br />\n|;
                        $results_html .= qq|<span class="fail">$_verify_count_parms[2]</span><br />\n|;
                        $results_xml .= qq|            <$_case_attribute-message>|._sub_xml_special($_verify_count_parms[2]).qq| [got $_count]</$_case_attribute-message>\n|;
                    }
                    else {# we make up a standard message
                        $results_html .= qq|<span class="fail">Failed Count Assertion of $_verify_count_parms[1], got $_count</span><br />\n|;
                        $results_xml .= qq|            <$_case_attribute-message>Failed Count Assertion of $_verify_count_parms[1], got $_count</$_case_attribute-message>\n|;
                    }
                    $results_stdout .= "Failed Count Assertion of $_verify_count_parms[1], got $_count \n";
                    if ($_verify_count_parms[2]) {
                        $results_stdout .= "$_verify_count_parms[2] \n";
                    }
                    $failed_count++;
                    $retry_failed_count++;
                    $is_failure++;
                } ## end else _verifycountparms[2]
            } ## end else _verifycountparms[3]
        } ## end if assertcount
    } ## end foreach

    return;
}
#------------------------------------------------------------------
sub parseresponse {  #parse values from responses for use in future request (for session id's, dynamic URL rewriting, etc)

    my ($_response_to_parse, @_parse_args);
    my ($_left_boundary, $_right_boundary, $_escape);

    foreach my $_case_attribute ( sort keys %{ $xml_test_cases->{case}->{$testnum} } ) {

        if ( (substr $_case_attribute, 0, 13) eq 'parseresponse' ) {

            @_parse_args = split /[|]/, $case{$_case_attribute} ;

            $_left_boundary = $_parse_args[0]; $_right_boundary = $_parse_args[1]; $_escape = $_parse_args[2];

            $parsedresult{$_case_attribute} = undef; ## clear out any old value first

            $_response_to_parse = $response->as_string;

            if ($_right_boundary eq 'regex') {## custom regex feature
                if ($_response_to_parse =~ m/$_left_boundary/s) {
                    $parsedresult{$_case_attribute} = $1;
                }
            } else {
                if ($_response_to_parse =~ m/$_left_boundary(.*?)$_right_boundary/s) {
                    $parsedresult{$_case_attribute} = $1;
                }
            }

            if ($_escape) {
                ## convert special characters into %20 and so on
                if ($_escape eq 'escape') {
                    $parsedresult{$_case_attribute} = uri_escape($parsedresult{$_case_attribute});
                }

                ## decode html entities - e.g. convert &amp; to & and &lt; to <
                if ($_escape eq 'decode') {
                    _decode_html_entities($_case_attribute);
                }

                ## quote meta characters so they will be treated as literal in regex
                if ($_escape eq 'quotemeta') {
                    $parsedresult{$_case_attribute} = quotemeta $parsedresult{$_case_attribute};
                }
            }

            #print "\n\nParsed String: $parsedresult{$_}\n\n";
        }
    }

    return;
}

#------------------------------------------------------------------
sub _decode_html_entities {
    my ($_case_attribute) = @_;

    require HTML::Entities;

    $parsedresult{$_case_attribute} = HTML::Entities::decode_entities($parsedresult{$_case_attribute});

    return;
}

#------------------------------------------------------------------
sub slash_me {
    my ($_string) = @_;

    if ($is_windows) {
        $_string =~ s{/}{\\}g;
    } else {
        $_string =~ s{\\}{/}g;
    }

    return $_string;
}

#------------------------------------------------------------------
sub process_config_file { #parse config file and grab values it sets

    my $_config_file_path;

    #process the config file
    if ($opt_configfile) {  #if -c option was set on command line, use specified config file
        $_config_file_path = slash_me($opt_configfile);
    } else {
        $_config_file_path = 'config.xml';
        $opt_configfile = 'config.xml'; ## we have defaulted to config.xml in the current folder
    }

    if (-e "$_config_file_path") {  #if we have a config file, use it
        $user_config = XMLin("$_config_file_path"); ## Parse as XML for the user defined config
    } else {
        die "\nNo config file specified and no config.xml found in current working directory\n\n";
    }

    if (($#ARGV + 1) > 2) {  #too many command line args were passed
        die "\nERROR: Too many arguments\n\n";
    }

    if (($#ARGV + 1) < 1) {  #no command line args were passed
        #if testcase filename is not passed on the command line, use files in config.xml

        if ($user_config->{testcasefile}) {
            $current_case_file = slash_me($user_config->{testcasefile});
        } else {
            die "\nERROR: I can't find any test case files to run.\nYou must either use a config file or pass a filename."; ## no critic(RequireCarping)
        }

    }

    elsif (($#ARGV + 1) == 1) {  #one command line arg was passed
        #use testcase filename passed on command line (config.xml is only used for other options)
        $current_case_file = slash_me($ARGV[0]);  #first commandline argument is the test case file
    }

    #grab values for constants in config file:
    for my $_config_const (qw/baseurl baseurl1 baseurl2 proxy timeout globalretry globaljumpbacks autocontrolleronly/) {
        if ($user_config->{$_config_const}) {
            $config{$_config_const} = $user_config->{$_config_const};
            #print "\n$_ : $config{$_} \n\n";
        }
    }

    if ($user_config->{httpauth}) {
        if ( ref($user_config->{httpauth}) eq 'ARRAY') {
            #print "We have an array of httpauths\n";
            for my $_auth ( @{ $user_config->{httpauth} } ) { ## $user_config->{httpauth} is an array
                _push_httpauth ($_auth);
            }
        } else {
            #print "Not an array - we just have one httpauth\n";
            _push_httpauth ($user_config->{httpauth});
        }
    }

    if (not defined $config{globaljumpbacks}) { ## default the globaljumpbacks if it isn't in the config file
        $config{globaljumpbacks} = 20;
    }

    if ($opt_ignoreretry) { ##
        $config{globalretry} = -1;
        $config{globaljumpbacks} = 0;
    }

    # find the name of the output folder only i.e. not full path - OS safe
    my $_abs_output_full = File::Spec->rel2abs( $output );
    $concurrency =  basename ( dirname($_abs_output_full) );

    $outsum = unpack '%32C*', $output; ## checksum of output directory name - for concurrency
    #print "outsum $outsum \n";

    if (defined $user_config->{ports_variable}) {
        if ($user_config->{ports_variable} eq 'convert_back') {
            $convert_back_ports = 'true';
        }

        if ($user_config->{ports_variable} eq 'null') {
            $convert_back_ports_null = 'true';
        }
    }

    if (defined $user_config->{reporttype}) {
        $report_type = lc $user_config->{reporttype};
        if ($report_type ne 'standard') {
            $opt_no_output = 'true'; ## no standard output for plugins like nagios
        }
    }


    my $_os;
    if ($is_windows) { $_os = 'windows'; }
    $_os //= 'linux';
    
    if (defined $user_config->{$_os}->{'chromedriver-binary'}) {
        $opt_chromedriver_binary //= $user_config->{$_os}->{'chromedriver-binary'}; # default to value from config file if present
    }

    if (defined $user_config->{$_os}->{'selenium-binary'}) {
        $opt_selenium_binary //= $user_config->{$_os}->{'selenium-binary'};
    }

    return;
}

sub _push_httpauth {
    my ($_auth) = @_;

    my $_delimiter = quotemeta substr $_auth,0,1;
    my $_err_delim = substr $_auth,0,1;

    #print "\nhttpauth:$auth\n";
    my @_auth_entry = split /$_delimiter/, $_auth;
    if ($#_auth_entry != 5) {
        print {*STDERR} "\n$_auth\nError: httpauth should have 5 fields delimited by the first character [$_err_delim]\n\n";
    }
    else {
        push @http_auth, [@_auth_entry];
    }

    return;
}

#------------------------------------------------------------------
sub _sub_xml_special {
    my ($_clean) = @_;

    $_clean =~ s/&/{AMPERSAND}/g;
    $_clean =~ s/</{LESSTHAN}/g;
    $_clean =~ s/>/{GREATERTHAN}/g;

    return $_clean;
}

#------------------------------------------------------------------
sub read_test_case_file {

    my $_xml = read_file($current_case_file);

    # substitute in the included test step files
    $_xml =~ s{<include[^>]*?
               id[ ]*=[ ]*["'](\d*)["']                 # ' # id = "10"
               [^>]*?
               file[ ]*=[ ]*["']([^"']*)["']            # file = "tests\helpers\setup\create_job_ad.xml"
               [^>]*>
               }{_include_file($2,$1,$&)}gsex;          # the actual file content

    # for convenience, WebInject allows ampersand and less than to appear in xml data, so this needs to be masked
    $_xml =~ s/&/{AMPERSAND}/g;
    while ( $_xml =~ s/\w\s*=\s*"[^"]*\K<(?!case)([^"]*")/{LESSTHAN}$1/sg ) {}
    while ( $_xml =~ s/\w\s*=\s*'[^']*\K<(?!case)([^']*')/{LESSTHAN}$1/sg ) {}
    #$_xml =~ s/\\</{LESSTHAN}/g;

    $case_count = 0;
    while ($_xml =~ /<case/g) {  #count test cases based on '<case' tag
        $case_count++;
    }

    if ($case_count == 1) {
        $_xml =~ s/<\/testcases>/<case id="99999999" description1="dummy test case"\/><\/testcases>/;  #add dummy test case to end of file
    }

    # see the final test case file after all alerations for debug purposes
    #write_file('final_test_case_file_'.int(rand(999)).'.xml', $_xml);

    # here we parse the xml file in an eval, and capture any error returned (in $@)
    my $_message;
    $xml_test_cases = eval { XMLin($_xml, VarAttr => 'varname') };

    if ($@) {
        $_message = $@;
        $_message =~ s{XML::Simple.*\n}{}g; # remove misleading line number reference
        my $_file_name_full = _write_failed_xml($_xml);
        die "\n".$_message."\nRefer to built test file: $_file_name_full\n";
    }

    $testfile_contains_selenium = _does_testfile_contain_selenium(\$_xml);
    #print "Contains Selenium:$testfile_contains_selenium\n";

    return;
}

#------------------------------------------------------------------
sub _write_failed_xml {
    my ($_xml) = @_;

    ## output location might include a prefix that we do not want
    my $_output_folder = dirname($output.'dummy');

    my $_path = slash_me ($_output_folder.'/parse_error');

    File::Path::make_path ( $_path );

    my $_rand = int rand 999;
    my $_file_name = 'test_file_'.$_rand.'.xml';
    my $_file_name_full = slash_me ( $_path.q{/}.$_file_name);

    my $_abs_file_full = File::Spec->rel2abs( $_file_name_full );

    write_file($_abs_file_full, $_xml);

    return $_abs_file_full;
}

#------------------------------------------------------------------
sub _include_file {
    my ($_file, $_id, $_match) = @_;

    if ( $_match =~ /runon[\s]*=[\s]*"([^"]*)/ ) {
        if ( not _run_this_step($1) ) {
            $results_stdout .= "not included: [id $_id] $_file (run on $1)\n";
            return q{};
        }
    }

    if ($_match =~ /autocontrolleronly/) {
        if (not $opt_autocontroller) {
            $results_stdout .= "not included: [id $_id] $_file (autocontrolleronly)\n";
            return q{};
        }
    }

    $results_stdout .= "include: [id $_id] $_file\n";

    my $_include = read_file(slash_me($_file));
    $_include =~ s{\n(\s*)id[\s]*=[\s]*"}{"\n".$1.'id="'.$_id.'.'}eg; #'

    #open my $_INCLUDE, '>', "$output".'include.xml' or die "\nERROR: Failed to open include debug file\n\n";
    #print {$_INCLUDE} $_include;
    #close $_INCLUDE or die "\nERROR: Failed to close include debug file\n\n";

    return $_include;
}

#------------------------------------------------------------------
sub _does_testfile_contain_selenium {
    my ($_text) = @_; # sub is passed reference to file contents in string

    if (${$_text} =~ m/\$driver->/) {
        return 'true';
    }

    return;
}

#------------------------------------------------------------------
## no critic (RequireArgUnpacking)
sub convert_back_xml {  #converts replaced xml with substitutions

## perform arbirtary user defined config substituions - done first to allow for double substitution e.g. {:8080}
    my ($_value, $_KEY);
    foreach my $_key (keys %{ $user_config->{userdefined} } ) {
        $_value = $user_config->{userdefined}{$_key};
        if (ref($_value) eq 'HASH') { ## if we found a HASH, we treat it as blank
            $_value = q{};
        }
        $_KEY = uc $_key; ## convert to uppercase
        $_[0] =~ s/{$_KEY}/$_value/g;
    }

## length feature for returning the size of the response
    my $_my_length;
    if (defined $response) {#It will not be defined for the first test
        $_my_length = length($response->as_string);
    }

    $_[0] =~ s/{JUMPBACKS}/$jumpbacks/g; #Number of times we have jumped back due to failure

## hostname, testnum, concurrency, teststeptime
    $_[0] =~ s/{HOSTNAME}/$hostname/g; #of the computer currently running webinject
    $_[0] =~ s/{TESTNUM}/$testnum_display/g;
    $_[0] =~ s/{TESTFILENAME}/$testfilename/g;
    $_[0] =~ s/{LENGTH}/$_my_length/g; #length of the previous test step response
    $_[0] =~ s/{AMPERSAND}/&/g;
    $_[0] =~ s/{LESSTHAN}/</g;
    $_[0] =~ s/{SINGLEQUOTE}/'/g; #'
    $_[0] =~ s/{TIMESTAMP}/$timestamp/g;
    $_[0] =~ s/{STARTTIME}/$start_time/g;
    $_[0] =~ s/{OPT_PROXY}/$opt_proxy/g;

    $_[0] =~ m/{TESTSTEPTIME:(\d+)}/s;
    if ($1)
    {
     $_[0] =~ s/{TESTSTEPTIME:(\d+)}/$test_step_time{$1}/g; #latency for test step number; example usage: {TESTSTEPTIME:5012}
    }

    $_[0] =~ s/{RANDOM:(\d+)(:*[[:alpha:]]*)}/_get_random_string($1, $2)/eg;

    if (defined $convert_back_ports) {
        $_[0] =~ s/{:(\d+)}/:$1/;
    } elsif (defined $convert_back_ports_null) {
        $_[0] =~ s/{:(\d+)}//;
    }

## day month year constant support #+{DAY}.{MONTH}.{YEAR}+{HH}:{MM}:{SS}+ - when execution started
    $_[0] =~ s/{DAY}/$DAYOFMONTH/g;
    $_[0] =~ s/{MONTH}/$MONTHS[$MONTH]/g;
    $_[0] =~ s/{YEAR}/$YEAR/g; #4 digit year
    $_[0] =~ s/{YY}/$YY/g; #2 digit year
    $_[0] =~ s/{HH}/$HOUR/g;
    $_[0] =~ s/{MM}/$MINUTE/g;
    $_[0] =~ s/{SS}/$SECOND/g;
    $_[0] =~ s/{WEEKOFMONTH}/$WEEKOFMONTH/g;
    $_[0] =~ s/{DATETIME}/$YEAR$MONTHS[$MONTH]$DAYOFMONTH$HOUR$MINUTE$SECOND/g;
    my $_underscore = '_';
    $_[0] =~ s{{FORMATDATETIME}}{$DAYOFMONTH\/$MONTHS[$MONTH]\/$YEAR$_underscore$HOUR:$MINUTE:$SECOND}g;
    $_[0] =~ s/{COUNTER}/$counter/g;
    $_[0] =~ s/{CONCURRENCY}/$concurrency/g; #name of the temporary folder being used - not full path
    $_[0] =~ s/{OUTPUT}/$output/g;
    $_[0] =~ s/{PUBLISH}/$opt_publish_full/g;
    $_[0] =~ s/{OUTSUM}/$outsum/g;
## CWD Current Working Directory
    $_[0] =~ s/{CWD}/$this_script_folder_full/g;

## parsedresults moved before config so you can have a parsedresult of {BASEURL2} say that in turn gets turned into the actual value

    ##substitute all the parsed results back
    ##parseresponse = {}, parseresponse5 = {5}, parseresponseMYVAR = {MYVAR}
    foreach my $_case_attribute ( sort keys %{parsedresult} ) {
       my $_parse_var = substr $_case_attribute, 13;
       $_[0] =~ s/{$_parse_var}/$parsedresult{$_case_attribute}/g;
    }

    $_[0] =~ s/{BASEURL}/$config{baseurl}/g;
    $_[0] =~ s/{BASEURL1}/$config{baseurl1}/g;
    $_[0] =~ s/{BASEURL2}/$config{baseurl2}/g;

    return;
}

#------------------------------------------------------------------
sub _get_random_string {
    my ($_length, $_type) = @_;

    if (not $_type) {
        $_type = ':ALPHANUMERIC';
    }

    require Math::Random::ISAAC;

    my $_rng = Math::Random::ISAAC->new(time*100_000); ## only integer portion is used in seed

    my $_random;
    my $_last;
    my $_next;
    foreach my $_i (1..$_length) {
        $_next = _get_char($_rng->irand(), $_type);

        ## this clause stops two consecutive characters being the same
        ## some search engines will filter out words containing more than 2 letters the same in a row
        if (defined $_last) {
            while ($_next eq $_last) {
                $_next = _get_char($_rng->irand(), $_type);
            }
        }

        $_last = $_next;
        $_random .= $_last;
    }

    return $_random;
}

#------------------------------------------------------------------
sub _get_char {
    my ($_raw_rnd, $_type) = @_;

    ## here we need to turn our unsigned 32 bit integer into a character of the desired type
    ## supported types :ALPHANUMERIC, :ALPHA, :NUMERIC

    my $_min_desired_rnd = 1;
    my $_max_desired_rnd;
    my $_max_possible_rnd = 4_294_967_296;
    my $_number;
    my $_char;

    if (uc $_type eq ':ALPHANUMERIC') {
        $_max_desired_rnd = 36;
        $_number = _get_number_in_range ($_min_desired_rnd, $_max_desired_rnd, $_max_possible_rnd, $_raw_rnd);
        # now we should have a number in the range 1 to 36
        if ($_number < 11) {
            $_char = chr $_number + 47;
        } else {
            $_char = chr $_number + 54;  ## i.e. 64 - 10
        }
    }

    if (uc $_type eq ':ALPHA') {
        $_max_desired_rnd = 26;
        $_number = _get_number_in_range ($_min_desired_rnd, $_max_desired_rnd, $_max_possible_rnd, $_raw_rnd);
        $_char = chr $_number + 64;
    }

    if (uc $_type eq ':NUMERIC') {
        $_max_desired_rnd = 10;
        $_number = _get_number_in_range ($_min_desired_rnd, $_max_desired_rnd, $_max_possible_rnd, $_raw_rnd);
        $_char = chr $_number + 47;
    }

    return $_char;
}

#------------------------------------------------------------------
sub _get_number_in_range {
    my ($_min_desired_rnd, $_max_desired_rnd, $_max_possible_rnd, $_raw_rnd) = @_;

    return ( ($_raw_rnd * $_max_desired_rnd) / $_max_possible_rnd ) + $_min_desired_rnd;
}

#------------------------------------------------------------------
sub convert_back_xml_dynamic {## some values need to be updated after each retry

    my $_retries_sub = $retries-1;

    my $_elapsed_seconds_so_far = int(time() - $start_time) + 1; ## elapsed time rounded to seconds - increased to the next whole number
    my $_elapsed_minutes_so_far = int($_elapsed_seconds_so_far / 60) + 1; ## elapsed time rounded to seconds - increased to the next whole number

    $_[0] =~ s/{RETRY}/$_retries_sub/g;
    $_[0] =~ s/{ELAPSED_SECONDS}/$_elapsed_seconds_so_far/g; ## always rounded up
    $_[0] =~ s/{ELAPSED_MINUTES}/$_elapsed_minutes_so_far/g; ## always rounded up

    ## put the current date and time into variables
    my ($_dynamic_second, $_dynamic_minute, $_dynamic_hour, $_dynamic_day_of_month, $_dynamic_month, $_dynamic_year_offset, $_dynamic_day_of_week, $_dynamic_day_of_year, $_dynamic_daylight_savings) = localtime;
    my $_dynamic_year = 1900 + $_dynamic_year_offset;
    $_dynamic_month = $MONTHS[$_dynamic_month];
    my $_dynamic_day = sprintf '%02d', $_dynamic_day_of_month;
    $_dynamic_hour = sprintf '%02d', $_dynamic_hour; #put in up to 2 leading zeros
    $_dynamic_minute = sprintf '%02d', $_dynamic_minute;
    $_dynamic_second = sprintf '%02d', $_dynamic_second;

    my $_underscore = '_';
    $_[0] =~ s{{NOW}}{$_dynamic_day\/$_dynamic_month\/$_dynamic_year$_underscore$_dynamic_hour:$_dynamic_minute:$_dynamic_second}g;

    return;
}

#------------------------------------------------------------------
sub convert_back_var_variables { ## e.g. postbody="time={RUNSTART}"
    foreach my $_case_attribute ( sort keys %{varvar} ) {
       my $_sub_var = substr $_case_attribute, 3;
       $_[0] =~ s/{$_sub_var}/$varvar{$_case_attribute}/g;
    }

    return;
}

## use critic
#------------------------------------------------------------------
sub set_var_variables { ## e.g. varRUNSTART="{HH}{MM}{SS}"
    foreach my $_case_attribute ( sort keys %{ $xml_test_cases->{case}->{$testnum} } ) {
       if ( (substr $_case_attribute, 0, 3) eq 'var' ) {
            $varvar{$_case_attribute} = $case{$_case_attribute}; ## assign the variable
        }
    }

    return;
}

#------------------------------------------------------------------
sub substitute_var_variables {

    foreach my $_case_attribute ( keys %{ $xml_test_cases->{case}->{$testnum} } ) { ## then substitute them in
        convert_back_var_variables($case{$_case_attribute});
    }

    return;
}

#------------------------------------------------------------------
sub uri_escape {
    my ($_string) = @_;

    $_string =~ s/([^^A-Za-z0-9\-_.!~*'()])/ sprintf "%%%02x", ord $1 /eg; ##no critic(RegularExpressions::ProhibitEnumeratedClasses) #'

    return $_string;
}

#------------------------------------------------------------------
sub httplog {  # write requests and responses to http.txt file

    ## save the http response to a file - e.g. for file downloading, css
    if ($case{logresponseasfile}) {
        my $_response_folder_name = dirname($output.'dummy'); ## output folder supplied by command line might include a filename prefix that needs to be discarded, dummy text needed due to behaviour of dirname function
        open my $_RESPONSE_AS_FILE, '>', "$_response_folder_name/$case{logresponseasfile}" or die "\nCould not open file for response as file\n\n";  #open in clobber mode
        binmode $_RESPONSE_AS_FILE; ## set binary mode
        print {$_RESPONSE_AS_FILE} $response->content, q{}; #content just outputs the content, whereas as_string includes the response header
        close $_RESPONSE_AS_FILE or die "\nCould not close file for response as file\n\n";
    }

    my $_step_info = "Test Step: $testnum_display$jumpbacks_print$retries_print - ";

    ## log descrption1 and description2
    $_step_info .=  $case{description1};
    if (defined $case{description2}) {
       $_step_info .= ' ['.$case{description2}.']';
    }
    $_step_info .= "\n";

    for (qw/searchimage searchimage1 searchimage2 searchimage3 searchimage4 searchimage5/) {
        if ($case{$_}) {
            $_step_info .= "<searchimage>$case{$_}</searchimage>\n";
        }
    }

    my $_request_headers = $request->as_string;

    my $_request_content_length = length $request->content;
    if ($_request_content_length) {
        $_request_headers .= 'Request Content Length: '.$_request_content_length." bytes\n";
    }

    #$textrequest =~ s/%20/ /g; #Replace %20 with a single space for clarity in the log file

    my $_core_info = "\n".$response->status_line( )."\n";

    my $_response_base;
    if ( eval { defined $response->base( ) } ) {
        $_response_base = $response->base( );
        $_core_info .= 'Base for relative URLs: '.$_response_base."\n";
        $_core_info .= 'Expires: '.scalar(localtime( $response->fresh_until( ) ))."\n";
    }

    #my $_age = $response->current_age( );
    #my $_days  = int($_age/86400);       $_age -= $_days * 86400;
    #my $_hours = int($_age/3600);        $_age -= $_hours * 3600;
    #my $_mins  = int($_age/60);          $_age -= $_mins    * 60;
    #my $_secs  = $_age;
    #$_core_info .= "The document is $_days days, $_hours hours, $_mins minutes, and $_secs seconds old.\n";

    my $_response_content_ref = $response->content_ref( );
    my $_response_headers = $response->headers_as_string;

    _write_http_log($_step_info, $_request_headers, $_core_info, $_response_headers, $_response_content_ref);
    _write_step_html($_step_info, $_request_headers, $_core_info, $_response_headers, $_response_content_ref, $_response_base);

    $previous_test_step = $testnum_display.$jumpbacks_print.$retries_print;

    return;
}

#------------------------------------------------------------------
sub _write_http_log {
    my ($_step_info, $_request_headers, $_core_info, $_response_headers, $_response_content_ref) = @_;

    my $_log_separator = "\n";
    $_log_separator .= "      *****************************************************      \n";
    $_log_separator .= "    *********************************************************    \n";
    $_log_separator .= "  *************************************************************  \n";
    $_log_separator .= "************************* LOG SEPARATOR *************************\n";
    $_log_separator .= "  *************************************************************  \n";
    $_log_separator .= "    *********************************************************    \n";
    $_log_separator .= "      *****************************************************      \n\n";
    if (not $opt_no_output) {
        open my $_HTTPLOGFILE, '>>' ,$opt_publish_full.'http.txt' or die "\nERROR: Failed to open $opt_publish_full"."http.txt for append\n\n";
        print {$_HTTPLOGFILE} $_step_info, $_request_headers, $_core_info."\n", $_response_headers."\n", ${ $_response_content_ref }, $_log_separator;
        close $_HTTPLOGFILE or die "\nCould not close http.txt file\n\n";
    }

    return;
}

#------------------------------------------------------------------
sub _write_step_html {
    my ($_step_info, $_request_headers, $_core_info, $_response_headers, $_response_content_ref, $_response_base) = @_;

    _format_xml($_response_content_ref);

    _format_json($_response_content_ref);

    my $_display_as_text = _should_display_as_text($_response_content_ref);

    my ($_wif_batch, $_wif_run_number);
    if (defined $user_config->{wif}->{batch} ) {
        $_wif_batch = $user_config->{wif}->{batch};
        $_wif_run_number = $user_config->{wif}->{run_number};
    } else {
        $_wif_batch = 'needs_webinject_framework';
        $_wif_run_number = 'needs_webinject_framework';
    }

    my $_html = '<!DOCTYPE html>';
    _add_html_head(\$_html);

    $_html .= qq|        <div style="padding:1em 1em 0 1em; border:1px solid #ddd; background:DarkSlateGray; margin:0 2em 2em 0; font-weight:normal;  color:#D1E6E7; line-height:1.6em !important; font:Verdana, sans-serif !important;">\n|;
    $_html .= qq|            <h1 style="font-weight: normal; font-size:1.6em !important; font-family: Verdana, sans-serif; float: left; margin: 0; padding: 0; border: 0; color:#D1E6E7;">Step $testnum_display$jumpbacks_print$retries_print</wi>\n|;
    $_html .= qq|            <h3 style="font-size: 1.0em !important; font-family: Verdana, sans-serif !important; margin-bottom: 0.3em; float: right; margin: 0; padding: 0; border: 0; line-height: 1.0em !important; color:#D1E6E7;">\n|;
    $_html .= qq|              $case{description1}\n|;
    $_html .= qq|            </h3>\n|;
    $_html .= qq|            <div style="clear: both;"></div>\n|;
    $_html .= qq|            <h2 style="font-size:1.2em !important; font-family: Verdana, sans-serif !important; margin-bottom:0.3em !important; text-align: left;">\n|;
    $_html .= qq|                <a class="wi_hover_item" style="color:SlateGray;font-weight:bolder !important;" href="../../../All_Batches/Summary.xml"> Summary </a> -&gt; <a class="wi_hover_item" style="color:SlateGray;font-weight:bolder;" href="../../../All_Batches/$_wif_batch.xml"> Batch Summary </a> -&gt; <a class="wi_hover_item" style="color:SlateGray;font-weight:bolder;" href="results_$_wif_run_number.xml"> Run Results </a> -&gt; Step\n|;
    if (defined $previous_test_step) {
        $_html .= qq|                &nbsp; &nbsp; [<a class="wi_hover_item" style="color:SlateGray;font-weight:bolder;" href="$output_prefix$previous_test_step.html"> prev </a>]\n|;
    }
    $_html .= qq|            </h2>\n|;
    $_html .= qq|        </div>\n|;

    #$_html .= $_step_info;

    $_html .= qq|        <a class="wi_hover_item" style="font-family: Verdana, sans-serif; color:SlateGray; font-weight:bolder;" href="javascript:wi_toggle('wi_toggle_request');">Request Headers</a> : \n|;
    $_html .= qq|\n<xmp id="wi_toggle_request" style="display: none; font-size:1.5em; white-space: pre-wrap;">\n|.$_request_headers.qq|\n</xmp>\n|;
    $_html .= qq|        <a class="wi_hover_item" style="font-family: Verdana, sans-serif; color:SlateGray; font-weight:bolder;" href="javascript:wi_toggle('wi_toggle_response');">Response Headers</a>\n|;
    $_html .= qq|\n<xmp id="wi_toggle_response" style="display: none; font-size:1.5em; white-space: pre-wrap;">\n|.$_core_info.qq|\n|.$_response_headers.qq|\n</xmp>\n<br /><br />\n|;
    $_html .= qq|    </wi_body>\n|;
#    $_html .= qq|    <body style="display:block; margin:0; padding:0; border:0; font-size: 100%; font: inherit; vertical-align: baseline;">\n|;
    $_html .= qq|    <body>\n|;

    _add_selenium_screenshot(\$_html);

    _add_search_images(\$_html);

    _add_email_link(\$_html);

    if (defined $_response_base) {
        _replace_relative_urls_with_absolute($_response_content_ref, $_response_base);
    }

    _response_content_substitutions( $_response_content_ref );

    if (defined $_display_as_text) {
        $_html .= "\n<xmp>\n".${ $_response_content_ref } ."\n</xmp>\n";
    } else {
        $_html .= ${ $_response_content_ref } ;
    }

    $_html .= "\n    </body>\n</html>\n";

    my $_file_full = $opt_publish_full."$testnum_display$jumpbacks_print$retries_print".'.html';
    _delayed_write_step_html($_file_full, $_html);

    return;
}

#------------------------------------------------------------------
sub _format_xml {
    my ($_response) = @_;

    if ($case{formatxml}) {
         ## makes an xml response easier to read by putting in a few carriage returns
         ${ $_response } =~ s{\>\<}{\>\x0D\n\<}g; ## insert a CR between every ><
    }

    return;
}

#------------------------------------------------------------------
sub _format_json {
    my ($_response) = @_;

    if ($case{formatjson}) {
         ## makes a JSON response easier to read by putting in a few carriage returns
         ${ $_response }  =~ s{",}{",\x0D\n}g;   ## insert a CR after  every ",
         ${ $_response }  =~ s/[}],/\},\x0D\n/g;  ## insert a CR after  every },
         ${ $_response }  =~ s/\["/\x0D\n\["/g;  ## insert a CR before every ["
         ${ $_response }  =~ s/\\n\\tat/\x0D\n\\tat/g;        ## make java exceptions inside JSON readable - when \n\tat is seen, eat the \n and put \ CR before the \tat
    }

    return;
}

#------------------------------------------------------------------
sub _should_display_as_text {
    my ($_response) = @_;

    if ($case{logastext}) { return 'true'; }
    if ($case{method} eq 'selenium') { return 'true'; }

    # if html and body tags found, then display as html
    if ( ${ $_response } =~ m/<HTML.*?<BODY/is ) { return; }

    # if we didn't find html and body tags, then don't attempt to render as html
    return 'true';
}

#------------------------------------------------------------------
sub _add_html_head {
    my ($_html) = @_;

    ${$_html} .= qq|\n<html>\n    <wi_body style="padding:25px 0 0 35px; background: #ecf0f1; display:block; margin:0; border:0; font-size: 100%; vertical-align: baseline; text-align: left;">\n|;
    ${$_html} .= qq|        <head>\n|;
    ${$_html} .= qq|            <style>\n|;
    ${$_html} .= qq|                .wi_hover_item { text-decoration: none; }\n|;
    ${$_html} .= qq|                .wi_hover_item:hover { text-decoration: underline; }\n|;
    ${$_html} .= qq|            </style>\n|;
    ${$_html} .= qq|            <script language="javascript">\n|;
    ${$_html} .= qq|                function wi_toggle(wi_toggle_ele) {\n|;
    ${$_html} .= qq|                   var ele = document.getElementById(wi_toggle_ele);\n|;
    ${$_html} .= qq|                   if(ele.style.display == "block") {\n|;
    ${$_html} .= qq|                           ele.style.display = "none";\n|;
    ${$_html} .= qq|                   }\n|;
    ${$_html} .= qq|                   else {\n|;
    ${$_html} .= qq|                       ele.style.display = "block";\n|;
    ${$_html} .= qq|                   }\n|;
    ${$_html} .= qq|                } \n|;
    ${$_html} .= qq|            </script>\n|;
    ${$_html} .= qq|        </head>\n|;

    return;
}

#------------------------------------------------------------------
sub _add_selenium_screenshot {
    my ($_html) = @_;

    # if we have a Selenium WebDriver screenshot, link to it
    if (-e "$opt_publish_full$testnum_display$jumpbacks_print$retries_print.png" ) {
        ${$_html} .= qq|<br /><img style="position: relative; left: 50%; transform: translateX(-50%);" alt="screenshot of test step $testnum_display$jumpbacks_print$retries_print" src="$output_prefix$testnum_display$jumpbacks_print$retries_print.png"><br />|;
    }

    return;
}

#------------------------------------------------------------------
sub _add_search_images {
    my ($_html) = @_;

    # if we have search images, copy them to the results and link to them
    for (qw/searchimage searchimage1 searchimage2 searchimage3 searchimage4 searchimage5/) {
        if ( $case{$_} && -e $case{$_} ) {
            copy "$case{$_}", "$opt_publish_full";
            my ($_image_name, $_image_path) = fileparse( $case{$_} );
            ${$_html} .= qq|<br />$_image_name<br /><img style="position: relative; left: 50%; transform: translateX(-50%);" alt="searchimage $case{$_}" src="$_image_name"><br />|;
        }
    }

    return;
}

#------------------------------------------------------------------
sub _add_email_link {
    my ($_html) = @_;

    # if we have grabbed an email file, link to it
    if (-e "$opt_publish_full$testnum_display$jumpbacks_print$retries_print.eml" ) {
        ${$_html} .= qq|<br /><A style="font-family: Verdana; font-size:2.5em;" href="$output_prefix$testnum_display$jumpbacks_print$retries_print.eml">&nbsp; Link to actual eMail file &nbsp;</A><br /><br />|;
    }

    return;
}

#------------------------------------------------------------------
sub _response_content_substitutions {
    my ($_response_content_ref) = @_;

    foreach my $_sub ( keys %{ $user_config->{content_subs} } ) {
        #print "_sub:$_sub:$user_config->{content_subs}{$_sub}\n";
        my @_regex = split /[|][|][|]/, $user_config->{content_subs}{$_sub}; #index 0 contains the LHS, 1 the RHS
        ${ $_response_content_ref } =~ s{$_regex[0]}{$_regex[1]}gees;
    }

    if (@hrefs) {
        ${ $_response_content_ref } =~ s{href="([^"]+)}{_grabbed_href($1)}eg;
    }

    if (@srcs) {
        ${ $_response_content_ref } =~ s{src="([^"]+)}{_grabbed_src($1)}eg;
    }

    if (@bg_images) {
        ${ $_response_content_ref } =~ s{style="background-image: url[(]([^)]+)}{_grabbed_background_image($1)}eg; #"
    }

    return;
}

#------------------------------------------------------------------
sub _grabbed_href {
    my ($_href) = @_;

    foreach (@hrefs) {
        if ($_href =~ m/$_/) {
            return 'href="'.$_;
        }
    }

    # we did not grab that asset, so we will substitute it with itself
    return 'href="'.$1; ##no critic(RegularExpressions::ProhibitCaptureWithoutTest)
}

#------------------------------------------------------------------
sub _grabbed_src {
    my ($_src) = @_;

    foreach (@srcs) {
        if ($_src =~ m/$_/) {
            return 'src="'.$_;
        }
    }

    # we did not grab that asset, so we will substitute it with itself
    return 'src="'.$1; ##no critic(RegularExpressions::ProhibitCaptureWithoutTest)
}

#------------------------------------------------------------------
sub _grabbed_background_image {
    my ($_bg_image) = @_;

    foreach (@bg_images) {
        if ($_bg_image =~ m/$_/) {
            return 'style="background-image: url\('.$_;
        }
    }

    # we did not grab that asset, so we will substitute it with itself
    return 'style="background-image: url\('.$1; ##no critic(RegularExpressions::ProhibitCaptureWithoutTest)
}

#------------------------------------------------------------------
sub _replace_relative_urls_with_absolute {
    my ($_response_content_ref, $_response_base) = @_;

    # first we need to see if there are any substitutions defined for the base url - e.g. turn https: to http:
    foreach my $_sub ( keys %{ $user_config->{baseurl_subs} } ) {
        #print "_sub:$_sub:$user_config->{baseurl_subs}{$_sub}\n";
        #print "orig _response_base:$_response_base\n";
        my @_regex = split /[|][|][|]/, $user_config->{baseurl_subs}{$_sub}; #index 0 contains the LHS, 1 the RHS
        $_response_base =~ s{$_regex[0]}{$_regex[1]}ee;
        #print "new _response_base:$_response_base\n";
    }

    while (
            ${ $_response_content_ref } =~ s{
                                                 (action|href|src)
                                                 [ ]{0,1}
                                                 =
                                                 [ ]{0,1}
                                                 ["']                                                     #" (fix editor code highlight)
                                                 (
                                                     [./a-gik-zA-GIK-Z~]                                  # will not match http or javascript
                                                     [^"']*                                               #" (fix editor code highlight)
                                                 )
                                                 ["']                                                     #" (fix editor code highlight)
                                             }
                                             {
                                                $1
                                                .'="'.
                                                _determine_absolute_url($2, $_response_base)
                                                .'"'
                                             }exg
          )
    {
        #print "$&\n";
    }

    return;
}

#------------------------------------------------------------------
sub _determine_absolute_url {
    my ($_ref, $_response_base) = @_;

    require URI::URL;

    my $_ur_url = URI::URL->new($_ref, $_response_base);
    my $_abs_url = $_ur_url->abs;

    # we must return a url beginning with http (or javascript), otherwise WebInject will get stuck in an infinite loop
    # if the url we are processing begins with something like android-app://, URI:URL will not turn it into a http url - better just to get rid of it
    if ( (substr $_abs_url, 0, 1) ne 'h') {
        $_abs_url = 'http://webinject_could_not_determine_absolute_url';
    }

    return $_abs_url;
}

#------------------------------------------------------------------
sub _delayed_write_step_html {
    my ($_file_full, $_html) = @_;

    if (defined $delayed_file_full) { # will not be defined on very first call, since it is only written to by this sub
        if (defined $_html) { # will not be defined on very last call - sub finaltaks passes undef
            # substitute in the next test step number now that we know what it is
            $delayed_html =~ s{</h2>}{ &nbsp; &nbsp; [<a class="wi_hover_item" style="color:SlateGray;font-weight:bolder;" href="$output_prefix$testnum_display$jumpbacks_print$retries_print.html"> next </a>]</h2>};
        }
        if (not $opt_no_output) {
            open my $_FILE, '>', "$delayed_file_full" or die "\nERROR: Failed to create $delayed_file_full\n\n";
            print {$_FILE} $delayed_html;
            close $_FILE or die "\nERROR: Failed to close $delayed_file_full\n\n";
        }
    }

    $delayed_file_full = $_file_full;
    $delayed_html = $_html;

    return;
}

#------------------------------------------------------------------
sub final_tasks {  #do ending tasks

    # write out the html for the final test step, there is no new content to put in the buffer
    _delayed_write_step_html(undef, undef);

    $total_response = sprintf '%.3f', $total_response;

    write_final_html();  #write summary and closing tags for results file

    write_final_xml();  #write summary and closing tags for XML results file

    write_final_stdout();  #write summary and closing tags for STDOUT

    return;
}

#------------------------------------------------------------------
sub start_selenium_browser {     ## start Browser using Selenium Server or ChromeDriver
    require Selenium::Remote::Driver;
    require Selenium::Chrome;

    if (not $opt_chromedriver_binary) {
        die "\n\nYou must specify --chromedriver-binary for Selenium tests\n\n";
    }

    if (not -e $opt_chromedriver_binary) {
        die "\n\nCannot find ChromeDriver at $opt_chromedriver_binary\n\n";
    }

    if (defined $driver) { #shut down any existing selenium browser session
        $results_stdout .= "    [\$driver is defined so shutting down Selenium first]\n";
        shutdown_selenium();
        shutdown_selenium_server($selenium_port);
        sleep 2.1; ## Sleep for 2.1 seconds, give system a chance to settle before starting new browser
        $results_stdout .= "    [Done shutting down Selenium]\n";
    }

    $opt_driver //= 'chromedriver'; ## if variable is undefined, set to default value
    $opt_driver = lc $opt_driver;

    if ($opt_driver eq 'chrome') {
        $selenium_port = _start_selenium_server();
        $results_stdout .= "    [Connecting to Selenium Remote Control server on port $selenium_port]\n";
    }

    my $_max = 30;
    my $_try = 0;

    ## --load-extension Loads an extension from the specified directory
    ## --whitelisted-extension-id
    ## http://rdekleijn.nl/functional-test-automation-over-a-proxy/
    ## http://bmp.lightbody.net/
    ATTEMPT:
    {
        eval
        {

            ## ChromeDriver without Selenium Server or JRE
            if ($opt_driver eq 'chromedriver') {
                my $_port = find_available_port(9585); ## find a free port to bind to, starting from this number
                if ($opt_proxy) {
                    $results_stdout .= "    [Starting ChromeDriver without Selenium Server through proxy on port $opt_proxy]\n";
                    $driver = Selenium::Chrome->new (binary => $opt_chromedriver_binary,
                                                 binary_port => $_port,
                                                 _binary_args => " --port=$_port --url-base=/wd/hub --verbose --log-path=$output".'chromedriver.log',
                                                 'browser_name' => 'chrome',
                                                 'proxy' => {'proxyType' => 'manual', 'httpProxy' => $opt_proxy, 'sslProxy' => $opt_proxy }
                                                 );

                } else {
                    $results_stdout .= "    [Starting ChromeDriver without Selenium Server]\n";
                    $driver = Selenium::Chrome->new (binary => $opt_chromedriver_binary,
                                                 binary_port => $_port,
                                                 _binary_args => " --port=$_port --url-base=/wd/hub --verbose --log-path=$output".'chromedriver.log',
                                                 'browser_name' => 'chrome'
                                                 );
                }
            }

            ## Chrome
            if ($opt_driver eq 'chrome') {
                my $_chrome_proxy = q{};
                if ($opt_proxy) {
                    $results_stdout .= qq|    [Starting Chrome with Selenium Server Standalone on port $selenium_port through proxy on port $opt_proxy]\n|;
                    $driver = Selenium::Remote::Driver->new('remote_server_addr' => 'localhost',
                                                        'port' => $selenium_port,
                                                        'browser_name' => 'chrome',
                                                        'proxy' => {'proxyType' => 'manual', 'httpProxy' => $opt_proxy, 'sslProxy' => $opt_proxy },
                                                        'extra_capabilities' => {'chromeOptions' => {'args' => ['window-size=1260,968']}}
                                                        );
                } else {
                    $results_stdout .= "    [Starting Chrome using Selenium Server Standalone on $selenium_port]\n";
                    $driver = Selenium::Remote::Driver->new('remote_server_addr' => 'localhost',
                                                        'port' => $selenium_port,
                                                        'browser_name' => 'chrome',
                                                        'extra_capabilities' => {'chromeOptions' => {'args' => ['window-size=1260,968']}}
                                                        );
                }
             }
                                                   # For reference on how to specify options for Chrome
                                                   #
                                                   #'proxy' => {'proxyType' => 'manual', 'httpProxy' => $opt_proxy, 'sslProxy' => $opt_proxy },
                                                   #'extra_capabilities' => {'chrome.switches' => ['--proxy-server="http://127.0.0.1:$opt_proxy" --incognito --window-size=1260,460'],},
                                                   #'extra_capabilities' => {'chrome.switches' => ['--incognito --window-size=1260,960']}
                                                   #'extra_capabilities' => {'chromeOptions' => {'args' => ['incognito','window-size=1260,960']}}
                                                   #'extra_capabilities' => {'chromeOptions' => {'args' => ['window-size=1260,968']}}

                                                   #'extra_capabilities'
                                                   #   => {'chromeOptions' => {'args'  =>         ['window-size=1260,960','incognito'],
                                                   #                           'prefs' => {'session' => {'restore_on_startup' =>4, 'urls_to_restore_on_startup' => ['http://www.google.com','http://www.example.com']},
                                                   #                                       'first_run_tabs' => ['http://www.mywebsite.com','http://www.google.de']
                                                   #                                      }
                                                   #                          }
                                                   #      }

        }; ## end eval

        if ( $@ and $_try++ < $_max )
        {
            print "\n[Selenium Start Error - possible Chrome and ChromeDriver version compatibility issue]\n$@\nFailed try $_try to connect to Selenium Server, retrying...\n\n";
            sleep 4; ## sleep for 4 seconds, Selenium Server may still be starting up
            redo ATTEMPT;
        }
    } ## end ATTEMPT

    if ($@) {
        print "\nError: $@ Failed to connect on port $opt_port after $_max tries\n\n";
        $results_xml .= qq|        <testcase id="999999">\n|;
        $results_xml .= qq|            <description1>WebInject ended execution early !!!</description1>\n|;
        $results_xml .= qq|            <verifynegative>\n|;
        $results_xml .= qq|                <assert>WebInject Aborted - could not connect to Selenium Server</assert>\n|;
        $results_xml .= qq|                <success>false</success>\n|;
        $results_xml .= qq|            </verifynegative>\n|;
        $results_xml .= qq|            <success>false</success>\n|;
        $results_xml .= qq|            <result-message>WEBINJECT ABORTED</result-message>\n|;
        $results_xml .= qq|            <responsetime>0.001</responsetime>\n|;
        $results_xml .= qq|        </testcase>\n|;
        $case_failed_count++;
        write_final_xml();
        die "\n\nWebInject Aborted - could not connect to Selenium Server\n";
    }

    eval { $driver->set_timeout('page load', 30_000); };

    return;
}

#------------------------------------------------------------------
sub shutdown_selenium_server {
    my ($_selenium_port) = @_;

    if (not defined $_selenium_port) {
        return;
    }

    require LWP::Simple;

    my $_url = "http://localhost:$_selenium_port/selenium-server/driver/?cmd=shutDownSeleniumServer";
    my $_content = LWP::Simple::get $_url;
    #print {*STDOUT} "Shutdown Server:$_content\n";

    return;
}

#------------------------------------------------------------------
sub _start_selenium_server {

    if (not -e $opt_selenium_binary) {
        die "\nCannot find Selenium Server at $opt_selenium_binary\n";
    }

    # copy chromedriver - source location hardcoded for now
    copy $opt_chromedriver_binary, $output_folder;

    # find free port
    my $_selenium_port = find_available_port(int(rand 999)+11_000);
    #print "_selenium_port:$_selenium_port\n";

    my $_abs_selenium_log_full = File::Spec->rel2abs( $output_folder.'/selenium_log.txt' );

    if ($is_windows) {
        my $_abs_chromedriver_full = File::Spec->rel2abs( "$output_folder/chromedriver.eXe" );
        my $_pid = _start_windows_process(qq{cmd /c java -Dwebdriver.chrome.driver="$_abs_chromedriver_full" -Dwebdriver.chrome.logfile="$_abs_selenium_log_full" -jar $opt_selenium_binary -port $_selenium_port -trustAllSSLCertificates});
    } else {
        my $_abs_chromedriver_full = File::Spec->rel2abs( "$output_folder/chromedriver" );
        chmod 0775, $_abs_chromedriver_full; # Linux loses the write permission with file copy
        _start_linux_process(qq{java -Dwebdriver.chrome.driver="$_abs_chromedriver_full" -Dwebdriver.chrome.logfile="$_abs_selenium_log_full" -jar $opt_selenium_binary -port $_selenium_port -trustAllSSLCertificates});
    }

    return $_selenium_port;
}

#------------------------------------------------------------------
sub _start_windows_process {
    my ($_command) = @_;

    my $_wmic = "wmic process call create '$_command'"; #
    my $_result = `$_wmic`;
    #print "_wmic:$_wmic\n";
    #print "$_result\n";

    my $_pid;
    if ( $_result =~ m/ProcessId = (\d+)/ ) {
        $_pid = $1;
    }

    return $_pid;
}

#------------------------------------------------------------------
sub _start_linux_process {
    my ($_command) = @_;

    my $_gnome_terminal = qq{(gnome-terminal -e "$_command" &)}; #
    my $_result = `$_gnome_terminal`;
    #print "_gnome_terminal:_gnome_terminal\n";
    #print "$_result\n";

    return;
}

#------------------------------------------------------------------

sub port_available {
    my ($_port) = @_;

    my $_family = PF_INET;
    my $_type   = SOCK_STREAM;
    my $_proto  = getprotobyname 'tcp' or die "getprotobyname: $!\n";
    my $_host   = INADDR_ANY;  # Use inet_aton for a specific interface

    socket my $_sock, $_family, $_type, $_proto or die "socket: $!\n";
    my $_name = sockaddr_in($_port, $_host)     or die "sockaddr_in: $!\n";

    if (bind $_sock, $_name) {
        return 'available';
    }

    return 'in use';
}

sub find_available_port {
    my ($_start_port) = @_;

    my $_max_attempts = 20;
    foreach my $_i (0..$_max_attempts) {
        if (port_available($_start_port + $_i) eq 'available') {
            return $_start_port + $_i;
        }
    }

    return 'none';
}

sub shutdown_selenium {
    if ($opt_driver) {
        #$results_stdout .= " Shutting down Selenium Browser Session\n";

        #my $close_handles = $driver->get_window_handles;
        #for my $_close_handle (reverse 0..@{$_close_handles}) {
        #   $results_stdout .= "Shutting down window $_close_handle\n";
        #   $driver->switch_to_window($_close_handles->[$_close_handle]);
        #   $driver->close();
        #}

        eval { $driver->quit(); }; ## shut down selenium browser session
        if ($opt_driver eq 'chromedriver') {
            eval { $driver->shutdown_binary(); }; ## shut down chromedriver binary
        }
        undef $driver;
    }

    return;
}
#------------------------------------------------------------------
sub start_session {     ## creates the webinject user agent

    require IO::Socket::SSL;
    #require Crypt::SSLeay;  #for SSL/HTTPS (you may comment this out if you don't need it)
    require HTTP::Cookies;

    #$useragent = LWP::UserAgent->new; ## 1.41 version
    $useragent = LWP::UserAgent->new(keep_alive=>1);
    $cookie_jar = HTTP::Cookies->new;
    $useragent->agent('WebInject');  ## http useragent that will show up in webserver logs
    #$useragent->timeout(200); ## it is possible to override the default timeout of 360 seconds
    $useragent->max_redirect('0');  #don't follow redirects for GET's (POST's already don't follow, by default)
    #push @{ $useragent->requests_redirectable }, 'POST'; # allow redirects for POST (if used in conjunction with maxredirect parameter) - does not appear to work with Login requests, perhaps cookies are not dealt with
    eval
    {
       $useragent->ssl_opts(verify_hostname=>0); ## stop SSL Certs from being validated - only works on newer versions of of LWP so in an eval
       $useragent->ssl_opts(SSL_verify_mode=>'SSL_VERIFY_NONE'); ## from Perl 5.16.3 need this to prevent ugly warnings
    };

    #add proxy support if it is set in config.xml
    if ($config{proxy}) {
        $useragent->proxy(['http', 'https'], "$config{proxy}")
    }

    #add http basic authentication support
    #corresponds to:
    #$useragent->credentials('servername:portnumber', 'realm-name', 'username' => 'password');
    if (@http_auth) {
        #add the credentials to the user agent here. The foreach gives the reference to the tuple ($elem), and we
        #deref $elem to get the array elements.
        foreach my $_elem(@http_auth) {
            #$results_stdout .= "adding credential: $_elem->[0]:$_elem->[1], $_elem->[2], $_elem->[3] => $_elem->[4]\n";
            $useragent->credentials("$_elem->[0]:$_elem->[1]", "$_elem->[2]", "$_elem->[3]" => "$_elem->[4]");
        }
    }

    #change response delay timeout in seconds if it is set in config.xml
    if ($config{timeout}) {
        $useragent->timeout("$config{timeout}");  #default LWP timeout is 180 secs.
    }

    my $_set_user_agent;
    if ($user_config->{useragent}) {
        $_set_user_agent = $user_config->{useragent};
        if ($_set_user_agent) { #http useragent that will show up in webserver logs
            $useragent->agent($_set_user_agent);
        }
    }

    if ($testfile_contains_selenium) { start_selenium_browser(); }  ## start selenium browser if applicable. If it is already started, close browser then start it again.

    $session_started='true';

    return;
}

#------------------------------------------------------------------
sub get_options {  #shell options

    Getopt::Long::Configure('bundling');
    GetOptions(
        'v|V|version'   => \$opt_version,
        'h|help'   => \$opt_help,
        'c|config=s'    => \$opt_configfile,
        'o|output=s'    => \$opt_output,
        'a|autocontroller'    => \$opt_autocontroller,
        'x|proxy=s'   => \$opt_proxy,
        'd|driver=s'   => \$opt_driver,
        'r|chromedriver-binary=s'   => \$opt_chromedriver_binary,
        's|selenium-binary=s'   => \$opt_selenium_binary,
        'i|ignoreretry'   => \$opt_ignoreretry,
        'n|no-output'   => \$opt_no_output,
        'e|verbose'   => \$opt_verbose,
        'u|publish-to=s' => \$opt_publish_full,
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
        $output = 'output/'; ## default to the output folder under the current folder
    }
    $output = slash_me($output);
    $output_folder = dirname($output.'dummy'); ## output folder supplied by command line might include a filename prefix that needs to be discarded, dummy text needed due to behaviour of dirname function
    File::Path::make_path ( $output_folder );
    $output_prefix = $output;
    $output_prefix =~ s{.*[/\\]}{}g; ## if there is an output prefix, grab it

    # default the publish to location for the individual html step files
    if (not defined $opt_publish_full) {
        $opt_publish_full = $output;
    } else {
        $opt_publish_full = slash_me($opt_publish_full);
    }

    return;
}

sub print_version {
    print "\nWebInject version $VERSION\nFor more info: https://github.com/Qarj/WebInject\n\n";

    return;
}

sub print_usage {
        print <<'EOB'
Usage: webinject.pl test_case_file <<options>>

                                     examples/simple.xml
-c|--config config_file           -c config.xml
-o|--output output_location       -o output/
-a|--autocontroller               -a
-p|--port selenium_port           -p 8325
-x|--proxy proxy_server           -x localhost:9222
-d|--driver chrome|chromedriver   -d chrome
-r|--chromedriver-binary          -r C:\selenium-server\chromedriver.exe
-s|--selenium-binary              -s C:\selenium-server\selenium-server-standalone-2.53.1.jar
-i|--ignoreretry                  -i
-n|--no-output                    -n
-e|--verbose                      -e
-u|--publish-to                   -u C:\inetpub\wwwroot\this_run_home

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
