use diagnostics;
use warnings;
use strict;
use Test::More qw( no_plan );

#http://www.drdobbs.com/scripts-as-modules/184416165
do './webinject.pl';

#
# GLOBAL TEST SETUP
#

before_test();

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

before_test();
$main::response = HTTP::Response->parse('A response without an action');
save_page();
assert_stdout_contains('ACTION none', 'save_page: ACTION none');

before_test();
$main::response = HTTP::Response->parse('A response with an action after post - method="post" id="3" action="submit.aspx"');
save_page();
assert_stdout_contains('ACTION submit.aspx', 'save_page: ACTION after method of post');

before_test();
$main::response = HTTP::Response->parse('A response with an action before post - action="submit.aspx" id="3" method="post"');
save_page();
assert_stdout_contains('ACTION submit.aspx', 'save_page: ACTION before method of post');

before_test();
$main::response = HTTP::Response->parse('A response with a null action - action="" id="3" method="post"');
save_page();
is(stdout_contains('ACTION IS NULL'), 1, 'save_page: ACTION IS NULL');
assert_stdout_contains('SAVING /jobs/search.cgi', 'save_page: default action to page path');

before_test();
$main::response = HTTP::Response->parse('A response with full url in action="https://example.com/home/query.cgi?keyword=test" method="post"');
save_page();
is(stdout_contains('ACTION https:'), 1, 'save_page: full url in action');
assert_stdout_contains('SAVING /home/query.cgi', 'save_page: clean action to just url path');

before_test();
$main::response = HTTP::Response->parse('action="submit.aspx" id="3" method="post"');
save_page();
assert_stdout_contains('NO CACHED PAGES', 'save_page: NO CACHED PAGES');

before_test();
$main::response = HTTP::Response->parse('action="submit.aspx" id="3" method="post"');
save_page();
save_page();
assert_stdout_contains('MATCH at position 0', 'save_page: MATCH at position 0');

before_test();
$main::response = HTTP::Response->parse('action="submit.aspx" id="3" method="post"');
save_page();
$main::response = HTTP::Response->parse('action="query.aspx" id="3" method="post"');
save_page();
save_page();
assert_stdout_contains('MATCH at position 1', 'save_page: MATCH at position 1');

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

sub assert_stdout_contains {
    my ($_must_contain, $_test_description) = @_;
    if ($main::results_stdout =~ m/$_must_contain/s) {
        is(1, 1, $_test_description);
    } else {
        is($main::results_stdout, $_must_contain, $_test_description);
    }
}

sub before_test {
    $main::EXTRA_VERBOSE = 1;

    $main::case{url} = 'http://example.com/jobs/search.cgi?query=Test%Automation&Location=London';
    $main::results_stdout = '';
    $main::response = '';

    undef @main::visited_pages;
    undef @main::visited_page_names;
    undef @main::page_update_times;
    
    return;
}

#
# SUPPRESS WARNINGS FOR VARIABLES USED ONLY ONCE
#

$main::response = '';
$main::EXTRA_VERBOSE = 0;
$main::results_stdout = '';
undef @main::visited_pages;
undef @main::visited_page_names;
undef @main::page_update_times;
