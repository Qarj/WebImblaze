#!/usr/bin/perl

# $Id$
# $Revision$
# $Date$

use strict;
use warnings;
use vars qw/ $VERSION /;

$VERSION = '2.9.0';

#    Copyright 2004-2006 Corey Goldberg (corey@goldb.org)
#    Extensive updates 2015-2018 Tim Buckland
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
use LWP::Protocol::http;
use HTTP::Request::Common;
use XML::Simple;
use JSON::PP;
use Time::HiRes qw( time sleep gettimeofday );
use Getopt::Long;
local $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 'false';
use File::Copy qw(copy), qw(move);
use File::Path qw(make_path remove_tree);
use Encode qw(encode decode);
use if $^O eq 'MSWin32', 'Win32::Console::ANSI';
use Term::ANSIColor;
use lib '.'; ## Current folder is not @INC from Perl 5.26

local $| = 1; #don't buffer output to STDOUT
our $EXTRA_VERBOSE = 0; ## Set to 1 for additional std out messages, also used by the unit tests

## Variable declarations

our ($request, $response);
my $useragent;

our ($latency, $verification_latency, $screenshot_latency);
my ($epoch_seconds, $epoch_split); ## for {TIMESTAMP}, {EPOCHSECONDS} - global so all substitutions in a test step have same timestamp
my $test_file_base_name;
my $total_run_time;
my ($total_response, $avg_response, $max_response, $min_response);
my %test_step_time; ## record latency for use by substitutions

my ($cookie_jar, @http_auth);

our ($case_failed_count, $passed_count, $failed_count);
our $is_failure;
my ($run_count, $total_run_count, $case_passed_count, $case_failed);
my ($current_case_file, $current_case_filename, $case_count, $fast_fail_invoked);

our %case;
my %case_save; ## when we retry, we need to re-substitute some variables
my (%parsedresult, %varvar, %late_sub);

our $opt_proxy;
our ($opt_driver, $opt_chromedriver_binary, $opt_selenium_binary, $opt_selenium_host, $opt_selenium_port, $opt_publish_full, $opt_headless, $opt_resume_session, $opt_keep_session);
my ($opt_configfile, $opt_version, $opt_output, $opt_autocontroller);
my ($opt_ignoreretry, $opt_no_colour, $opt_no_output, $opt_verbose, $opt_help);

my $report_type; ## 'standard' and 'nagios' supported
my $nagios_return_message;

my $testnum;
our $testnum_display;
my ($previous_test_step, $delayed_file_full, $delayed_html);
our ($retry_passed_count, $retry_failed_count, $retries_print, $jumpbacks_print);
my ($retry, $retries, $globalretries, $jumpbacks, $auto_retry, $checkpoint);
my $attempts_since_last_success = 0;
my ($xml_test_cases, $step_index, @test_steps);
my $execution_aborted = 'false';

our $results_output_folder; ## output relative path e.g. 'output/'
my $results_filename_prefix; ## prefix for results file names e.g. 'run1'
my $outsum; ## outsum is a checksum calculated on the output directory name. Used to help guarantee test data uniqueness where two WebInject processes are running in parallel.
my $config; ## contents of config.xml
my ($convert_back_ports, $convert_back_ports_null); ## turn {:4040} into :4040 or null
my $total_assertion_skips = 0;

our @cached_pages; ## page source of previously visited pages
our @cached_page_actions; ## page name of previously visited pages
our @cached_page_update_times; ## last time the page was updated in the cache
my $MAX_CACHE_SIZE = 5; ## maximum size of the cache

my $assertion_skips = 0;
my $assertion_skips_message = q{}; ## support tagging an assertion as disabled with a message
my (@hrefs, @srcs, @bg_images, %asset); ## keep an array of all grabbed assets to substitute them into the step results html (for results visualisation)
my ($getallsrcs, $getallhrefs);
my ($hrefs_version, $srcs_version) = 0;
my $session_started; ## only start up http sesion if http is being used
my $shared_folder_full;

my ($testfile_contains_selenium, $selenium_plugin_present); ## so we know if Selenium Browser Session needs to be started
if (-e 'plugins/WebInjectSelenium.pm') {
    require 'plugins/WebInjectSelenium.pm';
    $selenium_plugin_present = 1;
}

my $start_time = time;  #timer for entire test run
my ($SECOND, $MINUTE, $HOUR, $DAYOFMONTH, $DAY_TEXT, $WEEKOFMONTH, $MONTH, $MONTH_TEXT, $YEAR, $YY) = get_formatted_datetime_for_seconds_since_epoch($start_time);
my $start_date_time = "$DAY_TEXT $DAYOFMONTH $MONTH_TEXT $YEAR, $HOUR:$MINUTE:$SECOND";

my $this_script_folder_full = dirname(__FILE__);
chdir $this_script_folder_full;

my $counter = 0; ## keeping track of the loop we are up to

my $concurrency = 'null'; ## current working directory - not full path

our ($results_stdout, $results_html, $results_xml);
my $results_xml_file_name;
my ($repeat, $start);

my $hostname = `hostname`; ##no critic(ProhibitBacktickOperators) ## hostname should work on Linux and Windows
$hostname =~ s/\r|\n//g; ## strip out any rogue linefeeds or carriage returns

our $is_windows = $^O eq 'MSWin32' ? 1 : 0;

## Startup
return 1 unless $0 eq __FILE__;
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

$current_case_filename = basename($current_case_file); ## with extension
$test_file_base_name = fileparse($current_case_file, '.xml');

read_test_case_file();

$repeat = $xml_test_cases->{repeat};  #grab the number of times to iterate test case file
$repeat //= 1;  #set to 1 in case it is not defined in test case file

$start = $xml_test_cases->{start};  #grab the start for repeating (for restart)
$start //= 1;  #set to 1 in case it is not defined in test case file

$counter = $start - 1; #so starting position and counter are aligned

write_stdout_dashes_separator();

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

        # populate variables with values from testcase file, do substitutions, and revert converted values back
        substitute_variables();

        $retry = get_number_of_times_to_retry_this_test_step(); # 0 means do not retry this step

        do ## retry loop
        {
            substitute_retry_variables(); ## for each retry, there are a few substitutions that we need to redo - like the retry number
            read_shared_variable();  ## read in a variable from another instance of WebInject that is running concurrently
            set_var_variables(); ## set any variables after doing all the static and dynamic substitutions
            late_substitute_var_variables(); ## allow var variables set in this test step to be used immediately

            my $skip_message = get_test_step_skip_message();
            if ( $skip_message ) {
                $results_stdout .= "Skipping Test Case $testnum... ($skip_message)\n";
                write_stdout_dashes_separator();
                next TESTCASE; ## skip running this test step
            }

            set_retry_to_zero_if_global_limit_exceeded();

            $is_failure = 0;
            $fast_fail_invoked = ''; # false
            $retry_passed_count = 0;
            $retry_failed_count = 0;

            if ($case{description1} and $case{description1} =~ /dummy test case/) {  ## if we hit the dummy record, skip it (this is a hack for test case files with only one step)
                next;
            }

            check_for_checkpoint();

            output_test_step_description();
            output_assertions();

            execute_test_step();
            display_request_response();

            dump_json();
            decode_smtp();
            decode_quoted_printable();

            verify(); ## check the assertions against the actual result

            getresources(); ## get JavaScript, CSS, GIF, JPG and other resources

            parseresponse();  #grab string from response to send later
            set_eval_variables(); ## perform simple true / false statement evaluations - or math expressions
            write_shared_variable();

            httplog();  #write to http.txt file

            pass_fail_or_retry();

            output_test_step_latency();
            increment_run_count();
            update_latency_statistics();

            restart_browser();

            sleep_before_next_step();

            output_test_step_results();

            $retry = $retry - 1;
        } ## end of retry loop
        until ($retry < 0); ## no critic(ProhibitNegativeExpressionsInUnlessAndUntilConditions])

        if ($case{abort} && $case_failed) { ## if abort (i.e. this case (test step) failed all after retries exhausted), then execution is aborted
            $results_stdout .= qq|EXECUTION ABORTED!!! \n|;
            $execution_aborted = 'true';
            if (set_step_index_for_test_step_to_jump_to($case{abort})) {
                $results_stdout .= qq|JUMPING TO TEARDOWN FROM STEP $case{abort}\n|;
                write_stdout_dashes_separator();
            } else {
                last;
            }
        }
    } ## end of test case loop

    if ($case{abort} && $case_failed) { last; } ## get out of repeat loop too

    $testnum = 1;  #reset testcase counter so it will reprocess test case file if repeat is set
} ## end of repeat loop

final_tasks();  #do return/cleanup tasks

my $status = $case_failed_count cmp 0;
exit $status;
## End main code


#------------------------------------------------------------------
#  SUBROUTINES
#------------------------------------------------------------------

