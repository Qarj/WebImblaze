use diagnostics;
use warnings;
use strict;
use Test::More qw( no_plan );

#http://www.drdobbs.com/scripts-as-modules/184416165
do './webinject.pl';

#
# GLOBAL TEST SETUP
#

$main::EXTRA_VERBOSE = 1;

#
# get_testnum_display
#

is(get_testnum_display(5,1), '5', 'get_testnum_display: Standard');
is(get_testnum_display(5,2), '10005', 'get_testnum_display: 1st repeat');
is(get_testnum_display(5,3), '20005', 'get_testnum_display: 2nd repeat');

$main::case{runon}='PROD';
is(get_test_step_skip_message(), 'run on PROD', 'get_test_step_skip_message: run on PROD');

$main::case{runon}='PAT';
is(get_test_step_skip_message(), 'run on PAT', 'get_test_step_skip_message: run on PAT');

#
# _url_path
#

is(_url_path('https://example.com/search/form?terms=cheapest'), '/search/form', '_url_path: Full url with query string');

#
# save_page
#

$main::response = HTTP::Response->parse('A response without an action');
save_page();
is(stdout_contains('ACTION none'), 1, 'save_page: ACTION none');

#
# GLOBAL HELPER SUBS
#

sub contains {
    my ($_string, $_target) = @_;
    return $_string =~ m/$_target/s;
}

sub stdout_contains {
    my ($_target) = @_;
    return $main::results_stdout =~ m/$_target/s;
}

#
# SUPPRESS WARNINGS FOR VARIABLES USED ONLY ONCE
#

$main::response = '';
$main::EXTRA_VERBOSE = 0;
$main::results_stdout = '';