sub get_formatted_datetime_for_seconds_since_epoch {
    my ($_seconds_since_epoch) = @_;

    my @_MONTHS = qw(01 02 03 04 05 06 07 08 09 10 11 12);
    my @_MONTHS_TEXT = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @_WEEKDAYS = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
    my ($_SECOND, $_MINUTE, $_HOUR, $_DAYOFMONTH, $_MONTH, $_YEAROFFSET, $_DAYOFWEEK, $_DAYOFYEAR, $_DAYLIGHTSAVINGS) = localtime($_seconds_since_epoch);
    my $_YEAR = 1900 + $_YEAROFFSET;
    my $_YY = substr $_YEAR, 2;
    my $_MONTH_TEXT = $_MONTHS_TEXT[$_MONTH];
    my $_DAY_TEXT = $_WEEKDAYS[$_DAYOFWEEK];
    $_DAYOFMONTH = sprintf '%02d', $_DAYOFMONTH;
    my $_WEEKOFMONTH = int(($_DAYOFMONTH-1)/7)+1;
    $_MINUTE = sprintf '%02d', $_MINUTE; #put in up to 2 leading zeros
    $_SECOND = sprintf '%02d', $_SECOND;
    $_HOUR = sprintf '%02d', $_HOUR;
    
    return $_SECOND, $_MINUTE, $_HOUR, $_DAYOFMONTH, $_DAY_TEXT, $_WEEKOFMONTH, $_MONTHS[$_MONTH], $_MONTH_TEXT, $_YEAR, $_YY;
}

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

    if ($case{runon}) { ## is this test step conditional on the target environment?
        if ( _run_this_step($case{runon}) ) {
            ## run this test case as normal since it is allowed
        }
        else {
            return "run on $case{runon}";
        }
    }

    if ($case{donotrunon}) { ## is this test step conditional on the target environment?
        if ( not _run_this_step($case{donotrunon}) ) {
            ## run this test case as normal since it is allowed
        }
        else {
            return "do not run on $case{donotrunon}";
        }
    }

    if ($case{autocontrolleronly}) { ## is the autocontrolleronly value set for this testcase?
        if ($opt_autocontroller) { ## if so, was the auto controller option specified?
            ## run this test case as normal since it is allowed
        }
        else {
              return 'This is not the automation controller';
        }
    }

    if ($case{firstlooponly}) { ## is the firstlooponly value set for this testcase?
        if ($counter == 1) { ## counter keeps track of what loop number we are on
            ## run this test case as normal since it is the first pass
        }
        else {
              return 'firstlooponly';
        }
    }

    if ($case{lastlooponly}) { ## is the lastlooponly value set for this testcase?
        if ($counter == $repeat) { ## counter keeps track of what loop number we are on
            ## run this test case as normal since it is the first pass
        }
        else {
              return 'lastlooponly';
        }
    }

    if (defined $case{runif}) {
        print"runif:[$case{runif}]\n";
    }
    if (defined $case{runif} && not $case{runif}) { ## evaluate content - truthy or falsy
        return 'runif evaluated as falsy';
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
    ## "retry", "abort", "logastext", "section", "assertcount", "searchimage", ... "searchimage5", "formatxml", "formatjson",
    ## "logresponseasfile", "addcookie", "restartbrowseronfail", "restartbrowser", "commandonerror", "getallhrefs", "getallsrcs", "getbackgroundimages",
    ## "firstlooponly", "lastlooponly", "decodequotedprintable"

    ($epoch_seconds, $epoch_split) = gettimeofday;

    undef %case_save; ## we need a clean array for each test case
    undef %case; ## do not allow values from previous test cases to bleed over
    undef %late_sub; ## do not substitute vars set this step with previous value

    foreach my $_case_attribute ( keys %{ $xml_test_cases->{case}->{$testnum} } ) {
        $case{$_case_attribute} = $xml_test_cases->{case}->{$testnum}->{$_case_attribute};
    }
    set_late_var_list();

    foreach my $_case_attribute (  keys %case  ) {
        #print "DEBUG: $_case_attribute", ": ", $xml_test_cases->{case}->{$testnum}->{$_case_attribute};
        #print "\n";
        $case{$_case_attribute} = $xml_test_cases->{case}->{$testnum}->{$_case_attribute};
        convert_back_xml($case{$_case_attribute});
        convert_back_var_variables($case{$_case_attribute});
        $case_save{$_case_attribute} = $case{$_case_attribute}; ## in case we have to retry, some parms need to be resubbed
    }

    return;
}

#------------------------------------------------------------------
sub get_number_of_times_to_retry_this_test_step {

    if (defined $case{autoretry}) { $auto_retry = $case{autoretry}; } ## we need to capture this value if it is present since it applies to subsequent steps

    if ($case{retryfromstep}) { ## retryfromstep parameter found
        $results_stdout .= qq|Retry from step $case{retryfromstep}\n|;
        return 0; ## we will not do a regular retry
    }

    my $_retry;
    if ($case{retry}) { ## retry parameter found
        $_retry = $case{retry}; ## assume we can retry as many times as specified
        if ($config->{globalretry}) { ## ensure that the global retry limit won't be exceeded
            if ($_retry > ($config->{globalretry} - $globalretries)) { ## we can't retry that many times
                $_retry =  $config->{globalretry} - $globalretries; ## this is the most we can retry
                if ($_retry < 0) {
                    return 0; ## if less than 0 then make 0
                }
            }
        }
        $results_stdout .= qq|Retry $_retry times\n|;
        return $_retry;
    }

    ## getting this far means there is no retry or retryfromstep parameter, perhaps this step is eligible for autoretry
    ## to prevent excessive retries when there are severe errors, auto retry will turn itself off until it sees a test step pass
    if ( defined $auto_retry && not $case{ignoreautoretry} ) {
        if ($attempts_since_last_success < $auto_retry) {
            my $_max = $auto_retry - $attempts_since_last_success;
            if ($_max > $auto_retry) {$_max = $auto_retry};
            if ( ($_max < 0)  ) {$_max = 0};
            $results_stdout .= qq|Auto Retry $_max times|;
            if ($attempts_since_last_success > 0) {
                $results_stdout .=  " :: attempts_since_last_success[$attempts_since_last_success]";
            }
            $results_stdout .= "\n";
            return $_max;
        } else {
            if ($auto_retry) {
                $results_stdout .=  "Will not auto retry - auto retry set to $auto_retry BUT $attempts_since_last_success attempts since last success\n";
            }
        }
    }

    return 0;
}

#------------------------------------------------------------------
sub substitute_retry_variables {

    foreach my $_case_attribute ( keys %case ) {
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

    if ($config->{globalretry}) {
        if ($globalretries >= $config->{globalretry}) {
            $retry = 0; ## globalretries value exceeded - not retrying any more this run
        }
    }

    return;
}

#------------------------------------------------------------------
sub check_for_checkpoint {

    ## checkpoint concept is like in a game - if you die (test step fails), you start again from the checkpoint
    if ($case{checkpoint} && lc $case{checkpoint} eq 'false') {
        ## checkpoint cleared - will not automatically jump back from this step onwards
        $results_html .= qq|--- CHECKPOINT CLEARED --- <br />\n|;
        $results_stdout .= qq|--- CHECKPOINT CLEARED --- \n|;
        $checkpoint = '';

        return;
    }

    if ($case{checkpoint}) {
        ## checkpoint reached - record where we are up to
        $results_html .= qq|--- CHECKPOINT --- <br />\n|;
        $results_stdout .= qq|--- CHECKPOINT --- \n|;
        $checkpoint = $testnum;
    }

    return;
}

#------------------------------------------------------------------
sub output_test_step_description {

    $results_html .= qq|<b>Test:  $current_case_file - <a href="$results_filename_prefix$testnum_display$jumpbacks_print$retries_print.html"> $testnum_display$jumpbacks_print$retries_print </a> </b><br />\n|;
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
    foreach my $_case_attribute ( sort keys %case ) {
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
        if ($case{method} eq 'selenium') { WebInjectSelenium::selenium(); return; }
    }

    set_useragent($case{useragent});
    set_max_redirect($case{maxredirect});

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

    $attempts_since_last_success++; ## assume failure, will be reset to 0 if that is not the case (used by auto retry)
    $case_failed = 0; ## assume this case passed (for abort parameter logic)

    ## check max jumpbacks - globaljumpbacks - i.e. retryfromstep usages before we give up - otherwise we risk an infinite loop
    if ( ($is_failure && !( retry_available() || retry_from_step_available() || jump_back_to_checkpoint_available() ) ) || $fast_fail_invoked ) {
        ## if any verification fails, test case is considered a failure UNLESS there is at least one retry available, or it is a retryfromstep case
        $results_xml .= qq|            <success>false</success>\n|;
        if ($case{errormessage}) { #Add defined error message to the output
            $results_html .= qq|<b><span class="fail">TEST CASE FAILED : $case{errormessage}</span></b><br />\n|;
            $results_xml .= '            <result-message>'._sub_xml_special($case{errormessage})."</result-message>\n";
            colour_stdout('bold red', qq|TEST CASE FAILED : $case{errormessage}\n|);
            if (not $nagios_return_message) {
                $nagios_return_message = $case{errormessage}; ## only return the first error message to nagios
            }
        }
        else { #print regular error output
            $results_html .= qq|<b><span class="fail">TEST CASE FAILED</span></b><br />\n|;
            $results_xml .= qq|            <result-message>TEST CASE FAILED</result-message>\n|;
            colour_stdout('bold red', qq|TEST CASE FAILED\n|);
            if (not $nagios_return_message) {
                $nagios_return_message = "Test case number $testnum failed"; ## only return the first test case failure to nagios
            }
        }
        $case_failed = 1; ## for abort paramter logic
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
    elsif ( $is_failure && ($case{retryfromstep} || $checkpoint) ) {#Output message if we will retry the test case from step
        my $_jump_back_to_step;
        if ($case{retryfromstep}) {
            $_jump_back_to_step = $case{retryfromstep};
        } else {
            $_jump_back_to_step = $checkpoint;
            $results_stdout .= qq|RESTARTING SESSION BEFORE JUMPING BACK TO CHECKPOINT ... \n|;
            start_session();
        }
        my $_jump_backs_left = $config->{globaljumpbacks} - $jumpbacks;
        $results_html .= qq|<b><span class="pass">RETRYING FROM STEP $_jump_back_to_step ... $_jump_backs_left tries left</span></b><br />\n|;
        $results_stdout .= qq|RETRYING FROM STEP $_jump_back_to_step ...  $_jump_backs_left tries left\n|;
        $results_xml .= qq|            <success>false</success>\n|;
        $results_xml .= qq|            <result-message>RETRYING FROM STEP $_jump_back_to_step ...  $_jump_backs_left tries left</result-message>\n|;
        $jumpbacks++; ## increment number of times we have jumped back - i.e. used retryfromstep
        $jumpbacks_print = "-$jumpbacks";
        $globalretries++;
        $passed_count = $passed_count - $retry_passed_count;
        $failed_count = $failed_count - $retry_failed_count;

        set_step_index_for_test_step_to_jump_to($_jump_back_to_step);
    }
    else {
        $results_html .= qq|<b><span class="pass">TEST CASE PASSED</span></b><br />\n|;
        $results_stdout .= qq|TEST CASE PASSED \n|;
        $results_xml .= qq|            <success>true</success>\n|;
        $results_xml .= qq|            <result-message>TEST CASE PASSED</result-message>\n|;
        $case_passed_count++;
        $retry = 0; # no need to retry when test case passes
        $attempts_since_last_success = 0; # reset attempts for auto retry
    }

    if (($case{commandonfail}) && $case_failed) { ## if test step declared as failure (after all retries), run a command
        run_special_command('commandonfail');
    }

    return;
}

sub colour_stdout {
    my ($_colour, $_text) = @_;

    $results_stdout .= color($_colour) if !$opt_no_colour;
    $results_stdout .= $_text;
    $results_stdout .= color('reset')  if !$opt_no_colour;

    return;
}

sub set_step_index_for_test_step_to_jump_to {
    my ($_target_test_step) = @_;

    $step_index = 0;
    my $_found_index = 'false';
    foreach (@test_steps) {
        if ($test_steps[$step_index] eq $_target_test_step) {
            $_found_index = 'true';
            last;
        }
        $step_index++
    }
    if ($_found_index eq 'false') {
        $results_stdout .= qq|ERROR - COULD NOT FIND STEP $_target_test_step - TESTING STOPS\n\n|;
        return 0;
    }
    else {
        $step_index--; ## since we increment it at the start of the next loop / end of this loop
    }
    return 1;
}

sub retry_available {
    return ( ($retry > 0) && !($case{retryfromstep}) ); # retryfromstep ignored if a retry parameter is present
}

sub retry_from_step_available {
    return $case{retryfromstep} && ( $jumpbacks < $config->{globaljumpbacks} ); # retryfromstep takes priority over checkpoint
}

sub jump_back_to_checkpoint_available {
    return $checkpoint && ( $jumpbacks < $config->{globaljumpbacks} );
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

    write_html_dashes_separator();
    _write_html (\$results_html);
    undef $results_html;

    write_stdout_dashes_separator();
    if (not $opt_no_output) { print {*STDOUT} $results_stdout; }
    undef $results_stdout;

    return;
}

sub write_html_dashes_separator {
    $results_html .= qq|<br />\n---------------------------------------------------------------------- <br />\n\n|;
}

sub write_stdout_dashes_separator {
    $results_stdout .= qq|------------------------------------------------------- \n|;
}

#------------------------------------------------------------------
sub increment_run_count {

    if ( ( ($is_failure > 0) && ($retry > 0) && !($case{retryfromstep}) ) ||
         ( ($is_failure > 0) && $case{retryfromstep} && ($jumpbacks < $config->{globaljumpbacks} ) && !$fast_fail_invoked )
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

    if ( (($is_failure < 1) && ($case{retry})) || (($is_failure < 1) && ($case{retryfromstep})) || (($is_failure < 1) && $checkpoint) )
    {
        ## ignore the sleep if the test case worked and it is a retry test case (including active checkpoint)
    }
    else
    {
        if ($case{sleep})
        {
            if ( (($is_failure > 0) && ($retry < 1)) || (($is_failure > 0) && ($jumpbacks > ($config->{globaljumpbacks}-1))) )
            {
                ## do not sleep if the test case failed and we have run out of retries or jumpbacks
            }
            else
            {
                ## if a sleep value is set in the test case, sleep that amount
                $results_html .= qq|INVOKED SLEEP of $case{sleep} seconds<br />\n|;
                $results_stdout .= qq|INVOKED SLEEP of $case{sleep} seconds\n|;
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
    $results_html .= qq|            font-size: 17px;\n|;
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
    write_html_dashes_separator();

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
    $_results_xml .= '<?xml-stylesheet type="text/xsl" href="/content/Results.xsl"?>'."\n";
    $_results_xml .= "<results>\n\n";
    $results_xml_file_name = 'results.xml';
    if ( defined $config->{wif}->{dd} && defined $config->{wif}->{run_number} ) { # presume if this info is present, webinject.pl has been called by wif.pl
        $results_xml_file_name = 'results_'.$config->{wif}->{run_number}.'.xml';
        $_results_xml .= "    <wif>\n";
        $_results_xml .= "        <environment>$config->{wif}->{environment}</environment>\n";
        $_results_xml .= "        <yyyy>$config->{wif}->{yyyy}</yyyy>\n";
        $_results_xml .= "        <mm>$config->{wif}->{mm}</mm>\n";
        $_results_xml .= "        <dd>$config->{wif}->{dd}</dd>\n";
        $_results_xml .= "        <batch>$config->{wif}->{batch}</batch>\n";
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

    write_file("$opt_publish_full".$results_xml_file_name, {append => 1}, $_xml); ## $_xml is a ref, but we do not need to dereference with slurp

    return;
}

#------------------------------------------------------------------
sub _write_html {
    my ($_html) = @_;

    write_file($opt_publish_full.'results.html', {append => 1}, $_html); ## $_html is a ref, but we do not need to dereference with slurp

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
    $results_html .= qq|Start Time: $start_date_time <br />\n|;
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

    $results_xml .= qq|    </testcases>\n\n|;

    my $_TIMESECONDS = ($HOUR * 60 * 60) + ($MINUTE * 60) + $SECOND;
    my $_STARTDATE = "$YEAR-$MONTH-$DAYOFMONTH";

    $results_xml .= qq|    <test-summary>\n|;
    $results_xml .= qq|        <start-time>$start_date_time</start-time>\n|;
    $results_xml .= qq|        <start-seconds>$_TIMESECONDS</start-seconds>\n|;
    $results_xml .= qq|        <start-date-time>$_STARTDATE|;
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
    $results_xml .= qq|        <execution-aborted>$execution_aborted</execution-aborted>\n|;
    $results_xml .= qq|        <test-file-name>$test_file_base_name</test-file-name>\n|;
    $results_xml .= qq|    </test-summary>\n\n|;

    $results_xml .= qq|</results>\n|;

    _write_xml(\$results_xml);
    undef $results_xml;

    return;
}

#------------------------------------------------------------------
sub write_final_stdout {  #write summary and closing text for STDOUT

    $results_stdout .= qq|Start Time: $start_date_time\n|;
    $results_stdout .= qq|Total Run Time: $total_run_time seconds\n\n|;
    $results_stdout .= qq|Total Response Time: $total_response seconds\n\n|;

    $results_stdout .= qq|Test Cases Run: $total_run_count\n|;
    $results_stdout .= qq|Test Cases Passed: $case_passed_count\n|;
    $results_stdout .= qq|Test Cases Failed: $case_failed_count\n|;
    $results_stdout .= qq|Verifications Passed: $passed_count\n|;
    $results_stdout .= qq|Verifications Failed: $failed_count\n\n|;

    if ($opt_publish_full eq $results_output_folder) {
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

	    my $_end = defined $config->{globaltimeout} ? "$config->{globaltimeout};;0" : ';;0';

            if ($case_failed_count > 0) {
	        print "WebInject CRITICAL - $nagios_return_message |time=$total_response;$_end\n";
                exit $_exit_codes{'CRITICAL'};
            }
            elsif ( ($config->{globaltimeout}) && ($total_response > $config->{globaltimeout}) ) {
                print "WebInject WARNING - All tests passed successfully but global timeout ($config->{globaltimeout} seconds) has been reached |time=$total_response;$_end\n";
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
        if (defined $config->{wif}->{environment}) {
            if ( $_ eq $config->{wif}->{environment} ) {
                return 'true';
            }
        }
    }

    return;
}


#------------------------------------------------------------------
sub setcookie {
    if ($case{setcookie}) {
        require URI;
        my $_uri = URI->new($request->uri);

        my @_cookies = split /;/, $case{setcookie};
        foreach my $_cookie (@_cookies) {
            my ($_key, $_value) = split /:/, $_cookie, 2;
            $_key = trim($_key);
            $_value = trim($_value);
            $results_stdout .= " Set cookie -> $_key: $_value\n";
            $cookie_jar->set_cookie( 0, $_key, $_value, '/', $_uri->host, $_uri->port, 0, 0, 86400, 0 )
        }
    }

    return;
}
sub trim { my $_s = shift; $_s =~ s/^\s+|\s+$//g; return $_s };

#------------------------------------------------------------------
# function addcookie is deprecated since it only adds the cookie for the current step
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
sub getresources {

    getallhrefs(); ## get href assets for this step and all following steps
    getallsrcs(); ## get src assets for this step and all following steps
    getbackgroundimages(); ## get specified web page src assets

    return;
}

#------------------------------------------------------------------
sub getallhrefs { ## getallhrefs=".less|.css"
                  ## get page href assets matching a list of ending patterns, separate multiple with |

    if ($case{getallhrefs}) {
        $getallhrefs = $case{getallhrefs};
        $hrefs_version = $testnum;
        undef @hrefs;
    }

    if (not defined $getallhrefs) {
        return;
    }

    my $_match = 'href=';
    my $_delim = q{"}; #"
    get_assets ($_match,$_delim,$_delim,$getallhrefs, 'hrefs', 'version'.$hrefs_version.'_');

    return;
}

#------------------------------------------------------------------
sub getallsrcs { ## getallsrcs=".js|.png|.jpg|.gif"
                 ## get page src assets matching a list of ending patterns, separate multiple with |

    if ($case{getallsrcs}) {
        $getallsrcs = $case{getallsrcs};
        $srcs_version = $testnum;
        undef @srcs;
    }

    if (not defined $getallsrcs) {
        return;
    }

    my $_match = 'src=';
    my $_delim = q{"}; #"
    get_assets ($_match, $_delim, $_delim, $getallsrcs, 'srcs', 'version'.$srcs_version.'_');

    return;
}

#------------------------------------------------------------------
sub getbackgroundimages { ## style="background-image: url( )"

    if ($case{getbackgroundimages}) {
        my $_match = 'style="background-image: url';
        my $_left_delim = '\(';
        my $_right_delim = '\)';
        get_assets ($_match, $_left_delim, $_right_delim, $case{getbackgroundimages}, 'bg-images', 'version1_');
    }

    return;
}

#------------------------------------------------------------------
sub get_assets { ## get page assets matching a list for a reference type
                ## get_assets ('href',q{"},q{"},'.less|.css')

    my ($_match, $_left_delim, $_right_delim, $assetlist, $_type, $_version) = @_;

    require URI::URL; ## So getallhrefs can determine the absolute URL of an asset, and the asset name, given a page url and an asset href

    my ($_start_asset_request, $_end_asset_request, $_asset_latency);
    my ($_asset_ref, $_ur_url, $_asset_url, $_path, $_filename, $_asset_request, $_asset_response);

    my $_page = $response->as_string;

    my @_extensions = split /[|]/, $assetlist ;

    foreach my $_extension (@_extensions) {

        while ($_page =~ m{$_match$_left_delim([^$_right_delim]*$_extension)[$_right_delim?]}g) ##" Iterate over all the matches to this extension
        {
            $_start_asset_request = time;

            $_asset_ref = $1;

            $_ur_url = URI::URL->new($_asset_ref, $case{url}); ## join the current page url together with the href of the asset
            $_asset_url = $_ur_url->abs; ## determine the absolute address of the asset
            $_path = $_asset_url->path; ## get the path portion of the asset location
            $_filename = basename($_path); ## get the filename from the path

            if (defined $asset{$_version . $_filename}) {
                next; ## since all assets are stored in the same folder, there is no point getting an asset again with the same filename
            }
            $asset{$_version . $_filename} = 1; # true

            $results_stdout .= "  GET Asset [$_version$_filename] ...";

            $_asset_request = HTTP::Request->new('GET',"$_asset_url");
            $cookie_jar->add_cookie_header($_asset_request); ## session cookies will be needed

            $_asset_response = $useragent->request($_asset_request);

            write_file( "$results_output_folder$_version$_filename", {binmode => ':raw'}, $_asset_response->content );

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
sub save_page_when_method_post_and_has_action {## to enable auto substitution of hidden fields like __VIEWSTATE and the dynamic component of variable names

    my $_page_action;

    ## if we have a method="post" and action="something" then save the page in the cache
    if ( ($response->as_string =~ m{method="post"[^>]+action="([^"]*)"}s) || ($response->as_string =~ m{action="([^"]*)"[^>]+method="post"}s) ) {
        $_page_action = $1;
        $results_stdout .= qq|\n ACTION $_page_action\n| if $EXTRA_VERBOSE;
    } else {
        $results_stdout .= qq|\n ACTION none\n\n| if $EXTRA_VERBOSE;
        return;
    }

    if (not $_page_action) {
        $results_stdout .= qq| ACTION IS NULL - will use test step url path\n| if $EXTRA_VERBOSE;
        $_page_action = $case{url};
    }

    my $_normalised_page_action = _url_path($_page_action);
    $results_stdout .= qq| SAVING $_normalised_page_action\n| if $EXTRA_VERBOSE;

    my $_page_index_to_write = _find_page_in_cache($_normalised_page_action);

    if (not defined $_page_index_to_write) {
        $_page_index_to_write = _find_free_index_or_oldest_index();
    }

    $cached_page_update_times[$_page_index_to_write] = time;
    $cached_page_actions[$_page_index_to_write] = $_normalised_page_action;
    $cached_pages[$_page_index_to_write] = $response->as_string;

    $results_stdout .= " Saved $cached_page_update_times[$_page_index_to_write]:$cached_page_actions[$_page_index_to_write] \n\n" if $EXTRA_VERBOSE;

    if ($EXTRA_VERBOSE) {
        for my $_i (0 .. $#cached_page_actions) {
             $results_stdout .= " Cache $_i:$cached_page_actions[$_i]:$cached_page_update_times[$_i] \n";
         }
        $results_stdout .= "\n";
    }

    return;
}

sub _url_path { #https://example.com/search/form?terms=cheapest becomes /search/form
        my ($_url) = @_;

        $_url =~ s{[?].*}{}si; ## we only want everything to the left of the ? mark
        $_url =~ s{http.?://}{}si; ## remove http:// and https://
        $_url =~ s{^.*?/}{/}s; ## remove everything to the left of the first / in the path

        return $_url;
}

sub _find_page_in_cache {

    my ($_normalised_page_action) = @_;

    if ($cached_page_actions[0]) { ## does the array contain at least one entry?
        for my $_i (0 .. $#cached_page_actions) {
            if ($cached_page_actions[$_i] =~ m/$_normalised_page_action/si) { ## can we find the post url within the current saved action url?
                $results_stdout .= qq| MATCH at position $_i\n| if $EXTRA_VERBOSE;
                return $_i;
            } else {
                $results_stdout .= qq| NO MATCH on $_i:$cached_page_actions[$_i]\n| if $EXTRA_VERBOSE;
            }
        }
        $results_stdout .= qq| NO MATCHES FOUND IN CACHE!\n| if $EXTRA_VERBOSE;
    } else {
        $results_stdout .= qq| NO CACHED PAGES!\n| if $EXTRA_VERBOSE;
    }

    return;
}

sub _find_free_index_or_oldest_index {

    my $_page_index_to_write;
    if ($#cached_page_actions == $MAX_CACHE_SIZE) {## the cache is full - so we need to overwrite the oldest page in the cache
        $_page_index_to_write = _find_oldest_page_in_cache();
        $results_stdout .= qq|\n Overwriting - Oldest Page Index: $_page_index_to_write\n\n| if $EXTRA_VERBOSE;
    } else {
        $_page_index_to_write = $#cached_page_actions + 1;
        $results_stdout .= qq| Index $_page_index_to_write is free \n\n| if $EXTRA_VERBOSE;
    }

    return $_page_index_to_write;
}

sub _find_oldest_page_in_cache {

    ## assume the first page in the cache is the oldest
    my $_oldest_index = 0;
    my $_oldest_page_time = $cached_page_update_times[0];

    ## if we find an older updated time, use that instead
    for my $i (0 .. $#cached_page_update_times) {
        if ($cached_page_update_times[$i] < $_oldest_page_time) { $_oldest_index = $i; $_oldest_page_time = $cached_page_update_times[$i]; }
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

    if ($EXTRA_VERBOSE) {
        $results_stdout .= " \n There are ".($#_post_fields+1)." fields in the postbody: \n";
        for my $_i (0 .. $#_post_fields) {
            $results_stdout .= '  Field '.($_i+1).": $_post_fields[$_i] \n";
        }
    }

    ## work out pagename to use for matching purposes
    $_post_url = _url_path($_post_url);

    my $_page_id = _find_page_in_cache($_post_url.q{$});
    if (not defined $_page_id) {
        $_post_url =~ s{^.*/}{}s; ## remove the path entirely, except for the page name itself
        $results_stdout .= " REMOVE PATH                : $_post_url".'$'."\n" if $EXTRA_VERBOSE;
        $_page_id = _find_page_in_cache($_post_url.q{$}); ## try again without the full path
    }
    if (not defined $_page_id) {
        $results_stdout .= " DESPERATE MODE - NO ANCHOR : $_post_url\n" if $EXTRA_VERBOSE;
        $_page_id = _find_page_in_cache($_post_url);
    }

    ## there is heavy use of regex in this sub, we need to ensure they are optimised
    my $_start_loop_timer = time if $EXTRA_VERBOSE;

    ## time for substitutions
    if (defined $_page_id) { ## did we find match?
        $results_stdout .= " ID MATCH $_page_id \n" if $EXTRA_VERBOSE;
        for my $_i (0 .. $#_post_fields) { ## loop through each of the fields being posted
            ## substitute {NAME} for actual

            my $_dot_x_found;
            my $_dot_y_found;

            ($_dot_x_found, $_post_fields[$_i]) = _remove_dot_letter_from_field_name_if_present($_post_fields[$_i], 'x');
            ($_dot_y_found, $_post_fields[$_i]) = _remove_dot_letter_from_field_name_if_present($_post_fields[$_i], 'y');
    
            $_post_fields[$_i] = _substitute_name($_post_fields[$_i], $_page_id, $_post_type);

            ## substitute {DATA} for actual
            $_post_fields[$_i] = _substitute_data($_post_fields[$_i], $_page_id, $_post_type);

            if ($_dot_x_found) {
                $_post_fields[$_i] = _restore_dot_letter_to_field_name($_post_fields[$_i], $_post_type, 'x');
            }

            if ($_dot_y_found) {
                $_post_fields[$_i] = _restore_dot_letter_to_field_name($_post_fields[$_i], $_post_type, 'y');
            }
    
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
    $results_stdout .= qq|\n\n POSTBODY is $_post_body \n| if $EXTRA_VERBOSE;

    my $_loop_latency = (int(1000 * (time - $_start_loop_timer)) / 1000) if $EXTRA_VERBOSE;
    $results_stdout .= qq| Auto substitution latency was $_loop_latency \n| if $EXTRA_VERBOSE;

    return $_post_body;
}

sub _remove_dot_letter_from_field_name_if_present {
    my ($_post_field, $_dot_letter) = @_;

    ## does the field name end in .x or .y e.g. btnSubmit.x? The .x bit won't be in the saved page
    if ( $_post_field =~ m{[.]$_dot_letter[=']} ) { ## does it end in .x or .y? #'
        $results_stdout .= qq| DOT$_dot_letter found in $_post_field \n| if $EXTRA_VERBOSE;
        $_post_field =~ s{[.]$_dot_letter}{}; ## remove first occurence only - so value not affected
        return 1, $_post_field;
    }

    return 0, $_post_field;
}    

sub _restore_dot_letter_to_field_name {
    my ($_post_field, $_post_type, $_post_letter) = @_;

    if ($_post_type eq 'normalpost') {
        $_post_field =~ s{[=]}{\.$_post_letter\=};
    } else {
        $_post_field =~ s{['][ ]?\=}{\.$_post_letter\' \=}; #[ ]? means match 0 or 1 space #'
    }
    $results_stdout .= qq| DOT$_post_letter restored to $_post_field \n| if $EXTRA_VERBOSE;

    return $_post_field;
}

sub _substitute_name {
    my ($_post_field, $_page_id, $_post_type) = @_;

    ## look for characters to the left and right of {NAME} and save them
    if ( $_post_field =~ m/([^'"]{0,70}?)[{]NAME[}]([^='"]{0,70})/s ) { ## '" was *?, {0,70}? much quicker
        my $_lhs_name = $1;
        my $_rhs_name = $2;

        $_lhs_name =~ s{\$}{\\\$}g; ## protect $ with \$
        $_lhs_name =~ s{[.]}{\\\.}g; ## protect . with \.
        $results_stdout .= qq| LHS of {NAME}: [$_lhs_name] \n| if $EXTRA_VERBOSE;

        $_rhs_name =~ s{%24}{\$}g; ## change any encoding for $ (i.e. %24) back to a literal $ - this is what we'll really find in the html source
        $_rhs_name =~ s{\$}{\\\$}g; ## protect the $ with a \ in further regexs
        $_rhs_name =~ s{[.]}{\\\.}g; ## same for the .
        $results_stdout .= qq| RHS of {NAME}: [$_rhs_name] \n| if $EXTRA_VERBOSE;

        ## find out what to substitute it with, then do the substitution
        ##
        ## saved page source will contain something like
        ##    <input name="pagebody_3$left_7$txtUsername" id="pagebody_3_left_7_txtUsername" />
        ## so this code will find that {NAME}Username will match pagebody_3$left_7$txt for {NAME}
        if ($cached_pages[$_page_id] =~ m/name=['"]$_lhs_name([^'"]{0,70}?)$_rhs_name['"]/s) { ## "
            my $_name = $1;
            $results_stdout .= qq| NAME is $_name \n| if $EXTRA_VERBOSE;

            ## substitute {NAME} for the actual (dynamic) value
            $_post_field =~ s/{NAME}/$_name/;
            $results_stdout .= qq| SUBBED NAME is $_post_field \n| if $EXTRA_VERBOSE;
        }
    }

    return $_post_field;
}

sub _substitute_data {
    my ($_post_field, $_page_id, $_post_type) = @_;

    my $_target_field;

    if ($_post_type eq 'normalpost') {
        if ($_post_field =~ m/(.{0,70}?)=[{]DATA}/s) {
            $_target_field = $1;
            $results_stdout .= qq| Normal field $_target_field has {DATA} \n| if $EXTRA_VERBOSE;
        }
    }

    if ($_post_type eq 'multipost') {
        if ($_post_field =~ m/['](.{0,70}?)['].{0,70}?[{]DATA}/s) {
            $_target_field = $1;
            $results_stdout .= qq| Multi field $_target_field has {DATA} \n| if $EXTRA_VERBOSE;
        }
    }

    ## find out what to substitute it with, then do the substitution
    if (defined $_target_field) {
        $_target_field =~ s{\$}{\\\$}; ## protect $ with \$ for final substitution
        $_target_field =~ s{[.]}{\\\.}; ## protect . with \. for final substitution
        if ($cached_pages[$_page_id] =~ m/="$_target_field" [^\>]*value="(.*?)"/s) {
            my $_data = $1;
            $results_stdout .= qq| DATA is $_data \n| if $EXTRA_VERBOSE;

            ## normal post must be escaped
            if ($_post_type eq 'normalpost') {
                $_data = uri_escape($_data);
                $results_stdout .= qq| URLESCAPE!! \n| if $EXTRA_VERBOSE;
            }

            ## substitute in the data
            if ($_post_field =~ s/{DATA}/$_data/) {
                $results_stdout .= qq| SUBBED FIELD is $_post_field \n| if $EXTRA_VERBOSE;
            }

        }
    }

    return $_post_field;
}

#------------------------------------------------------------------
sub httpget {  #send http request and read response

    $request = HTTP::Request->new('GET',"$case{url}");

    setcookie ();
    $cookie_jar->add_cookie_header($request);

    addcookie (); ## append additional cookies rather than overwriting with add header

    if ($case{addheader}) {  #add an additional HTTP Header if specified
        my @_add_headers = split /[|]/, $case{addheader} ;  #can add multiple headers with a pipe delimiter
        foreach (@_add_headers) {
            $_ =~ m/(.*): (.*)/;
            if ($1) {$request->header($1 => $2);}  #using HTTP::Headers Class
        }
    }

    my $_start_timer = time;
    $response = $useragent->request($request);
    $latency = _get_latency_since($_start_timer);

    $cookie_jar->extract_cookies($response);
    #print $cookie_jar->as_string; print "\n\n";

    save_page_when_method_post_and_has_action ();

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

    save_page_when_method_post_and_has_action ();

    return;
}

#------------------------------------------------------------------
sub httpsend_form_urlencoded {  #send application/x-www-form-urlencoded or application/json HTTP request and read response
    my ($_verb) = @_;

    my $_substituted_postbody; ## auto substitution
    $_substituted_postbody = auto_sub("$case{postbody}", 'normalpost', "$case{url}");

    $request = HTTP::Request->new($_verb,"$case{url}");
    $request->content_type("$case{posttype}");
    $request->content("$_substituted_postbody");

    setcookie ();
    $cookie_jar->add_cookie_header($request);

    addcookie (); ## append to additional cookies rather than overwriting with add header

    if ($case{addheader}) {  # add an additional HTTP Header if specified
        my @_add_headers = split /[|]/, $case{addheader} ;  #can add multiple headers with a pipe delimiter
        foreach (@_add_headers) {
            $_ =~ m{(.*): (.*)};
            if ($1) {$request->header($1 => $2);}  #using HTTP::Headers Class
        }
    }

    my $_start_timer = time;
    $response = $useragent->request($request);
    $latency = _get_latency_since($_start_timer);

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

    my $_start_timer = time;
    $response = $useragent->request($request);
    $latency = _get_latency_since($_start_timer);

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
    setcookie ();
    $cookie_jar->add_cookie_header($request);

    addcookie (); ## append additional cookies rather than overwriting with add header

    if ($case{addheader}) {  #add an additional HTTP Header if specified
        my @_add_headers = split /[|]/, $case{addheader} ;  #can add multiple headers with a pipe delimiter
        foreach (@_add_headers) {
            $_ =~ m/(.*): (.*)/;
            if ($1) {$request->header($1 => $2);}  #using HTTP::Headers Class
        }
    }

    my $_start_timer = time;
    $response = $useragent->request($request);
    $latency = _get_latency_since($_start_timer);

    $cookie_jar->extract_cookies($response);

    return;
}

#------------------------------------------------------------------
sub cmd {  ## send terminal command and read response

    my $_combined_response=q{};
    $request = HTTP::Request->new('GET','CMD');
    my $_start_timer = time;

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
    $latency = _get_latency_since($_start_timer);

    return;
}

#------------------------------------------------------------------
sub _get_latency_since {
    my ($_start_timer) = @_;

    return (int(1000 * (time - $_start_timer )) / 1000);  ## elapsed time rounded to thousandths

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
        ${$_parm} =~ s{\\}{\\\\}g; ## need to double back slashes in Linux, otherwise they vanish (unlike Windows shell)
        ${$_parm} =~ s/{SLASH}/\//g;
        ${$_parm} =~ s{^[.][/\\]}{perl ./}; ## for running perl scripts from within webinject using perlbrew
        ${$_parm} =~ s/{SHELL_ESCAPE}/\\/g;
    }

    return;
}

#------------------------------------------------------------------
sub run_special_command {  ## for commandonerror and commandonfail

    my ($_command_parameter) = @_;

    my $_combined_response = $response->as_string; ## take the existing test response

    if ($case{$_command_parameter}) {
        my $_cmd = $case{$_command_parameter};
        $_cmd =~ s/\%20/ /g; ## turn %20 to spaces for display in log purposes
        _shell_adjust(\$_cmd);
        my $_cmdresp = (`$_cmd 2>\&1`); ## run the cmd through the backtick method - 2>\&1 redirects error output to standard output
        $_combined_response =~ s{$}{<$_>$_cmd</$_>\n$_cmdresp\n\n\n}; ## include it in the response
    }

    $response = HTTP::Response->parse($_combined_response); ## put the test response along with the command on error response back in the response

    return;
}

#------------------------------------------------------------------
sub dump_json {
    require Data::Dumper;

	if ($case{dumpjson}) {
		 my $_dumped = eval { Data::Dumper::Dumper(decode_json $response->content) };
		 $response->content($_dumped); ## overwrite the existing content with the json dumped content
	}

    return;
}

#------------------------------------------------------------------
sub decode_smtp {

	if ($case{decodesmtp}) {
		 my $_decoded = $response->as_string;
		 $_decoded =~ s/(^|\v)\.\./$1\./g; ## http://tools.ietf.org/html/rfc5321#section-4.5.2
		 $response = HTTP::Response->parse($_decoded);
	}

    return;
}

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

    if ($testfile_contains_selenium) { WebInjectSelenium::searchimage(); } ## search for images within actual screen or page grab

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
                colour_stdout('red bold', "Failed Response Time Verification - should be at most $case{verifyresponsetime}, got $latency \n");
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
            colour_stdout('red bold', 'Failed HTTP Response Code Verification (received ' . $response->code() .  qq|, expecting $case{verifyresponsecode}) \n|);
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
                    colour_stdout('red bold', "Failed HTTP Response Code Verification ($1$2) \n"); #($1$2) is HTTP response code
                }
                else {  #no HTTP response returned.. could be error in connection, bad hostname/address, or can not connect to web server
                    $results_html .= qq|<span class="fail">Failed - No Response</span><br />\n|; #($1$2) is HTTP response code
                    $results_xml .= qq|            <verifyresponsecode-success>false</verifyresponsecode-success>\n|;
                    $results_xml .= qq|            <verifyresponsecode-message>Failed - No Response</verifyresponsecode-message>\n|;
                    colour_stdout('red bold', "Failed - No Response \n"); #($1$2) is HTTP response code
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

    if (($case{commandonerror}) && ($is_failure > 0)) { ## if an assertion failed, run a command - even if we retry
        run_special_command('commandonerror');
    }

    return;
}

sub _verify_autoassertion {

    foreach my $_config_attribute ( sort keys %{ $config->{autoassertions} } ) {
        if ( (substr $_config_attribute, 0, 13) eq 'autoassertion' ) {
            my $_verify_number = $_config_attribute; ## determine index verifypositive index
            $_verify_number =~ s/^autoassertion//g; ## remove autoassertion from string
            if (!$_verify_number) {$_verify_number = '0';} #In case of autoassertion, need to treat as 0
            my @_verifyparms = split /[|][|][|]/, $config->{autoassertions}{$_config_attribute} ; #index 0 contains the actual string to verify, 1 the message to show if the assertion fails, 2 the tag that it is a known issue
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
                    colour_stdout('red bold', "Failed Auto Assertion \n");
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

    foreach my $_config_attribute ( sort keys %{ $config->{smartassertions} } ) {
        if ( (substr $_config_attribute, 0, 14) eq 'smartassertion' ) {
            my $_verify_number = $_config_attribute; ## determine index verifypositive index
            $_verify_number =~ s/^smartassertion//g; ## remove smartassertion from string
            if (!$_verify_number) {$_verify_number = '0';} #In case of smartassertion, need to treat as 0
            my @_verifyparms = split /[|][|][|]/, $config->{smartassertions}{$_config_attribute} ; #index 0 contains the pre-condition assertion, 1 the actual assertion, 3 the tag that it is a known issue
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
                    colour_stdout('red bold', 'Failed Smart Assertion');
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

    foreach my $_case_attribute ( sort keys %case ) {
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
                    colour_stdout('red bold', "Failed Positive Verification $_verify_number\n");
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

    foreach my $_case_attribute ( sort keys %case ) {
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
                    colour_stdout('red bold', "Failed Negative Verification $_verify_number\n");
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

    foreach my $_case_attribute ( sort keys %case ) {
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
                $results_xml .= "            <$_case_attribute>\n";
                if ($_count == $_verify_count_parms[1]) {
                    $results_html .= qq|<span class="pass">Passed Count Assertion of $_verify_count_parms[1]</span><br />\n|;
                    $results_xml .= qq|                <success>true</success>\n|;
                    $results_stdout .= "Passed Count Assertion of $_verify_count_parms[1] \n";
                    $passed_count++;
                    $retry_passed_count++;
                }
                else {
                    $results_xml .= qq|                <success>false</success>\n|;
                    if ($_verify_count_parms[2]) {## if there is a custom message, write it out
                        $results_html .= qq|<span class="fail">Failed Count Assertion of $_verify_count_parms[1], got $_count</span><br />\n|;
                        $results_html .= qq|<span class="fail">$_verify_count_parms[2]</span><br />\n|;
                        $results_xml .= '                <message>'._sub_xml_special($_verify_count_parms[2])." [got $_count]</message>\n";
                    }
                    else {# we make up a standard message
                        $results_html .= qq|<span class="fail">Failed Count Assertion of $_verify_count_parms[1], got $_count</span><br />\n|;
                        $results_xml .= qq|            <$_case_attribute-message>Failed Count Assertion of $_verify_count_parms[1], got $_count</$_case_attribute-message>\n|;
                        $results_xml .= "                <message>Failed Count Assertion of $_verify_count_parms[1], got $_count</message>\n";
                    }
                    colour_stdout('red bold', "Failed Count Assertion of $_verify_count_parms[1], got $_count \n");
                    if ($_verify_count_parms[2]) {
                        $results_stdout .= "$_verify_count_parms[2] \n";
                    }
                    $failed_count++;
                    $retry_failed_count++;
                    $is_failure++;
                } ## end else _verifycountparms[2]
                $results_xml .= qq|            </$_case_attribute>\n|;
            } ## end else _verifycountparms[3]
        } ## end if assertcount
    } ## end foreach

    return;
}

#------------------------------------------------------------------
sub parseresponse {  #parse values from responses for use in future request (for session id's, dynamic URL rewriting, etc)

    my ($_response_to_parse, @_parse_args);
    my ($_left_boundary, $_right_boundary, $_escape);

    foreach my $_case_attribute ( sort keys %case ) {

        if ( (substr $_case_attribute, 0, 13) eq 'parseresponse' ) {

            @_parse_args = split /[|]/, $case{$_case_attribute} ;

            $_left_boundary = $_parse_args[0]; $_right_boundary = $_parse_args[1]; $_escape = $_parse_args[2];

            $parsedresult{$_case_attribute} = ''; ## clear out any old value first

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
sub write_shared_variable {

    if ($case{writesharedvar}) {
        _initialise_shared_variables();
        my ($_var_name, $_var_value) = split /\|/, $case{writesharedvar};
        my ($_second, $_minute, $_hour, undef, undef, undef, undef, undef, undef, undef) = get_formatted_datetime_for_seconds_since_epoch(time);
        my $_file_full = slash_me($shared_folder_full.'/'.$_var_name.'___'.$_hour.$_minute.$_second.'.txt');
        write_file ( $_file_full, $_var_value);
        $results_stdout .= " Wrote $_file_full\n";
    }

    return;
}

sub read_shared_variable {

    if ($case{readsharedvar}) {
        _initialise_shared_variables();
        my @_vars = glob(slash_me($shared_folder_full.'/'.$case{readsharedvar}.'___*'));
    
        my @_sorted_vars = sort { -M $a <=> -M $b } @_vars; ## -C is created, -M for modified

        if ($_sorted_vars[0]) { ## only the most recent variable value is relevant
            $varvar{'var'.$case{readsharedvar}} = read_file($_sorted_vars[0]);
            $results_stdout .= " Read  $_sorted_vars[0]\n";
        } else {
            $varvar{'var'.$case{readsharedvar}} = ''; ## set variable to null if it does not exist
            $results_stdout .= " Set  {$case{readsharedvar}} to null\n";
        }
    }

    return;
}

sub _initialise_shared_variables {

    $shared_folder_full = '/tmp';
    if ($is_windows) {
        $shared_folder_full = $ENV{TEMP};
    }

    $shared_folder_full .= '/WebInjectSharedVariables/';
    $shared_folder_full .= $YEAR . $MONTH . $DAYOFMONTH;
    File::Path::make_path ( slash_me($shared_folder_full) );

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
        $config = XMLin("$_config_file_path"); ## Parse as XML for the user defined config
    } else {
        die "\nNo config file specified and no config.xml found in current working directory\n\n";
    }

    if (($#ARGV + 1) > 2) {  #too many command line args were passed
        die "\nERROR: Too many arguments\n\n";
    }

    if (($#ARGV + 1) < 1) {  #no command line args were passed
        #if testcase filename is not passed on the command line, use files in config.xml

        if ($config->{testcasefile}) {
            $current_case_file = slash_me($config->{testcasefile});
        } else {
            die "\nERROR: I can't find any test case files to run.\nYou must either use a config file or pass a filename."; ## no critic(RequireCarping)
        }

    }

    elsif (($#ARGV + 1) == 1) {  #one command line arg was passed
        #use testcase filename passed on command line (config.xml is only used for other options)
        $current_case_file = slash_me($ARGV[0]);  #first commandline argument is the test case file
    }

    if ($config->{httpauth}) {
        if ( ref($config->{httpauth}) eq 'ARRAY') {
            #print "We have an array of httpauths\n";
            for my $_auth ( @{ $config->{httpauth} } ) { ## $config->{httpauth} is an array
                _push_httpauth ($_auth);
            }
        } else {
            #print "Not an array - we just have one httpauth\n";
            _push_httpauth ($config->{httpauth});
        }
    }

    if (not defined $config->{globaljumpbacks}) { ## default the globaljumpbacks if it isn't in the config file
        $config->{globaljumpbacks} = 5;
    }

    if ($opt_ignoreretry) { ##
        $config->{globalretry} = -1;
        $config->{globaljumpbacks} = 0;
    }

    if (defined $config->{autoretry}) {
        $auto_retry = $config->{autoretry};
    }

    # find the name of the output folder only i.e. not full path - OS safe
    my $_abs_output_full = File::Spec->rel2abs( $results_output_folder ) . '/dummy';
    $concurrency =  basename ( dirname($_abs_output_full) );

    $outsum = unpack '%32C*', $results_output_folder; ## checksum of output directory name - for concurrency
    #print "outsum $outsum \n";

    if (defined $config->{ports_variable}) {
        if ($config->{ports_variable} eq 'convert_back') {
            $convert_back_ports = 'true';
        }

        if ($config->{ports_variable} eq 'null') {
            $convert_back_ports_null = 'true';
        }
    }

    if (defined $config->{reporttype}) {
        $report_type = lc $config->{reporttype};
        if ($report_type ne 'standard') {
            $opt_no_output = 'true'; ## no standard output for plugins like nagios
        }
    }

    my $_os;
    if ($is_windows) { $_os = 'windows'; }
    $_os //= 'linux';
    
    if (defined $config->{$_os}->{'chromedriver-binary'}) {
        $opt_chromedriver_binary //= $config->{$_os}->{'chromedriver-binary'}; # default to value from config file if present
    }

    if (defined $config->{$_os}->{'selenium-binary'}) {
        $opt_selenium_binary //= $config->{$_os}->{'selenium-binary'};
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

    $_clean =~ s/&amp;/{{A}}/g;
    $_clean =~ s/&/&amp;/g;
    $_clean =~ s/[{][{]A}}/&amp;/g;
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

    my $_path = slash_me ($results_output_folder.'parse_error');

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
    $_include =~ s{\n(\s*)retryfromstep[\s]*=[\s]*"}{"\n".$1.'retryfromstep="'.$_id.'.'}eg; #'

    #open my $_INCLUDE, '>', "$results_output_folder".'include.xml' or die "\nERROR: Failed to open include debug file\n\n";
    #print {$_INCLUDE} $_include;
    #close $_INCLUDE or die "\nERROR: Failed to close include debug file\n\n";

    return $_include;
}

#------------------------------------------------------------------
sub _does_testfile_contain_selenium {
    my ($_text) = @_; # sub is passed reference to file contents in string

    if ( ${$_text} =~ m/(["'])selenium(['"])/ ) {
        return 'true';
    }

    return 0;
}

#------------------------------------------------------------------
## no critic (RequireArgUnpacking)
sub convert_back_xml {  #converts replaced xml with substitutions

## perform substitution modifiers first

    my $_YEAR = $YEAR;
    my $_YY = $YY;
    my $_MONTH = $MONTH;
    my $_MONTH_TEXT = $MONTH_TEXT;
    my $_DAY_TEXT = $DAY_TEXT;
    my $_DAYOFMONTH = $DAYOFMONTH;
    my $_WEEKOFMONTH = $WEEKOFMONTH;
    my $_MINUTE = $MINUTE;
    my $_SECOND = $SECOND;
    my $_HOUR = $HOUR;

    if ($_[0] =~ s|{DATE:::([+\-*/\d]+)}||g) {
        ($_SECOND, $_MINUTE, $_HOUR, $_DAYOFMONTH, $_DAY_TEXT, $_WEEKOFMONTH, $_MONTH, $_MONTH_TEXT, $_YEAR, $_YY) = get_formatted_datetime_for_seconds_since_epoch($start_time + (eval($1)*86400));
    }

## perform arbirtary user defined config substituions - done first to allow for double substitution e.g. {:8080}
    my ($_value, $_KEY);
    foreach my $_key (keys %{ $config->{userdefined} } ) {
        $_value = $config->{userdefined}{$_key};
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
    $_[0] =~ s/{TESTFILENAME}/$test_file_base_name/g;
    $_[0] =~ s/{LENGTH}/$_my_length/g; #length of the previous test step response
    $_[0] =~ s/{AMPERSAND}/&/g;
    $_[0] =~ s/{LESSTHAN}/</g;
    $_[0] =~ s/{SINGLEQUOTE}/'/g; #'
    $_[0] =~ s/{TIMESTAMP}/$epoch_seconds.$epoch_split/g;
    $_[0] =~ s/{EPOCHSECONDS}/$epoch_seconds/g;
    $_[0] =~ s/{EPOCHSPLIT}/$epoch_split/g;
    $_[0] =~ s/{STARTTIME}/$start_time/g;
    $_[0] =~ s/{OPT_PROXY}/$opt_proxy/g;
    $_[0] =~ s/{TESTSTEPTIME:(\d+)}/$test_step_time{$1}/g; #latency for test step number; example usage: {TESTSTEPTIME:5012}
    $_[0] =~ s/{RANDOM:(\d+)(:*[[:alpha:]]*)}/_get_random_string($1, $2)/eg;

    if (defined $convert_back_ports) {
        $_[0] =~ s/{:(\d+)}/:$1/;
    } elsif (defined $convert_back_ports_null) {
        $_[0] =~ s/{:(\d+)}//;
    }

## day month year constant support #+{DAY}.{MONTH}.{YEAR}+{HH}:{MM}:{SS}+ - when execution started
    $_[0] =~ s/{DAY}/$_DAYOFMONTH/g;
    $_[0] =~ s/{DAYTEXT}/$_DAY_TEXT/g;
    $_[0] =~ s/{MONTH}/$_MONTH/g;
    $_[0] =~ s/{MONTHTEXT}/$_MONTH_TEXT/g;
    $_[0] =~ s/{YEAR}/$_YEAR/g; #4 digit year
    $_[0] =~ s/{YY}/$_YY/g; #2 digit year
    $_[0] =~ s/{HH}/$_HOUR/g;
    $_[0] =~ s/{MM}/$_MINUTE/g;
    $_[0] =~ s/{SS}/$_SECOND/g;
    $_[0] =~ s/{WEEKOFMONTH}/$_WEEKOFMONTH/g;
    $_[0] =~ s/{DATETIME}/$_YEAR$_MONTH$_DAYOFMONTH$_HOUR$_MINUTE$_SECOND/g;
    my $_underscore = '_';
    $_[0] =~ s{{FORMATDATETIME}}{$_DAYOFMONTH\/$_MONTH\/$_YEAR$_underscore$_HOUR:$_MINUTE:$_SECOND}g;

    $_[0] =~ s/{COUNTER}/$counter/g;
    $_[0] =~ s/{CONCURRENCY}/$concurrency/g; ## name of the temporary folder being used - not full path
    $_[0] =~ s/{OUTPUT}/$results_output_folder/g;
    $_[0] =~ s/{PUBLISH}/$opt_publish_full/g;
    $_[0] =~ s/{OUTSUM}/$outsum/g;
    $_[0] =~ s/{CWD}/$this_script_folder_full/g; ## CWD Current Working Directory

## parsedresults moved before config so you can have a parsedresult of {BASEURL2} say that in turn gets turned into the actual value

    ##substitute all the parsed results back
    ##parseresponse = {}, parseresponse5 = {5}, parseresponseMYVAR = {MYVAR}
    foreach my $_case_attribute ( sort keys %{parsedresult} ) {
       my $_parse_var = substr $_case_attribute, 13;
       $_[0] =~ s/\{$_parse_var}/$parsedresult{$_case_attribute}/g;
    }

    $_[0] =~ s/{BASEURL}/$config->{baseurl}/g;
    $_[0] =~ s/{BASEURL1}/$config->{baseurl1}/g;
    $_[0] =~ s/{BASEURL2}/$config->{baseurl2}/g;

    $_[0] =~ s/\[\[\[\|(.{1,80})\|\]\]\]/pack('H*',$1)/eg;

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
    my $_first;
    foreach my $_i (1..$_length) {
        $_next = _get_char($_rng->irand(), $_type);

        ## this clause stops two consecutive characters being the same
        ## some search engines will filter out words containing more than 2 letters the same in a row
        if (defined $_last) {
            while ($_next eq $_last) {
                $_next = _get_char($_rng->irand(), $_type);
            }
        }

        ## never generate 0 as the first character, leading zeros can be problematic
        if (not defined $_first) {
            while ($_next eq '0') {
                $_next = _get_char($_rng->irand(), $_type);
            }
            $_first = $_next;
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

    my ($_second, $_minute, $_hour, $_dayofmonth, undef, undef, $_month, undef, $_year, undef) = get_formatted_datetime_for_seconds_since_epoch(time);
    my $_underscore = '_';
    $_[0] =~ s{{NOW}}{$_dayofmonth\/$_month\/$_year$_underscore$_hour:$_minute:$_second}g;

    return;
}

#------------------------------------------------------------------
sub convert_back_var_variables {
    foreach my $_case_attribute ( sort keys %{varvar} ) {
       if ($late_sub{$_case_attribute}) {
           next;
       }
       my $_sub_var = substr $_case_attribute, 3;
       $_[0] =~ s/{$_sub_var}/$varvar{$_case_attribute}/g;
    }

    return;
}

#------------------------------------------------------------------
sub late_convert_back_var_variables {
    foreach my $_case_attribute ( sort keys %{varvar} ) {
       my $_sub_var = substr $_case_attribute, 3;
       $_[0] =~ s/{$_sub_var}/$varvar{$_case_attribute}/g;
    }

    return;
}

## use critic
#------------------------------------------------------------------
sub set_var_variables { ## e.g. varRUNSTART="{HH}{MM}{SS}"
    foreach my $_case_attribute ( sort keys %case ) {
       if ( (substr $_case_attribute, 0, 3) eq 'var' ) {
            $varvar{$_case_attribute} = $case{$_case_attribute}; ## assign the variable
        }
    }

    return;
}

#------------------------------------------------------------------
sub late_substitute_var_variables {

    foreach my $_case_attribute ( keys %case ) {
        late_convert_back_var_variables($case{$_case_attribute});
    }

    return;
}

#------------------------------------------------------------------
sub set_late_var_list {
    foreach my $_case_attribute ( sort keys %case ) {
       if ( (substr $_case_attribute, 0, 3) eq 'var' ) {
            $late_sub{$_case_attribute} = 1;
        }
    }
    if ($case{readsharedvar}) {
        $late_sub{'var'.$case{readsharedvar}} = 1;
    }

    return;
}

#------------------------------------------------------------------
sub set_eval_variables { ## e.g. evalDIFF="10-5"
    foreach my $_case_attribute ( sort keys %case ) {
       if ( (substr $_case_attribute, 0, 4) eq 'eval' ) {
            $varvar{'var'.substr $_case_attribute, 4} = eval "$case{$_case_attribute}"; ## assign the variable
            my $_debug = $varvar{'var'.substr $_case_attribute, 4};
            #print 'var'.substr $_case_attribute, 4;
            #print " -> (eval) is [$_debug]\n";
        }
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
        write_file( "$results_output_folder$case{logresponseasfile}", {binmode => ':raw'}, $response->content ); #content just outputs the content, whereas as_string includes the response header
    }

    my $_step_info = "Test Step: $testnum_display$jumpbacks_print$retries_print - ";

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

    my $_core_info = "\n".$response->status_line( )."\n";

    my $_response_base;
    if ( eval { defined $response->base( ) } ) {
        $_response_base = $response->base( );
        $_core_info .= 'Base for relative URLs: '.$_response_base."\n";
        $_core_info .= 'Expires: '.scalar(localtime( $response->fresh_until( ) ))."\n";
    }

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
    if (defined $config->{wif}->{batch} ) {
        $_wif_batch = $config->{wif}->{batch};
        $_wif_run_number = $config->{wif}->{run_number};
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
        $_html .= qq|                &nbsp; &nbsp; [<a class="wi_hover_item" style="color:SlateGray;font-weight:bolder;" href="$results_filename_prefix$previous_test_step.html"> prev </a>]\n|;
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

    if (defined $config->{relativetoabsolute} && defined $_response_base) {
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
    ${$_html} .= qq|            <meta charset="utf-8"/>\n|;
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
        ${$_html} .= qq|<br /><img style="position: relative; left: 50%; transform: translateX(-50%);" alt="screenshot of test step $testnum_display$jumpbacks_print$retries_print" src="$results_filename_prefix$testnum_display$jumpbacks_print$retries_print.png"><br />|;
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
        ${$_html} .= qq|<br /><A style="font-family: Verdana; font-size:2.5em;" href="$results_filename_prefix$testnum_display$jumpbacks_print$retries_print.eml">&nbsp; Link to actual eMail file &nbsp;</A><br /><br />|;
    }

    return;
}

#------------------------------------------------------------------
sub _response_content_substitutions {
    my ($_response_content_ref) = @_;

    foreach my $_sub ( keys %{ $config->{content_subs} } ) {
        #print "_sub:$_sub:$config->{content_subs}{$_sub}\n";
        my @_regex = split /[|][|][|]/, $config->{content_subs}{$_sub}; #index 0 contains the LHS, 1 the RHS
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
            return 'href="'.'version'.$hrefs_version.'_'.$_;
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
            return 'src="'.'version'.$srcs_version.'_'.$_;
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
            return 'style="background-image: url('.'version1_'.$_;
        }
    }

    # we did not grab that asset, so we will substitute it with itself
    return 'style="background-image: url('.$1; ##no critic(RegularExpressions::ProhibitCaptureWithoutTest)
}

#------------------------------------------------------------------
sub _replace_relative_urls_with_absolute {
    my ($_response_content_ref, $_response_base) = @_;

    # first we need to see if there are any substitutions defined for the base url - e.g. turn https: to http:
    foreach my $_sub ( keys %{ $config->{baseurl_subs} } ) {
        #print "_sub:$_sub:$config->{baseurl_subs}{$_sub}\n";
        #print "orig _response_base:$_response_base\n";
        my @_regex = split /[|][|][|]/, $config->{baseurl_subs}{$_sub}; #index 0 contains the LHS, 1 the RHS
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
            $delayed_html =~ s{</h2>}{ &nbsp; &nbsp; [<a class="wi_hover_item" style="color:SlateGray;font-weight:bolder;" href="$results_filename_prefix$testnum_display$jumpbacks_print$retries_print.html"> next </a>]</h2>};
        }
        if (not $opt_no_output) {
            open my $_FILE, '>:encoding(UTF-8)', "$delayed_file_full" or die "\nERROR: Failed to create $delayed_file_full\n\n";
            print {$_FILE} decode('utf-8', $delayed_html);
            close $_FILE or die "\nERROR: Failed to close $delayed_file_full\n\n";
        }
    }

    $delayed_file_full = $_file_full;
    $delayed_html = $_html;

    return;
}

#------------------------------------------------------------------
sub final_tasks {  #do ending tasks

    if (not $total_run_count) {$total_run_count = 2}; ## prevent division by 0
    $total_run_time = (int(1000 * (time - $start_time)) / 1000);  #elapsed time rounded to thousandths
    $avg_response = (int(1000 * ($total_response / $total_run_count)) / 1000);  #avg response rounded to thousandths

    # write out the html for the final test step, there is no new content to put in the buffer
    _delayed_write_step_html(undef, undef);

    $total_response = sprintf '%.3f', $total_response;

    write_final_html();  #write summary and closing tags for results file
    write_final_xml();  #write summary and closing tags for XML results file
    write_final_stdout();  #write summary and closing tags for STDOUT

    ## shut down the Selenium session and Selenium Server last - it is less important than closing the files
    if ($testfile_contains_selenium) {
        WebInjectSelenium::shutdown_selenium();
    }

    return;
}

#------------------------------------------------------------------
sub start_session {     ## creates the webinject user agent

    require IO::Socket::SSL;
    #require Crypt::SSLeay;  #for SSL/HTTPS (you may comment this out if you don't need it)
    require HTTP::Cookies;

    push(@LWP::Protocol::http::EXTRA_SOCK_OPTS, MaxLineLength => 0); ## to prevent: Header line too long (limit is 8192)

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
    if ($config->{proxy}) {
        $useragent->proxy(['http', 'https'], "$config->{proxy}")
    }

    #add http basic authentication support
    #corresponds to:
    #$useragent->credentials('servername:portnumber', 'realm-name', 'username' => 'password');
    if (@http_auth) {
        #add the credentials to the user agent here. The foreach gives the reference to the tuple ($elem), and we
        #deref $elem to get the array elements.
        foreach my $_elem(@http_auth) {
            #$results_stdout .= "adding credential: $_elem->[1]:$_elem->[2], $_elem->[3], $_elem->[4] => $_elem->[5]\n";
            $useragent->credentials("$_elem->[1]:$_elem->[2]", "$_elem->[3]", "$_elem->[4]" => "$_elem->[5]");
        }
    }

    #change response delay timeout in seconds if it is set in config.xml
    if ($config->{timeout}) {
        $useragent->timeout("$config->{timeout}");  #default LWP timeout is 180 secs.
    }

    my $_set_user_agent;
    if ($config->{useragent}) {
        $_set_user_agent = $config->{useragent};
        if ($_set_user_agent) { #http useragent that will show up in webserver logs
            $useragent->agent($_set_user_agent);
        }
    }

    if ($testfile_contains_selenium) { WebInjectSelenium::start_selenium_browser(); }  ## start selenium browser if applicable. If it is already started, close browser then start it again.

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
        'i|ignoreretry'   => \$opt_ignoreretry,
        'z|no-colour'   => \$opt_no_colour,
        'n|no-output'   => \$opt_no_output,
        'e|verbose'   => \$opt_verbose,
        'u|publish-to=s' => \$opt_publish_full,
        'd|driver=s'   => \$opt_driver, ## Selenium plugin options start here
        'r|chromedriver-binary=s'   => \$opt_chromedriver_binary,
        's|selenium-binary=s'   => \$opt_selenium_binary,
        't|selenium-host=s'   => \$opt_selenium_host,
        'p|selenium-port=s'   => \$opt_selenium_port,
        'l|headless'   => \$opt_headless,
        'k|keep-session'   => \$opt_keep_session,
        'm|resume-session'   => \$opt_resume_session,
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

    $opt_output //= 'output/';
    $opt_output = slash_me($opt_output);

    $results_output_folder = slash_me(dirname($opt_output.'dummy') . '/'); ## remove any prefix passed from command line e.g. --output output\run1 becomes output/
    File::Path::make_path ( $results_output_folder );

    $results_filename_prefix = $opt_output;
    $results_filename_prefix =~ s{.*[/\\]}{}g; ## if there is an output prefix, grab it

    # default the publish to location for the individual html step files
    if (not defined $opt_publish_full) {
        $opt_publish_full = $results_output_folder.$results_filename_prefix;
    } else {
        $opt_publish_full = slash_me($opt_publish_full);
    }

    return;
}

sub print_version {
    print "\nWebInject version $VERSION\nFor more info: https://github.com/Qarj/WebInject\n\n";

    if ($selenium_plugin_present) { WebInjectSelenium::print_version(); }

    return;
}

sub print_usage {
        print <<'EOB'
webinject.pl -v|--version
webinject.pl -h|--help

Usage: webinject.pl tests.xml <<options>>

                                  examples/simple.xml
-c|--config config_file           --config config.xml
-o|--output output_location       --output output/
-a|--autocontroller               --autocontroller
-x|--proxy proxy_server           --proxy localhost:9222
-i|--ignoreretry                  --ignore-retry
-z|--no-colour                    --no-colour
-n|--no-output                    --no-output
-e|--verbose                      --verbose
-u|--publish-to                   --publish-to C:\inetpub\wwwroot\this_run_home
EOB
    ;

    if ($selenium_plugin_present) { WebInjectSelenium::print_usage(); }

    return;
}

#------------------------------------------------------------------

## References
##
## http://www.kichwa.com/quik_ref/spec_variables.html