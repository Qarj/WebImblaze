#!/usr/bin/env perl

use diagnostics;
use warnings;
use strict;
use Test::More qw( no_plan );
use File::Path qw(make_path remove_tree);
use vars qw/ $VERSION /;

$VERSION = '0.0.1';

#http://www.drdobbs.com/scripts-as-modules/184416165
do './wi.pl';

require HTTP::Cookies;
require LWP;

my $WEBIMBLAZE_ROOT = $main::this_script_folder_full;
$WEBIMBLAZE_ROOT =~ s{\\}{/}g;
my $OUTPUT = 'unittest/';
remove_tree($WEBIMBLAZE_ROOT . $OUTPUT);

#
# GLOBAL TEST SETUP
#

before_test();

#
#
# get_testnum_display
#
#

is(get_testnum_display(5,1), '5', 'get_testnum_display: Standard');
is(get_testnum_display(5,2), '10005', 'get_testnum_display: 1st repeat');
is(get_testnum_display(5,3), '20005', 'get_testnum_display: 2nd repeat');

$main::case{runon}='PROD';
is(get_test_step_skip_message(), 'run on PROD', 'get_test_step_skip_message: run on PROD');

$main::case{runon}='PAT';
is(get_test_step_skip_message(), 'run on PAT', 'get_test_step_skip_message: run on PAT');

#
#
# _url_path
#
#

is(_url_path('https://example.com/search/form?terms=cheapest'), '/search/form', '_url_path: Full url with query string');

#
#
# save_page_when_method_post_and_has_action 
#
#

before_test();
$main::resp_content = ('A response without an action');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('ACTION none', 'save_page_when_method_post_and_has_action : ACTION none');

before_test();
$main::resp_content = ('A response with an action after post - method="post" id="3" action="submit.aspx"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('ACTION submit.aspx', 'save_page_when_method_post_and_has_action : ACTION after method of post');

before_test();
$main::resp_content = ('A response with an action before post - action="submit.aspx" id="3" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('ACTION submit.aspx', 'save_page_when_method_post_and_has_action : ACTION before method of post');

before_test();
$main::resp_content = ('A response with a null action - action="" id="3" method="post"');
save_page_when_method_post_and_has_action ();
is(stdout_contains('ACTION IS NULL'), 1, 'save_page_when_method_post_and_has_action : ACTION IS NULL');
assert_stdout_contains('SAVING /jobs/search.cgi', 'save_page_when_method_post_and_has_action : default action to page path');

before_test();
$main::resp_content = ('A response with full url in action="https://example.com/home/query.cgi?keyword=test" method="post"');
save_page_when_method_post_and_has_action ();
is(stdout_contains('ACTION https:'), 1, 'save_page_when_method_post_and_has_action : full url in action');
assert_stdout_contains('SAVING /home/query.cgi', 'save_page_when_method_post_and_has_action : clean action to just url path');

before_test();
$main::resp_content = ('action="submit.aspx" id="3" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('NO CACHED PAGES', 'save_page_when_method_post_and_has_action : NO CACHED PAGES');

before_test();
$main::resp_content = ('action="submit.aspx" id="3" method="post"');
save_page_when_method_post_and_has_action ();
save_page_when_method_post_and_has_action ();
assert_stdout_contains('MATCH at position 0', 'save_page_when_method_post_and_has_action : MATCH at position 0');

before_test();
$main::resp_content = ('action="submit.aspx" id="3" method="post"');
save_page_when_method_post_and_has_action ();
$main::resp_content = ('action="query.aspx" id="3" method="post"');
save_page_when_method_post_and_has_action ();
save_page_when_method_post_and_has_action ();
assert_stdout_contains('MATCH at position 1', 'save_page_when_method_post_and_has_action : MATCH at position 1');

before_test();
$main::resp_content = ('action="submit.aspx" method="post"');
save_page_when_method_post_and_has_action ();
$main::resp_content = ('action="query.aspx" method="post"');
save_page_when_method_post_and_has_action ();
$main::resp_content = ('action="/register.cgi" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('NO MATCH on 0:submit.aspx', 'save_page_when_method_post_and_has_action : NO MATCH on 0:submit.aspx');
assert_stdout_contains('NO MATCH on 1:query.aspx', 'save_page_when_method_post_and_has_action : NO MATCH on 1:query.aspx');
assert_stdout_contains('NO MATCHES FOUND IN CACHE', 'save_page_when_method_post_and_has_action : NO MATCHES FOUND IN CACHE - different action');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('MATCH at position 2', 'save_page_when_method_post_and_has_action : MATCH at position 2');
$main::resp_content = ('action="/submit.aspx" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('NO MATCHES FOUND IN CACHE', 'save_page_when_method_post_and_has_action : NO MATCHES FOUND IN CACHE - slightly different action');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('MATCH at position 3', 'save_page_when_method_post_and_has_action : MATCH at position 3 - slightly different action saved again');



before_test();
$main::resp_content = ('action="index_0" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Index 0 is free', 'save_page_when_method_post_and_has_action : Index 0 is free');

$main::resp_content = ('action="index_1" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Index 1 is free', 'save_page_when_method_post_and_has_action : Index 1 is free');

$main::resp_content = ('action="index_2" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Index 2 is free', 'save_page_when_method_post_and_has_action : Index 2 is free');

$main::resp_content = ('action="index_3" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Index 3 is free', 'save_page_when_method_post_and_has_action : Index 3 is free');

$main::resp_content = ('action="index_4" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Index 4 is free', 'save_page_when_method_post_and_has_action : Index 4 is free');

$main::resp_content = ('action="index_5" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Index 5 is free', 'save_page_when_method_post_and_has_action : Index 5 is free');

$main::resp_content = ('action="page_7" method="post"');
clear_stdout();
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Overwriting - Oldest Page Index: 0', 'save_page_when_method_post_and_has_action : Overwrite oldest page in cache - index 0');

$main::resp_content = ('action="page_8" method="post"');
clear_stdout();
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Overwriting - Oldest Page Index: 1', 'save_page_when_method_post_and_has_action : Overwrite oldest page in cache - index 1');

$main::resp_content = ('action="page_9" method="post"');
clear_stdout();
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Overwriting - Oldest Page Index: 2', 'save_page_when_method_post_and_has_action : Overwrite oldest page in cache - index 2');

clear_stdout();
save_page_when_method_post_and_has_action ();
assert_stdout_contains('MATCH at position 2', 'save_page_when_method_post_and_has_action : MATCH at position 2 - save overwritten page again');

$main::resp_content = ('action="page_8" method="post"');
clear_stdout();
save_page_when_method_post_and_has_action ();
assert_stdout_contains('MATCH at position 1', 'save_page_when_method_post_and_has_action : MATCH at position 1 - save older overwritten page again');
assert_stdout_contains('Cache 0:page_7', 'save_page_when_method_post_and_has_action : saved in cache at 0');
assert_stdout_contains('Cache 1:page_8', 'save_page_when_method_post_and_has_action : saved in cache at 1');
assert_stdout_contains('Cache 2:page_9', 'save_page_when_method_post_and_has_action : saved in cache at 2');
assert_stdout_contains('Cache 3:index_3', 'save_page_when_method_post_and_has_action : saved in cache at 3');
assert_stdout_contains('Cache 4:index_4', 'save_page_when_method_post_and_has_action : saved in cache at 4');
assert_stdout_contains('Cache 5:index_5', 'save_page_when_method_post_and_has_action : saved in cache at 5');



before_test();
$main::resp_content = ('action="submit.aspx" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Saved [\d\.]+:submit.aspx', 'save_page_when_method_post_and_has_action : confirmation page is saved');

#
#
# auto_sub
#
#

before_test();
auto_sub('a=b&c=d&e=f', 'normalpost', 'http://example.com');
assert_stdout_contains('There are 3 fields in the postbody', 'auto_sub : normal post has 3 fields');

before_test();
auto_sub(q{}, 'normalpost', 'http://example.com');
assert_stdout_contains('There are 0 fields in the postbody', 'auto_sub : normal post has 0 fields');

before_test();
auto_sub('a=b', 'normalpost', 'http://example.com');
assert_stdout_contains('There are 1 fields in the postbody', 'auto_sub : normal post has 1 field');

before_test();
auto_sub(q{( 'name' => 'Upload' )}, 'multipost', 'http://example.com');
assert_stdout_contains('There are 1 fields in the postbody', 'auto_sub : multi post has 1 field');

before_test();
auto_sub(q{( 'fileUpload' => ['examples/multipart_post.csv'], 'name' => 'Upload' )}, 'multipost', 'http://example.com');
assert_stdout_contains('There are 1 fields in the postbody', 'auto_sub : multi post has 2 fields');

before_test();
auto_sub('a=b&c=d&e=f', 'normalpost', 'http://example.com');
assert_stdout_contains('Field 1: a=b', 'auto_sub : field 1 display');
assert_stdout_contains('Field 2: c=d', 'auto_sub : field 2 display');
assert_stdout_contains('Field 3: e=f', 'auto_sub : field 3 display');

before_test();
auto_sub(q{(  'a' => 'b', 'c' => 'd', 'e' => 'f' )}, 'multipost', 'http://example.com');
assert_stdout_contains(q|Field 1: \(  'a' => 'b|, 'auto_sub : multipost field 1 display');
assert_stdout_contains(q|Field 2:  'c' => 'd|, 'auto_sub : multimpost field 2 display');
assert_stdout_contains(q|Field 3:  'e' => 'f|, 'auto_sub : multimpost field 3 display'); #'

before_test();
is(auto_sub('a=b&c=d&e=f', 'normalpost', 'http://example.com'), 'a=b&c=d&e=f', 'auto_sub : no change - no cached pages');
assert_stdout_contains('REMOVE PATH', 'auto_sub : remove path');
assert_stdout_contains('DESPERATE MODE - NO ANCHOR', 'auto_sub : desperate mode - no anchor');

before_test();
$main::resp_content = ('action="/search.aspx" method="post"');
save_page_when_method_post_and_has_action ();
auto_sub('a=b&c=d&e=f', 'normalpost', 'http://example.com/search.aspx');
assert_stdout_contains('MATCH at position 0', 'auto_sub : exact action match - assert 1');
assert_stdout_does_not_contain('PAGE NAME ONLY', 'auto_sub : exact action match - assert 2');

before_test();
$main::resp_content = ('action="/search.aspx" method="post"');
save_page_when_method_post_and_has_action ();
auto_sub('a=b&c=d&e=f', 'normalpost', 'http://example.com/premium/search.aspx');
assert_stdout_contains('MATCH at position 0', 'auto_sub : page name only - assert 2');
assert_stdout_contains('REMOVE PATH', 'auto_sub : page name only - assert 2');
assert_stdout_does_not_contain('DESPERATE MODE', 'auto_sub : page name only - assert 3');

before_test();
$main::resp_content = ('action="/search.aspx" method="post"');
save_page_when_method_post_and_has_action ();
auto_sub('a=b&c=d&e=f', 'normalpost', 'http://example.com/premium/search');
assert_stdout_contains('MATCH at position 0', 'auto_sub : desperate mode - assert 2');
assert_stdout_contains('DESPERATE MODE', 'auto_sub : desperate mode - assert 2');

before_test();
$main::resp_content = ('action="/search.aspx" method="post" name="a" type="hidden" value="bee bee"');
save_page_when_method_post_and_has_action ();
auto_sub('a={DATA}&c=d&e=f', 'normalpost', 'http://example.com/search.aspx');
assert_stdout_contains('ID MATCH 0', 'auto_sub : ID MATCH');
assert_stdout_contains('Normal field a has \{DATA\}', 'auto_sub : normal field has {DATA}');
assert_stdout_contains('DATA is bee', 'auto_sub : normalpost {DATA} - field 1 - assert 1');
assert_stdout_contains('URLESCAPE!!', 'auto_sub : normalpost {DATA} - field 1 - assert 2');
assert_stdout_contains('SUBBED FIELD is a=bee%20bee', 'auto_sub : normalpost {DATA} - field 1 - assert 3');
assert_stdout_contains('a=bee%20bee', 'auto_sub : normalpost {DATA} - field 1 - assert 4');

before_test();
$main::resp_content = ('action="/search.aspx" method="post" <input name="c" value="dee" /> <input name="e" value="eff" />');
save_page_when_method_post_and_has_action ();
auto_sub('a=b&c={DATA}&e={DATA}', 'normalpost', 'http://example.com/search.aspx');
assert_stdout_contains('c=dee', 'auto_sub : normalpost {DATA} - field 2');
assert_stdout_contains('e=eff', 'auto_sub : normalpost {DATA} - field 3');

before_test();
$main::resp_content = ('action="/search.aspx" method="post" name="a" type="hidden" value="bee bee"');
save_page_when_method_post_and_has_action ();
auto_sub(q{(  'a' => '{DATA}', 'c' => 'd', 'e' => 'f' )}, 'multipost', 'http://example.com/search.aspx');
assert_stdout_contains('ID MATCH 0', 'auto_sub : ID MATCH');
assert_stdout_contains('Multi field a has \{DATA\}', 'auto_sub : multi field has {DATA}');
assert_stdout_contains('DATA is bee', 'auto_sub : multipost {DATA} - field 1 - assert 1');
assert_stdout_contains(q|SUBBED FIELD is \(  'a' => 'bee bee|, 'auto_sub : multipost {DATA} - field 1 - assert 2'); #'
assert_stdout_contains(q|POSTBODY is \(  'a' => 'bee bee', 'c' => 'd', 'e' => 'f' \)|, 'auto_sub : multipost {DATA} - field 1 - assert 3');
assert_stdout_contains('Auto substitution latency was ', 'auto_sub : latency display');

before_test();
$main::resp_content = ('action="/search.aspx" method="post" <input name="c" value="dee" /> <input name="e" value="eff" />');
save_page_when_method_post_and_has_action ();
auto_sub(q|(  'a' => 'b', 'c' => '{DATA}', 'e' => '{DATA}' )|, 'multipost', 'http://example.com/search.aspx');
assert_stdout_contains(q|'c' => 'dee'|, 'auto_sub : multipost {DATA} - field 2');
assert_stdout_contains(q|'e' => 'eff'|, 'auto_sub : multipost {DATA} - field 3');

before_test();
$main::resp_content = ('action="/search.aspx" method="post" name="Row1_Col1_Field1" type="hidden" value="b"');
save_page_when_method_post_and_has_action ();
auto_sub('Row1_{NAME}_Field1=b&c=d&e=f', 'normalpost', 'http://example.com/search.aspx');
assert_stdout_contains('LHS of \{NAME}: \[Row1_] ', 'auto_sub : normal post - LHS of {NAME}');
assert_stdout_contains('RHS of \{NAME}: \[_Field1] ', 'auto_sub : normal post - RHS of {NAME}');
assert_stdout_contains('NAME is Col1', 'auto_sub : normal post - NAME is');
assert_stdout_contains('SUBBED NAME is Row1_Col1_Field1=b', 'auto_sub : normal post - SUBBED NAME is');

before_test();
$main::resp_content = ('action="/search.aspx" method="post" <input name="Row2_Col2_Field2" value="d" /> <input name="Row3_Col3_Field3" value="f" /> ');
save_page_when_method_post_and_has_action ();
auto_sub('Row1_Col1_Field1=b&Row2_{NAME}_Field2=d&Row3_{NAME}_Field3=f', 'normalpost', 'http://example.com/search.aspx');
assert_stdout_contains('NAME is Col2', 'auto_sub : normal post - NAME is - field 2');
assert_stdout_contains('NAME is Col3', 'auto_sub : normal post - NAME is - field 2');

before_test();
$main::resp_content = ('action="/search.aspx" method="post" name="Row1_Col1_Field1" type="hidden" value="b"');
save_page_when_method_post_and_has_action ();
auto_sub('{NAME}_Field1=b&c=d&e=f', 'normalpost', 'http://example.com/search.aspx');
assert_stdout_contains('LHS of \{NAME}: \[] ', 'auto_sub : LHS of {NAME} is null');

before_test();
$main::resp_content = ('action="/search.aspx" method="post" name="Row1_Col1_Field1" type="hidden" value="b"');
save_page_when_method_post_and_has_action ();
auto_sub('Row1_Col1_{NAME}=b&c=d&e=f', 'normalpost', 'http://example.com/search.aspx');
assert_stdout_contains('RHS of \{NAME}: \[] ', 'auto_sub : RHS of {NAME} is null');

before_test();
$main::resp_content = ('action="/search.aspx" method="post" <input name="Row2_Col2_Field2" value="d" /> <input name="Row3_Col3_Field3" value="f" /> ');
save_page_when_method_post_and_has_action ();
auto_sub(q|(  'a' => 'b', 'Row2_{NAME}_Field2' => '{DATA}', '{NAME}Field3' => '{DATA}' )|, 'multipost', 'http://example.com/search.aspx');
assert_stdout_contains(q|POSTBODY is \(  'a' => 'b', 'Row2_Col2_Field2' => 'd', 'Row3_Col3_Field3' => 'f' \)|, 'auto_sub : multi post - NAME and DATA');

before_test();
$main::resp_content = ('action="/search.aspx" method="post" <input name="strange_xname" value="d" /> <input name="odd_yname" value="f" /> ');
save_page_when_method_post_and_has_action ();
auto_sub(q|(  'a' => 'b', '{NAME}_xname.x' => '{DATA}', '{NAME}_yname.y' => '{DATA}' )|, 'multipost', 'http://example.com/search.aspx');
assert_stdout_contains('DOTx found in ', 'auto_sub : NAME - DOTX');
assert_stdout_contains('DOTy found in ', 'auto_sub : NAME - DOTY');
assert_stdout_contains(q|DOTx restored to  'strange_xname.x'|, 'auto_sub : NAME - DOTX restored');
assert_stdout_contains(q|DOTy restored to  'odd_yname.y'|, 'auto_sub : NAME - DOTY restored');
assert_stdout_contains(q|POSTBODY is \(  'a' => 'b', 'strange_xname.x' => 'd', 'odd_yname.y' => 'f' \)|, 'auto_sub : DOTX and DOTY');

before_test();
$main::resp_content = ('action="/search.aspx" method="post" <input name="odd_xname" value="default" /> <input name="odd_yname" value="default" /> ');
save_page_when_method_post_and_has_action ();
auto_sub('a=b&{NAME}xname.x=d.xtra&{NAME}yname.y=f.ytra', 'normalpost', 'http://example.com/search.aspx');
assert_stdout_contains('odd_xname\.x=d\.xtra', 'auto_sub : DOTX - ensure value not affected');
assert_stdout_contains('odd_yname\.y=f\.ytra', 'auto_sub : DOTY - ensure value not affected');

#
#
# Lean Test Format
#
#

# XMLin function creates a data structure like the below, the lean parse must produce the same structure
#
#$VAR1 = {
#          'case' => {
#                      '20' => {
#                                'step' => 'Another step - retry {RETRY}',
#                                'desc' => 'Sub description',
#                                'method' => 'shell',
#                                'shell' => 'REM Not much more - retry {RETRY}',
#                                'retry' => '3',
#                                'verifynegative' => 'Nothing much',
#                                'verifypositive' => 'retry 1'
#                              },
#                      '10' => {
#                                'step' => 'Test that WebImblaze can run a very basic test',
#                                'shell' => 'REM Nothing: much',
#                                'method' => 'shell',
#                                'verifypositive1' => 'Nothing: much'
#                              }
#                    },
#          'repeat' => '1'
#        };

before_test();
$main::unit_test_steps = <<'EOB'
step: Test that WebImblaze can run a very basic test
shell: REM Nothing: much
verifypositive1: Nothing: much

step: Another step - retry {RETRY}
desc: Sub description
shell: REM Not much more - retry {RETRY}
verifypositive: retry 1
verifynegative: Nothing much
retry: 3
EOB
    ;
read_test_steps_file();
assert_stdout_contains('Lean test steps parsed OK', 'read_test_steps_file : lean style format parsed ok');
assert_stdout_does_not_contain(q{'repeat' => '1'}, '_parse_lean_test_steps : repeat is not defaulted');
assert_stdout_contains(q{'10' =>}, '_parse_lean_test_steps : Step 10 found');
assert_stdout_contains(q{'step' => 'Test that WebImblaze can run a very basic test'}, '_parse_lean_test_steps : Step 10, step name found');
assert_stdout_contains(q{'shell' => 'REM Nothing: much'}, '_parse_lean_test_steps : Step 10, command found');
assert_stdout_contains(q{'verifypositive1' => 'Nothing: much'}, '_parse_lean_test_steps : Step 10, verifypositive1 found');
assert_stdout_contains(q{'20' =>}, '_parse_lean_test_steps : Step 20 found');
assert_stdout_contains(q{'step' => 'Another step - retry [{]RETRY}'}, '_parse_lean_test_steps : Step 20, desc1 found');
assert_stdout_contains(q{'desc' => 'Sub description'}, '_parse_lean_test_steps : Step 20, desc2 found');
assert_stdout_contains(q{'method' => 'shell'}, '_parse_lean_test_steps : Step 20, method found');
assert_stdout_contains(q{'shell' => 'REM Not much more - retry [{]RETRY}'}, '_parse_lean_test_steps : Step 20, command found');
assert_stdout_contains(q{'retry' => '3'}, '_parse_lean_test_steps : Step 20, retry found');
assert_stdout_contains(q{'verifynegative' => 'Nothing much'}, '_parse_lean_test_steps : Step 20, verifynegative found');
assert_stdout_contains(q{'verifypositive' => 'retry 1'}, '_parse_lean_test_steps : Step 20, verifypositive found');

# can have a lean test case file with a single step
before_test();
$main::unit_test_steps = <<'EOB'
step: Single test step in file
shell: echo Short
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'10' =>}, '_parse_lean_test_steps : Can have just one test step');

# can have quotes
before_test();
$main::unit_test_steps = <<'EOB'
step: Can handle 'single' and "double" quotes
shell: echo 'single' and "double" quotes
verifypostive: 'single' and "double" quotes
EOB
    ;
read_test_steps_file();
assert_stdout_contains('Lean test steps parsed OK', '_parse_lean_test_steps : Can handle single and double quotes');

# id auto generated - cannot be specified
before_test();
$main::unit_test_steps = <<'EOB'
step: Id is auto generated
shell: echo auto

step: Next step
shell: echo next
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'10' =>}, '_parse_lean_test_steps : step ids are auto generated - 10');
assert_stdout_contains(q{'20' =>}, '_parse_lean_test_steps : step ids are auto generated - 20');

# method="cmd" is auto generated
before_test();
$main::unit_test_steps = <<'EOB'
step: Shell method is detected
shell: echo auto1
shell20: echo auto2

step: Next step
shell5: echo next1
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'shell20' => 'echo auto2'}, '_parse_lean_test_steps : shell not converted back to command');
assert_stdout_contains(q{'method' => 'shell'}, '_parse_lean_test_steps : shell method detected - 1');

# method="cmd" is auto generated - shell1
before_test();
$main::unit_test_steps = <<'EOB'
step: Shell method is detected
shell1: echo auto1

step: Next step
shell1: echo next1
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'method' => 'shell'}, '_parse_lean_test_steps : shell method detected - 2');

# method="selenium" is auto generated
before_test();
$main::unit_test_steps = <<'EOB'
step: Selenium method is detected
selenium3: $driver->get("https://www.totaljobs.com")
selenium20: $driver->get_all_cookies()

step: Next step
selenium5: $driver->get('https://www.totaljobs.com/register')
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'method' => 'selenium'}, '_parse_lean_test_steps : Selenium method detected');
assert_stdout_contains(q{'selenium20' => '.driver->get_all_cookies..'}, '_parse_lean_test_steps : selenium not converted back to command');

# method="get" is auto generated
before_test();
$main::unit_test_steps = <<'EOB'
step: Get method is detected
url: https://www.totaljobs.com
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'method' => 'get'}, '_parse_lean_test_steps : get method detected');

# method="post" is auto generated
before_test();
$main::unit_test_steps = <<'EOB'
step: Get method is detected
url: https://www.totaljobs.com
postbody: RecipeName=Sheperds%20Pie&Cuisine=British
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'method' => 'post'}, '_parse_lean_test_steps : post method detected');

# single line comment is a hash
before_test();
$main::unit_test_steps = <<'EOB'
step: Single line comment
url: https://www.totaljobs.com
#verifypositive: positive
EOB
    ;
read_test_steps_file();
assert_stdout_does_not_contain(q{'verifypositive'}, '_parse_lean_test_steps : single line comment first char');
assert_stdout_does_not_contain(q{'' =>}, '_parse_lean_test_steps : single line comment does not generate null parameter');

# multi line comment starts with --= and ends with =--
before_test();
$main::unit_test_steps = <<'EOB'
step: Multi line comment
url: https://www.totaljobs.com
#verifypositive: positive

--=
step: This step is commented out
url: https://www.totaljobs.com
verifypositive: Not found
=--
EOB
    ;
read_test_steps_file();
assert_stdout_does_not_contain(q{'Not found'}, '_parse_lean_test_steps : multi line comment');
assert_stdout_does_not_contain(q{'' =>}, '_parse_lean_test_steps : multi line comment does not generate null parameter');

# multi line comment can exist in a test step
before_test();
$main::unit_test_steps = <<'EOB'
step: Multi line comment
url: https://www.totaljobs.com
verifypositive: sure
--=
verifypositive: positive
=--
verifynegative: negative
EOB
    ;
read_test_steps_file();
assert_stdout_does_not_contain(q{'verifypositive' => 'positive'}, '_parse_lean_test_steps : can have multi line comment in step');
assert_stdout_does_not_contain(q{'' =>}, '_parse_lean_test_steps : multi line comment in step does not generate null parameter');
assert_stdout_contains(q{'verifynegative' => 'negative'}, '_parse_lean_test_steps : can have multi line comment in step - parm after comment is active');

# multi line comment and single line comment beside each other
before_test();
$main::unit_test_steps = <<'EOB'
step: Multi line comment
url: https://www.totaljobs.com
verifypositive: sure
#boring
--=
verifypositive: positive
=--
#verifypositive: happy
verifynegative: negative
#verifypositive: sad
EOB
    ;
read_test_steps_file();
assert_stdout_does_not_contain(q{'verifypositive' => 'positive'}, '_parse_lean_test_steps : multi comment ignore in mixed comments');
assert_stdout_does_not_contain(q{'' =>}, '_parse_lean_test_steps : multi line and single line comment does not generate null parameter');
assert_stdout_contains(q{'verifynegative' => 'negative'}, '_parse_lean_test_steps : multi and single line comments mixed ok - 1');
assert_stdout_contains(q{'verifypositive' => 'sure'}, '_parse_lean_test_steps : multi and single line comments mixed ok - 2');
assert_stdout_does_not_contain(q{'20' =>}, '_parse_lean_test_steps : multi line and single line comment - should only be one step');

# multi line comment can end anywhere on line
before_test();
$main::unit_test_steps = <<'EOB'
step: Multi line comment can end anywhere
url: https://www.totaljobs.com
verifypositive: sure
--=
verifypositive: positive =--
verifynegative: negative
EOB
    ;
read_test_steps_file();
assert_stdout_does_not_contain(q{'verifypositive' => 'positive'}, '_parse_lean_test_steps : multi comment can end anywhere on line - 1');
assert_stdout_contains(q{'verifynegative' => 'negative'}, '_parse_lean_test_steps : multi comment can end anywhere on line - 2');

# not a multi line comment - should not be removed
before_test();
$main::unit_test_steps = <<'EOB'
step: Multi line comment
url: https://www.totaljobs.com
verifypositive1: sure --= thing
verifypositive2: positive
verifynegative1: negative  =-- 
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'verifypositive1' => 'sure --= thing'}, '_parse_lean_test_steps : not a multiline quote - 1');
assert_stdout_contains(q{'verifypositive2' => 'positive'}, '_parse_lean_test_steps : not a multiline quote - 2');
assert_stdout_contains(q{'verifynegative1' => .negative  =--}, '_parse_lean_test_steps : not a multiline quote - 3');

# quoted string - one line
before_test();
$main::unit_test_steps = <<'EOB'
step: One line quoted string
url: https://www.totaljobs.com
verifypositive:q:    q sure q   
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'verifypositive' => ' sure '}, '_parse_lean_test_steps : single line quote - single char');

# quoted string - one line special characters
before_test();
$main::unit_test_steps = <<'EOB'
step: Be sure of one line quoted string
url: https://www.totaljobs.com
verifypositive1:$:    $ sure $   
verifypositive2:^:    ^ sure ^   
verifypositive3:.:    . sure .   
verifypositive4:*:    * sure *   
verifypositive5:+:    + sure +   
verifypositive6:?:    ? sure ?   
verifypositive7:\:    \ sure \   
verifypositive8:|:    | sure |   
verifypositive9:-:    - sure -   
verifypositiveA:/:    / sure /   
verifypositiveB:#:    # sure #   
verifypositiveC:@:    @ sure @   
verifypositiveD:&:    & sure &   
verifypositiveE:=:    = sure =   
verifypositiveF:":    " sure "   
verifypositiveG:':    ' sure '   
verifypositiveH:`:    ` sure `   
verifypositiveI:0:    0 sure 0   
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'verifypositive1' => ' sure '}, '_parse_lean_test_steps : single line quote - single char $');
assert_stdout_contains(q{'verifypositive2' => ' sure '}, '_parse_lean_test_steps : single line quote - single char ^');
assert_stdout_contains(q{'verifypositive3' => ' sure '}, '_parse_lean_test_steps : single line quote - single char .');
assert_stdout_contains(q{'verifypositive4' => ' sure '}, '_parse_lean_test_steps : single line quote - single char *');
assert_stdout_contains(q{'verifypositive5' => ' sure '}, '_parse_lean_test_steps : single line quote - single char +');
assert_stdout_contains(q{'verifypositive6' => ' sure '}, '_parse_lean_test_steps : single line quote - single char ?');
assert_stdout_contains(q{'verifypositive7' => ' sure '}, '_parse_lean_test_steps : single line quote - single char \\');
assert_stdout_contains(q{'verifypositive8' => ' sure '}, '_parse_lean_test_steps : single line quote - single char |');
assert_stdout_contains(q{'verifypositive9' => ' sure '}, '_parse_lean_test_steps : single line quote - single char -');
assert_stdout_contains(q{'verifypositiveA' => ' sure '}, '_parse_lean_test_steps : single line quote - single char /');
assert_stdout_contains(q{'verifypositiveB' => ' sure '}, '_parse_lean_test_steps : single line quote - single char #');
assert_stdout_contains(q{'verifypositiveC' => ' sure '}, '_parse_lean_test_steps : single line quote - single char @');
assert_stdout_contains(q{'verifypositiveD' => ' sure '}, '_parse_lean_test_steps : single line quote - single char &');
assert_stdout_contains(q{'verifypositiveE' => ' sure '}, '_parse_lean_test_steps : single line quote - single char =');
assert_stdout_contains(q{'verifypositiveF' => ' sure '}, '_parse_lean_test_steps : single line quote - single char "');
assert_stdout_contains(q{'verifypositiveG' => ' sure '}, q{_parse_lean_test_steps : single line quote - single char '});
assert_stdout_contains(q{'verifypositiveH' => ' sure '}, '_parse_lean_test_steps : single line quote - single char `');
assert_stdout_contains(q{'verifypositiveI' => ' sure '}, '_parse_lean_test_steps : single line quote - single char 0');

# quoted string - empty string quote
before_test();
$main::unit_test_steps = <<'EOB'
step: Empty string quote
url: https://www.totaljobs.com
verifypositive1:_: __
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'verifypositive1' => ''}, '_parse_lean_test_steps : empty string quote - single char _');

# quoted string - quote char is colon
before_test();
$main::unit_test_steps = <<'EOB'
step: Empty string quote
url: https://www.totaljobs.com
verifypositive1:;: ;hey;
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'verifypositive1' => 'hey'}, '_parse_lean_test_steps : quote character is semicolon ');

# unquoted string - preceding and trailing spaces ignored
before_test();
$main::unit_test_steps = <<'EOB'
step: Empty string quote
url: https://www.totaljobs.com
verifypositive1:   hello   
verifypositive2: world
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'verifypositive1' => 'hello'}, '_parse_lean_test_steps : before and after spaces ignored for unquoted string - 1');
assert_stdout_contains(q{'verifypositive2' => 'world'}, '_parse_lean_test_steps : before and after spaces ignored for unquoted string - 2');

# multi char single line quotes
before_test();
$main::unit_test_steps = <<'EOB'
step: Multi char single line quotes
url: https://www.totaljobs.com
verifypositive1:qqq:   qqq hello qqq  
verifypositive2:--=:   --= hello --=  
verifypositive3:=--:   =-- hello =--  
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'verifypositive1' => ' hello '}, '_parse_lean_test_steps : multi char single line quotes - 1');
assert_stdout_contains(q{'verifypositive2' => ' hello '}, '_parse_lean_test_steps : multi char single line quotes - 2');
assert_stdout_contains(q{'verifypositive3' => ' hello '}, '_parse_lean_test_steps : multi char single line quotes - 3');

# mirrored chars for quote
before_test();
$main::unit_test_steps = <<'EOB'
step: Multi char single line quotes
url: https://www.totaljobs.com
verifypositive1:(:   ( hello )  
verifypositive2:{{:   {{ hello }}  
verifypositive3:[<:   [< hello ]>  
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'verifypositive1' => ' hello '}, '_parse_lean_test_steps : mirror char for quotes - ()');
assert_stdout_contains(q{'verifypositive2' => ' hello '}, '_parse_lean_test_steps : mirror char for quotes - {{}}');
assert_stdout_contains(q{'verifypositive3' => ' hello '}, '_parse_lean_test_steps : mirror char for quotes [<]>');

# multiline quotes - classic
before_test();
$main::unit_test_steps = <<'EOB'
step: Multi line value
url: https://www.totaljobs.com
postbody:|: | first line 
second line
third line|
verifypositive1: first
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'verifypositive1' => 'first'}, '_parse_lean_test_steps : multi line value - 1');
assert_stdout_contains(q{'postbody' => ' first line }, '_parse_lean_test_steps : multi line value - 2');
assert_stdout_contains(q{'postbody' => [^|]+second line}, '_parse_lean_test_steps : multi line value - 3');
assert_stdout_contains(q{'postbody' => [^|]+third line'}, '_parse_lean_test_steps : multi line value - 4');
assert_stdout_does_not_contain(q{LOGIC ERROR}, '_parse_lean_test_steps : multi line value - 5');

# multiline quotes - minimum
before_test();
$main::unit_test_steps = <<'EOB'
step: Multi line min value
url: https://www.totaljobs.com
postbody:|: | first line 
second line|
verifypositive1: first
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'verifypositive1' => 'first'}, '_parse_lean_test_steps : multi line min value - 1');
assert_stdout_does_not_contain(q{LOGIC ERROR}, '_parse_lean_test_steps : multi line min value - 2');
assert_stdout_contains(q{'postbody' => ' first line }, '_parse_lean_test_steps : multi line min value - 3');
assert_stdout_contains(q{'postbody' => [^|]+second line'}, '_parse_lean_test_steps : multi line min value - 4');

# multi scenarios
before_test();
$main::unit_test_steps = <<'EOB'

step: Multi 10
url: https://www.totaljobs.com
postbody:QUOTE: QUOTE first line 
second lineQUOTE

--= Various: value
=--
#ignore: this
step: Multi 20
url: https://www.cwjobs.co.uk
postbody:[[[: [[[
first content line 
 second content line
]]]


EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'step' => 'Multi 10'}, '_parse_lean_test_steps : multi scenarios - 1');
assert_stdout_contains(q{'url' => 'https://www.totaljobs.com'}, '_parse_lean_test_steps : multi scenarios - 2');
assert_stdout_contains(q{'postbody' => ' first line }, '_parse_lean_test_steps : multi scenarios - 3');
assert_stdout_contains(q{second line'}, '_parse_lean_test_steps : multi scenarios - 4');
assert_stdout_does_not_contain(q{'30' =>}, '_parse_lean_test_steps : multi scenarios - 5');
assert_stdout_does_not_contain(q{LOGIC ERROR}, '_parse_lean_test_steps : multi scenarios - 6');
assert_stdout_does_not_contain(q{'ignore' => 'this'}, '_parse_lean_test_steps : multi scenarios - 7');
assert_stdout_contains(q{'step' => 'Multi 20'}, '_parse_lean_test_steps : multi scenarios - 8');
assert_stdout_contains(q{'url' => 'https://www.cwjobs.co.uk'}, '_parse_lean_test_steps : multi scenarios - 9');
assert_stdout_contains('first content line ', '_parse_lean_test_steps : multi scenarios - 10');
assert_stdout_contains(' second content line', '_parse_lean_test_steps : multi scenarios - 11');

# multiple blank lines between steps
before_test();
$main::unit_test_steps = <<'EOB'
    

step: Multiple blank lines between steps
url: https://www.totaljobs.com


step: Step 2
url: https://www.cwjobs.co.uk

   

EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'url' => 'https://www.totaljobs.com'}, '_parse_lean_test_steps : blank lines between steps - 1');
assert_stdout_contains(q{'step' => 'Multiple blank lines between steps'}, '_parse_lean_test_steps : blank lines between steps - 2');
assert_stdout_contains(q{'url' => 'https://www.cwjobs.co.uk'}, '_parse_lean_test_steps : blank lines between steps - 3');
assert_stdout_contains(q{'step' => 'Step 2'}, '_parse_lean_test_steps : blank lines between steps - 4');
assert_stdout_does_not_contain(q{'30' =>}, '_parse_lean_test_steps : blank lines between steps - 5');

# single line comment within quote
before_test();
$main::unit_test_steps = <<'EOB'
# assertcount: 5

step: Single line comment within quote
shell: echo NOP
verifypositive:[[: [[
# not a comment
# more content]]
verifynegative: bad stuff
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'verifynegative' => 'bad stuff'}, '_parse_lean_test_steps : single line comment in quote - 1');
assert_stdout_does_not_contain(q{'20' =>}, '_parse_lean_test_steps : single line comment in quote - 2');
assert_stdout_contains(q{'verifypositive' => '}, '_parse_lean_test_steps : single line comment in quote - 3');
assert_stdout_does_not_contain(q{'assert_count' =>}, '_parse_lean_test_steps : single line comment in quote - 4');

# single line comment not in quote
before_test();
$main::unit_test_steps = <<'EOB'
# assertcount: 5

step: Single line comment not in quote
shell: echo NOP
verifypositive:[[: [[
# more content]]
verifynegative: bad stuff
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{Got a single line comment index 0}, '_parse_lean_test_steps : single line comment not in quote - 1');
assert_stdout_does_not_contain(q{'' =>}, '_parse_lean_test_steps : single line comment not in quote - 2');

# various single line comments
before_test();
$main::unit_test_steps = <<'EOB'
# assertcount: 5
# step: 1

# step: 2

#pre: comment
step: Single line comment not in quote
shell: echo NOP
verifypositive:[[: [[
# more content]]
verifynegative: bad stuff
# comment: 3
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{Got a single line comment index 5}, '_parse_lean_test_steps : various single line comments - 1');
assert_stdout_does_not_contain(q{'' =>}, '_parse_lean_test_steps : various single line comments - 2');

# multi line comment within quote
before_test();
$main::unit_test_steps = <<'EOB'
# assertcount: 5

--= This truly is a comment
this: too
=--

step: Single line comment within quote
shell: echo NOP
verifypositive:[[: [[
--= not: a comment
more: content
=--
also: content]]
verifynegative: bad stuff
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'verifynegative' => 'bad stuff'}, '_parse_lean_test_steps : multi line comment in quote - 1');
assert_stdout_does_not_contain(q{'20' =>}, '_parse_lean_test_steps : multi line comment in quote - 2');
assert_stdout_contains(q{'verifypositive' => '}, '_parse_lean_test_steps : multi line comment in quote - 3');
assert_stdout_does_not_contain(q{'assert_count' =>}, '_parse_lean_test_steps : multi line comment in quote - 4');
assert_stdout_contains(q{'verifypositive' => .*not: a comment}, '_parse_lean_test_steps : multi line comment in quote - 5');
assert_stdout_contains(q{'verifypositive' => .*more: content}, '_parse_lean_test_steps : multi line comment in quote - 6');
assert_stdout_does_not_contain(q{'this' => 'too'}, '_parse_lean_test_steps : multi line comment in quote - 7');
assert_stdout_contains(q{'verifypositive' => .*also: content}, '_parse_lean_test_steps : multi line comment in quote - 8');

# multi line quote with blank lines
before_test();
$main::unit_test_steps = <<'EOB'
step: Multi line quote with blank lines
shell: echo NOP
verifypositive:[[: [[

one fish

two fish

]]
verifynegative: bad stuff

# the end
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'verifypositive' => .*one fish}, '_parse_lean_test_steps : multi line quote with blank lines - 1');
assert_stdout_contains(q{'verifypositive' => .*two fish}, '_parse_lean_test_steps : multi line quote with blank lines - 2');

# ends with multi line quote
before_test();
$main::unit_test_steps = <<'EOB'
step: Ends with multi line quote
shell: echo NOP
verifypositive:[[: [[
one fish
two fish
]]
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'verifypositive' => .*one fish}, '_parse_lean_test_steps : ends with multi line quote - 1');
assert_stdout_contains(q{'verifypositive' => .*two fish}, '_parse_lean_test_steps : ends with multi line quote - 2');

# test within a test
before_test();
$main::unit_test_steps = <<'EOB'
step: Test within a test
url: http://webimblaze.server/webimblaze/server/submit/?batch=Unit&target=test
postbody:-=-: -=-

step: Ends with multi line quote
shell: echo NOP
verifypositive:[[: [[
one fish
two fish
]]

-=-
verifynegative: Severe error
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'verifynegative' => 'Severe error'}, '_parse_lean_test_steps : test within a test - 1');
assert_stdout_contains(q{'postbody' => .*step: Ends}, '_parse_lean_test_steps : test within a test - 2');
assert_stdout_contains(q{'postbody' => .*shell: echo NOP}, '_parse_lean_test_steps : test within a test - 3');
assert_stdout_contains(q{'postbody' => .*verifypositive:\\[\\[: \\[\\[}, '_parse_lean_test_steps : test within a test - 4');

# edge cases
before_test();
$main::unit_test_steps = <<'EOB'
--= Various comments
# comment in comment
=--
# single line comment
step: Edge cases
verifynegative10: Error
url: http://webimblaze.server/webimblaze/server/submit/?batch=Unit&target=test
postbody:-=-: -=-

    step: Ends with multi line quote
    shell: echo NOP
    verifypositive:[[: [[
    one fish
    two fish
    ]]

-=-
--= Multi mid
=--
# single mid
verifynegative: Severe error
# single end

# Favourite
step: Step 20
shell: echo NOP
   
--=
=--
step: Step 30
shell1: REM
shell2: echo off 
 
# 
--= 
=--
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'verifynegative' => 'Severe error'}, '_parse_lean_test_steps : Edge cases - 1');
assert_stdout_contains(q{'30' =>}, '_parse_lean_test_steps : Edge cases - 2');
assert_stdout_contains(q{'shell2' => 'echo off'}, '_parse_lean_test_steps : Edge cases - 3');
assert_stdout_does_not_contain(q{'' =>}, '_parse_lean_test_steps : Edge cases - 4');
assert_stdout_does_not_contain(q{'40' =>}, '_parse_lean_test_steps : Edge cases - 5');

# repeat
before_test();
$main::unit_test_steps = <<'EOB'
repeat:  42 

step: Set repeat directive
shell: REM repeat
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'repeat' => '42'}, '_parse_lean_test_steps : repeat directive - 1');

# useragent
before_test();
$main::unit_test_steps = <<'EOB'
useragent:  My custom user agent 

step: Set useragent directive
shell: REM repeat
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'useragent' => 'My custom user agent'}, '_parse_lean_test_steps : useragent directive - 1');

# validate that parameter name only contains \w
before_test();
$main::unit_test_steps = <<'EOB'
step: Malformed paramater name
she!!: echo Hello World
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Parse error line 2 }, '_parse_lean_test_steps : validate malformed parameter name - she!!: - 1');
assert_stdout_contains(q{Parameter name must contain only}, '_parse_lean_test_steps : validate malformed parameter name - she!!: - 2');
assert_stdout_contains('Example of well formed .*verifypositive7:', '_parse_lean_test_steps : validate malformed parameter name - she!!: - 3');

# validate that parameter name starts at first character
before_test();
$main::unit_test_steps = <<'EOB'
step: Malformed paramater name
 shell: echo Hello World
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Parse error line 2 }, '_parse_lean_test_steps : validate parameter name starts in column 1');

# quote must end with a colon
before_test();
$main::unit_test_steps = <<'EOB'
step:quote
shell: echo Hello World
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Parse error line 1 }, '_parse_lean_test_steps : validate malformed quote - no colon - 1');
assert_stdout_contains(q{Quote must end with a colon}, '_parse_lean_test_steps : validate malformed quote - no colon - 2');

# quote cannot contain a space
before_test();
$main::unit_test_steps = <<'EOB'
step:qu ote: 
shell: echo Hello World
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Quote must end with a colon}, '_parse_lean_test_steps : validate malformed quote - space');

# quote must end with colon space
before_test();
$main::unit_test_steps = <<'EOB'
step:quote:quote ABCD quote
shell: echo Hello World
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Quote must end with a colon}, '_parse_lean_test_steps : validate malformed quote - no space after final colon');

# quote must not contain colon
before_test();
$main::unit_test_steps = <<'EOB'
step: Quote
shell::: :quoted text:
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Quote must end with a colon}, '_parse_lean_test_steps : validate malformed quote - no colon in quote');

# quote must not contain white space - space
before_test();
$main::unit_test_steps = <<'EOB'
step: Set repeat directive
shell:1 2: 1 2quoted text1 2
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Quote must end with a colon}, '_parse_lean_test_steps : validate malformed quote - no space in quote');

# quote must not contain white space - tab
before_test();
$main::unit_test_steps = <<'EOB'
step: Set repeat directive
url:1	2: 1	2https://www.cwjobs.co.uk1	2
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Quote must end with a colon}, '_parse_lean_test_steps : validate malformed quote - no tab in quote');

# quote must start on parameter line
before_test();
$main::unit_test_steps = <<'EOB'
step: Multiline quote
url:JJ: 
JJhttps://www.totaljobs.comJJ
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Quote declared but opening quote not found}, '_parse_lean_test_steps : validate opening quote is present');

# unquoted value cannot be just white space
before_test();
$main::unit_test_steps = <<'EOB'
step: Value must be present
verifypostive:      	 
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{No value found - must use quotes if value is only white space}, '_parse_lean_test_steps : unquoted must not be only white space');

# repeat value must be numeric only without quotes
before_test();
$main::unit_test_steps = <<'EOB'
repeat: often

step: Value must be present
verifypositive: SYS 49152
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Repeat directive value must be a whole number without quotes}, '_parse_lean_test_steps : repeat directive must be numeric');

# repeat value must not begin with 0
before_test();
$main::unit_test_steps = <<'EOB'
repeat: 05

step: Value must be present
verifypositive: SYS 49152
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Repeat directive value must be a whole number without quotes. It must not begin with 0}, '_parse_lean_test_steps : repeat directive must not begin with 0');

# runaway quote - no end quote
before_test();
$main::unit_test_steps = <<'EOB'
step: Value must be present
shell:[[: [[SYS 49152
Some more lines
end of file - no end quote!
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{End of file reached, but quote starting line 2 not found}, '_parse_lean_test_steps : runaway quote');

# runaway multi line comment - no end comment
before_test();
$main::unit_test_steps = <<'EOB'
--=
comment

step: do something
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Possible runaway multi line comment starting line 1}, '_parse_lean_test_steps : runaway multi line comment');

# step block must start with step parameter
before_test();
$main::unit_test_steps = <<'EOB'
shell: echo NOP
step: Value must be present
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{First parameter of step block must be step:}, '_parse_lean_test_steps : first parameter is step - 1');
assert_stdout_contains(q{Parse error line 1}, '_parse_lean_test_steps : first parameter is step - 2');

# id is a reserved parameter
before_test();
$main::unit_test_steps = <<'EOB'
step: Value must be present
shell: echo NOP
id: 152
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Parameter id is reserved}, '_parse_lean_test_steps : id is reserved - 1');
assert_stdout_contains(q{Parse error line 3}, '_parse_lean_test_steps : id is reserved - 2');

# command is a reserved parameter
before_test();
$main::unit_test_steps = <<'EOB'
step: Value must be present
shell: echo NOP
command: echo Stuff
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Parameter command is reserved}, '_parse_lean_test_steps : command is reserved');

# method can be delete
before_test();
$main::unit_test_steps = <<'EOB'
step: Value must be present
url: https://www.totaljobs.com/job/49152
method: delete
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'method' => 'delete'}, '_parse_lean_test_steps : method can be delete');

# method can be put
before_test();
$main::unit_test_steps = <<'EOB'
step: Value must be present
url: https://www.totaljobs.com/job/49152
method: put
postbody: abd=efg&hijk=lmnop
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'method' => 'put'}, '_parse_lean_test_steps : method can be put');

# method cannot be get - only put and delete accepted
before_test();
$main::unit_test_steps = <<'EOB'
step: Value must be present
url: https://www.totaljobs.com/job/49152
method: get
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Method parameter can only contain values of 'delete' or 'put'. Other values will be inferred}, '_parse_lean_test_steps : method can only be delete or put');

# duplicate attribute found
before_test();
$main::unit_test_steps = <<'EOB'
step: Value must be present
url: https://www.totaljobs.com/job/49152
url: https://www.totaljobs.com/job/792168
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Duplicate parameter url found}, '_parse_lean_test_steps : duplicate parameter - 1');
assert_stdout_contains(q{Parse error line 3}, '_parse_lean_test_steps : duplicate parameter - 2');

# tab before value - no quote is an error
before_test();
$main::unit_test_steps = <<'EOB'
step:	Value must be present
url:    https://www.totaljobs.com/job/49152
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Tab character found on column 6 of line 1. Please use spaces}, '_parse_lean_test_steps : tab before value - no quote');

# tab before value - with quote one liner is an error
before_test();
$main::unit_test_steps = <<'EOB'
step:$: 	  $Value must be present$
url:    https://www.totaljobs.com/job/49152
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Tab character found on column 9 of line 1. Please use spaces}, '_parse_lean_test_steps : tab before value - with quote one liner');

# tab before value - with quote multi line is an error
before_test();
$main::unit_test_steps = <<'EOB'
step:$: 	  $		Value must be present
in all cases	$
url:    https://www.totaljobs.com/job/49152
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Tab character found on column 9 of line 1. Please use spaces}, '_parse_lean_test_steps : tab before value - with quote multi line');

# tab can appear in value
before_test();
$main::unit_test_steps = <<'EOB'
step:$:   $		Value must be present
in all cases	$
url:      https://www.totaljobs.com/job/49152
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{parsed OK}, '_parse_lean_test_steps : tab can appear in value');

# special characters can be used
before_test();
$main::unit_test_steps = <<'EOB'
step:£€: £€My cool test with £ and € chars£€ 
shell: echo hello and also £€
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{parsed OK}, '_parse_lean_test_steps : special chars do not croak');

# specify one include file
before_test();
$main::unit_test_steps = <<'EOB'
step: This is my first step, 10 
shell: REM 10

include: examples/advanced/include/include_demo_1.test

step: This is my third step, 30 
shell: REM 30
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{parsed OK}, '_parse_lean_test_steps : include file names read in - 1');
assert_stdout_contains(q{'include' =>}, '_parse_lean_test_steps : include file names read in - 2');
assert_stdout_contains(q{'20' => 'examples/advanced/include/include_demo_1.test'}, '_parse_lean_test_steps : include file names read in - 3');

# specify include file with backslash
before_test();
$main::unit_test_steps = <<'EOB'
step: This is my first step, 10 
shell: REM 10

include: examples/advanced/include\include_demo_1.test

step: This is my third step, 30 
shell: REM 30
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{parsed OK}, '_parse_lean_test_steps : include file names read in with backslash - 1');
assert_stdout_contains(q{'include' =>}, '_parse_lean_test_steps : include file names read in with backslash - 2');

# specify two include files
before_test();
$main::unit_test_steps = <<'EOB'
step: This is my first step, 10 
shell: REM 10

include: examples/advanced/include/include_demo_1.test

step: This is my third step, 30 
shell: REM 30

include: examples/advanced/include/include_demo_2.test

EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'20' => 'examples/advanced/include/include_demo_1.test'}, '_parse_lean_test_steps : multi include files read in - 1');
assert_stdout_contains(q{'40' => 'examples/advanced/include/include_demo_2.test'}, '_parse_lean_test_steps : multi include files read in - 1');

# include file gets loaded
before_test();
$main::unit_test_steps = <<'EOB'
step: This is my first step, 10 
shell: REM 10

include: examples/advanced/include/include_demo_1.test

step: This is my third step, 30 
shell: REM 30
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'20.01' =>}, '_parse_lean_test_steps : include file read in - 1');
assert_stdout_contains(q{'shell' => 'echo include demo 1'}, '_parse_lean_test_steps : include file read in - 2');
assert_stdout_contains(q{'30' =>}, '_parse_lean_test_steps : include file read in - 3');
assert_stdout_contains(q{'shell' => 'REM 30'}, '_parse_lean_test_steps : include file read in - 4');

# include file with multiple steps gets loaded
before_test();
$main::unit_test_steps = <<'EOB'
step: This is my first step, 10 
shell: REM 10

include: examples/advanced/include/include_demo_3.test

step: This is my third step, 30 
shell: REM 30
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'20.01' =>}, '_parse_lean_test_steps : include file multi steps read in - 1');
assert_stdout_contains(q{'20.02' =>}, '_parse_lean_test_steps : include file multi steps read in - 2');
assert_stdout_contains(q{'shell' => 'echo include demo 3 first'}, '_parse_lean_test_steps : include file multi steps read in - 3');
assert_stdout_contains(q{'shell' => 'echo include demo 3 second'}, '_parse_lean_test_steps : include file multi steps read in - 4');
assert_stdout_contains(q{'step' => 'Demo 3 include step .01'}, '_parse_lean_test_steps : include file multi steps read in - 5');
assert_stdout_contains(q{'step' => 'Demo 3 include step .02'}, '_parse_lean_test_steps : include file multi steps read in - 6');
assert_stdout_contains(q{'30' =>}, '_parse_lean_test_steps : include file multi steps read in - 7');
assert_stdout_contains(q{'shell' => 'REM 30'}, '_parse_lean_test_steps : include file multi steps read in - 8');

# include multi files gets loaded
before_test();
$main::unit_test_steps = <<'EOB'
step: This is my first step, 10 
shell: REM 10

include: examples/advanced/include/include_demo_1.test

step: This is my third step, 30 
shell: REM 30

include: examples/advanced/include/include_demo_2.test
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'20.01' =>}, '_parse_lean_test_steps : include multi file read in - 1');
assert_stdout_contains(q{'shell' => 'echo include demo 1'}, '_parse_lean_test_steps : include multi file read in - 2');
assert_stdout_contains(q{'step' => 'This is include step .01'}, '_parse_lean_test_steps : include multi file read in - 3');
assert_stdout_contains(q{'30' =>}, '_parse_lean_test_steps : include multi file read in - 4');
assert_stdout_contains(q{'shell' => 'REM 30'}, '_parse_lean_test_steps : include multi file read in - 5');
assert_stdout_contains(q{'40.01' =>}, '_parse_lean_test_steps : include multi file read in - 6');
assert_stdout_contains(q{'shell' => 'echo include demo 2'}, '_parse_lean_test_steps : include multi file read in - 7');
assert_stdout_contains(q{'step' => 'Another include step .01'}, '_parse_lean_test_steps : include multi file read in - 8');

# repeat cannot be encountered twice - primary file
before_test();
$main::unit_test_steps = <<'EOB'
repeat: 5

step: This is my first step, 10 
shell: REM 10

step: This is my third step, 30 
shell: REM 30

repeat: 2
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Repeat directive can only be given once globally}, '_parse_lean_test_steps : repeat is declared once only - 1');
assert_stdout_contains(q{Parse error line 9}, '_parse_lean_test_steps : repeat is declared once only - 2');

# repeat cannot be encountered twice - include file
before_test();
$main::unit_test_steps = <<'EOB'
repeat: 5

step: This is my first step, 10 
shell: REM 10

include: examples/advanced/include/include_demo_4.test

step: This is my third step, 30 
shell: REM 30
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{Repeat directive can only be given once globally}, '_parse_lean_test_steps : repeat is declared once only - 3');
assert_stdout_contains(q{Parse error line 5}, '_parse_lean_test_steps : repeat is declared once only - 4');

# when include file fails to parse, give its filename
before_test();
$main::unit_test_steps = <<'EOB'
step: Include file has a parser error

include: examples/advanced/include/broken.test
EOB
    ;
eval { read_test_steps_file(); };
assert_stdout_contains(q{First parameter of step block must be step:}, '_parse_lean_test_steps : parse error in include file - 1');
assert_stdout_contains(q{Parse error line 3}, '_parse_lean_test_steps : parse error in include file - 2');
assert_stdout_contains(q{broken.test}, '_parse_lean_test_steps : parse error in include file - 3');

# section break increases step id to the next round 100 value
before_test();
$main::unit_test_steps = <<'EOB'
step: This is my first step, 10 
shell: REM 10

step: This is my third step, 100 
section: section break
shell: REM 100
EOB
    ;
read_test_steps_file();
assert_stdout_contains(q{'100' => }, '_parse_lean_test_steps : section break increases step id to next round 100');

# support testvar

#issues:
#   repeat parm needs to be renamed eventually for WebImblaze


#
# _verify_verifypositive
#

before_test();
$main::case{verifypositive1} = 'brown fox';
$main::resp_content = ('The quick brown fox jumps over the lazy dog');
_verify_verifypositive();
assert_stdout_contains('Passed Positive Verification', '_verify_verifypositive : Pass simple verifypositive');

before_test();
$main::case{verifypositive1} = 'brown [f-x]{3} jumps';
$main::resp_content = ('The quick brown fox jumps over the lazy dog');
_verify_verifypositive();
assert_stdout_contains('Passed Positive Verification', '_verify_verifypositive : Pass regex verifypositive');

before_test();
$main::case{verifypositive1} = 'blue fox';
$main::resp_content = ('The quick brown fox jumps over the lazy dog');
_verify_verifypositive();
assert_stdout_contains('Failed Positive Verification 1', '_verify_verifypositive : Fail simple verifypositive');

before_test();
$main::case{verifypositive} = 'blue fox';
$main::resp_content = ('The quick brown fox jumps over the lazy dog');
_verify_verifypositive();
assert_stdout_contains('Failed Positive Verification 0', '_verify_verifypositive : Fail simple verifypositive for special case position 0');

before_test();
$main::case{verifypositiveA} = 'blue fox|||This message shown on failure';
$main::resp_content = ('The quick brown fox jumps over the lazy dog');
_verify_verifypositive();
assert_stdout_contains('Failed Positive Verification A', '_verify_verifypositive : Special message - 1');
assert_stdout_contains('This message shown on failure', '_verify_verifypositive : Special message - 2');

before_test();
$main::case{verifypositive9999} = 'blue fox|||This message shown on failure|||Known issue';
$main::resp_content = ('The quick brown fox jumps over the lazy dog');
_verify_verifypositive();
assert_stdout_contains('Skipped Positive Verification 9999 - Known issue', '_verify_verifypositive : Known Issue');

before_test();
$main::case{verifypositive2} = 'fail fast!blue fox';
$main::case{retry} = '5';
$main::resp_content = ('The quick brown fox jumps over the lazy dog');
set_number_of_times_to_retry_this_test_step();
_verify_verifypositive();
assert_stdout_contains(q{Won't retry - a fail fast was invoked}, '_verify_verifypositive : Fail fast - 1');

before_test();
$main::case{verifypositive2} = 'fail fast!brown fox';
$main::resp_content = ('The quick brown fox jumps over the lazy dog');
_verify_verifypositive();
assert_stdout_contains('Passed Positive Verification', '_verify_verifypositive : Fail fast - 2');

before_test();
$main::case{verifypositive2} = 'fail fast!blue fox';
$main::case{retry} = '0';
$main::resp_content = ('The quick brown fox jumps over the lazy dog');
set_number_of_times_to_retry_this_test_step();
_verify_verifypositive();
assert_stdout_does_not_contain(q{Won't retry - a fail fast was invoked}, '_verify_verifypositive : Fail fast - 3');


#
# pass_fail_or_retry
#

before_test();
$main::case{verifypositive2} = 'blue fox';
$main::case{errormessage} = 'Could not find blue fox';
$main::resp_content = ('The quick brown fox jumps over the lazy dog');
_verify_verifypositive();
pass_fail_or_retry();
assert_stdout_contains('TEST STEP FAILED : Could not find blue fox', 'pass_fail_or_retry : Custom error message');

before_test();
$main::case{verifypositive2} = 'blue fox';
$main::case{retry} = '2';
$main::resp_content = ('The quick brown fox jumps over the lazy dog');
set_number_of_times_to_retry_this_test_step();
_verify_verifypositive();
pass_fail_or_retry();
assert_stdout_contains('RETRYING', 'pass_fail_or_retry : Retry available - retrying');


#
# resources
#

make_path ($WEBIMBLAZE_ROOT . $OUTPUT); # here to give remove_tree more time to settle

sub resources_setup {
    my (undef, $_goner) = @_;
    if ($_goner) {
        $_goner = $WEBIMBLAZE_ROOT . $OUTPUT . $_goner;
        if (-e $_goner ) { unlink $_goner }
    }
    $main::cookie_jar = HTTP::Cookies->new;
    $main::useragent = LWP::UserAgent->new(keep_alive=>1);
    $main::case{url} = "file:///$WEBIMBLAZE_ROOT/basic.html";
    $main::case{method} = 'get';
    return;
}

resources_setup(before_test());
$main::case{getallhrefs} = '\.css|\.less';
$main::resp_content = (q{ href="examples/assets/css/simple.css" });
getresources();
assert_stdout_contains('GET Asset \[version1_simple\.css\]', 'resources : simple.css matched - double quote');
assert_file_exists($WEBIMBLAZE_ROOT . $OUTPUT . 'version1_simple.css', 'resources : version1_simple.css file written - double quote');
assert_file_contains($WEBIMBLAZE_ROOT . $OUTPUT . 'version1_simple.css', 'text-align: center' ,'resources : version1_simple.css file has correct content - double quote');
_response_content_substitutions(\ $main::resp_content);
assert_resp_content_contains('href="version1_simple.css"', 'resources : version1_simple.css substituted into resp_content - double quote');

resources_setup(before_test(), 'version1_simple.css');
$main::case{getallhrefs} = '\.css|\.less';
$main::resp_content = (q{ href='examples/assets/css/simple.css' });
getresources();
assert_stdout_contains('GET Asset \[version1_simple\.css\]', 'resources : simple.css matched - single quote');
_response_content_substitutions(\ $main::resp_content);
assert_resp_content_contains('href="version1_simple.css"', 'resources : version1_simple.css substituted into resp_content - single quote, now double');
$main::resp_content = (q{ href='somewhere/nonmatched.css' });
_response_content_substitutions(\ $main::resp_content);
assert_resp_content_contains(q{href="somewhere/nonmatched.css"}, 'resources : nonmatched href - single quote, now double');

resources_setup(before_test(), 'version1_simple.css');
$main::case{getallhrefs} = '\.css|\.less';
$main::resp_content = (' href="examples\assets\css\simple.css" ');
getresources();
assert_stdout_contains('GET Asset \[version1_simple\.css\]', 'resources : simple.css matched - backslash path');
_response_content_substitutions(\ $main::resp_content);
assert_resp_content_contains('href="version1_simple.css"', 'resources : version1_simple.css substituted into resp_content - backslash path');

resources_setup(before_test());
$main::case{getallsrcs} = '\.js|\.gif';
$main::resp_content = (q{ src="examples/assets/js/quick.js" });
getresources();
assert_stdout_contains('GET Asset \[version1_quick\.js\]', 'resources : quick.js matched - double quote');
assert_file_exists($WEBIMBLAZE_ROOT . $OUTPUT . 'version1_quick.js', 'resources : version1_quick.js file written');
assert_file_contains($WEBIMBLAZE_ROOT . $OUTPUT . 'version1_quick.js', 'var i = 54' ,'resources : version1_quick.js file has correct content');
_response_content_substitutions(\ $main::resp_content);
assert_resp_content_contains('src="version1_quick.js"', 'resources : version1_quick.js substituted into resp_content - double quote');

resources_setup(before_test(), 'version1_quick.js');
$main::case{getallsrcs} = '\.js|\.gif';
$main::resp_content = (q{ src='examples/assets/js/quick.js' });
getresources();
assert_stdout_contains('GET Asset \[version1_quick\.js\]', 'resources : quick.js matched - single quote');
_response_content_substitutions(\ $main::resp_content);
assert_resp_content_contains('src="version1_quick.js"', 'resources : version1_quick.js substituted into resp_content - single quote, now double');
$main::resp_content = (q{ src='somewhere/nonmatched.js' });
_response_content_substitutions(\ $main::resp_content);
assert_resp_content_contains(q{src="somewhere/nonmatched.js"}, 'resources : nonmatched src - single quote, now double');

resources_setup(before_test(), 'version1_quick.js');
$main::case{getallsrcs} = '\.js|\.gif';
$main::resp_content = (q{ src="examples\assets\js\quick.js" });
getresources();
assert_stdout_contains('GET Asset \[version1_quick\.js\]', 'resources : quick.js matched - backslash path');
_response_content_substitutions(\ $main::resp_content);
assert_resp_content_contains('src="version1_quick.js"', 'resources : version1_quick.js substituted into resp_content - backslash path');

resources_setup(before_test());
$main::case{getallsrcs} = '\.js|\.png';
$main::resp_content = (q{ src="examples/assets/image/folder.png" });
getresources();
assert_stdout_contains('GET Asset \[version1_folder\.png\]', 'resources : image.png matched');
assert_file_exists($WEBIMBLAZE_ROOT . $OUTPUT . 'version1_folder.png', 'resources : version1_folder.png file written');
_response_content_substitutions(\ $main::resp_content);
assert_resp_content_contains('src="version1_folder.png"', 'resources : version1_folder.png substituted into resp_content');

resources_setup(before_test(), 'version1_folder.png');
$main::case{getbackgroundimages} = '\.tif|\.png';
$main::resp_content = (q{ <div style="background-image: url('examples/assets/image/folder.png');"> });
getresources();
assert_stdout_contains('GET Asset \[version1_folder\.png\]', 'resources : image.png matched as background image - single quote');
assert_file_exists($WEBIMBLAZE_ROOT . $OUTPUT . 'version1_folder.png', 'resources : version1_folder.png file written - single quote');
_response_content_substitutions(\ $main::resp_content);
assert_resp_content_contains(q{style="background-image: url\('version1_folder.png'\);"}, 'resources : version1_folder.png substituted into resp_content - single quote');

resources_setup(before_test(), 'version1_folder.png');
$main::case{getbackgroundimages} = '\.tif|\.png';
$main::resp_content = (q{ <div style='background-image: url("examples/assets/image/folder.png");'> });
getresources();
assert_stdout_contains('GET Asset \[version1_folder\.png\]', 'resources : image.png matched as background image - double quote');
assert_file_exists($WEBIMBLAZE_ROOT . $OUTPUT . 'version1_folder.png', 'resources : version1_folder.png file written - double quote');
_response_content_substitutions(\ $main::resp_content);
assert_resp_content_contains(q{style="background-image: url\('version1_folder.png'\);"}, 'resources : version1_folder.png substituted into resp_content - double quote');

resources_setup(before_test(), 'version1_folder.png');
$main::case{getbackgroundimages} = '\.tif|\.png';
$main::resp_content = (q{ <div style='background-image: url("examples/assets/image/folder.png");'> });
getresources(); # grab the asset
$main::resp_content = (q{ <div style='background-image: url("some_other_bgimage.png");'> }); # assume this asset was not grabbed
_response_content_substitutions(\ $main::resp_content);
assert_resp_content_contains(q{style="background-image: url\('some_other_bgimage.png'\);"}, 'resources : asset not substituted but now double then single quote');

resources_setup(before_test());
$main::case{getallhrefs} = '\.css|\.less';
$main::case{getallsrcs} = '\.js|\.png';
$main::case{getbackgroundimages} = '\.tif|\.png';
$main::resp_content = (q{ <div style='background-image: url("file0.png");'> href='file1.css' href='file2.less' href='file3.css' src='file4.js' src='file5.js' });
getresources(); # grab the asset
assert_stdout_contains('GET Asset \[version1_file0\.png\]', 'resources : GET multi file0.png ');
assert_stdout_contains('GET Asset \[version1_file1\.css\]', 'resources : GET multi file1.css ');
assert_stdout_contains('GET Asset \[version1_file2\.less\]', 'resources : GET multi file2.less ');
assert_stdout_contains('GET Asset \[version1_file3\.css\]', 'resources : GET multi file3.css ');
assert_stdout_contains('GET Asset \[version1_file4\.js\]', 'resources : GET multi file4.js ');
assert_stdout_contains('GET Asset \[version1_file5\.js\]', 'resources : GET multi file5.js ');
_response_content_substitutions(\ $main::resp_content);
assert_resp_content_contains(q{style="background-image: url\('version1_file0.png'\);"}, 'resources : version1_file0.png substituted into resp_content - multi');
assert_resp_content_contains('href="version1_file1.css"', 'resources : version1_file1.css substituted into resp_content - multi');
assert_resp_content_contains('href="version1_file2.less"', 'resources : version1_file2.less substituted into resp_content - multi');
assert_resp_content_contains('href="version1_file3.css"', 'resources : version1_file3.css substituted into resp_content - multi');
assert_resp_content_contains('src="version1_file4.js"', 'resources : version1_file4.js substituted into resp_content - multi');
assert_resp_content_contains('src="version1_file5.js"', 'resources : version1_file5.js substituted into resp_content - multi');
$main::resp_content = (q{ <div style="background-image: url('notfile0.png');"> href='notfile2.less' href='notfile3.css' src='notfile4.js' }); # assume this asset was not grabbed
_response_content_substitutions(\ $main::resp_content);
assert_resp_content_contains(q{background-image: url\('notfile0.png'\)}, 'resources : not substituted - multi - but single to double quote - 2');
assert_resp_content_contains('href="notfile2.less"', 'resources : not substituted - multi - but single to double quote - 2');
assert_resp_content_contains('href="notfile3.css"', 'resources : not substituted - multi - but single to double quote - 3');
assert_resp_content_contains('src="notfile4.js"', 'resources : not substituted - multi - but single to double quote - 4');


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
        is('see between dashes below for stdout', $_must_contain, $_test_description);
        show_string($main::results_stdout);
    }
    return;
}

sub assert_resp_content_contains {
    my ($_must_contain, $_test_description) = @_;
    if ($main::resp_content =~ m/$_must_contain/s) {
        is(1, 1, $_test_description);
    } else {
        is('see between dashes below for resp_content', $_must_contain, $_test_description);
        show_string($main::resp_content."\n");
    }
    return;
}

sub assert_file_exists {
    my ($_target_file, $_test_description) = @_;
    if (-e $_target_file) {
        is(1, 1, $_test_description);
    } else {
        is('see between dashes below for stdout', $_target_file . ' to exist', $_test_description);
        show_string($main::results_stdout);
    }
    return;
}

sub assert_file_contains {
    my ($_target_file, $_must_contain, $_test_description) = @_;
    my $_content_ref = read_utf8($_target_file);
    if (${ $_content_ref } =~ m/$_must_contain/s) {
        is(1, 1, $_test_description);
    } else {
        is('see between dashes below for 1 - stdout, 2 - file content', $_target_file . ' to contain "' . $_must_contain . q{"}, $_test_description);
        show_string($main::results_stdout);
        show_string(${ $_content_ref }."\n");
    }
    return;
}

sub assert_stdout_does_not_contain {
    my ($_must_not_contain, $_test_description) = @_;
    if ($main::results_stdout =~ m/$_must_not_contain/s) {
        isnt($main::results_stdout, $main::results_stdout, $_test_description);
        print '# not expected: '.$_must_not_contain."\n";
    } else {
        is(1, 1, $_test_description);
    }
    return;
}

sub clear_stdout {
    $main::results_stdout = q{};
    return;
}

sub show_string {
    my ($_string) = @_;
    print "\n---------------\n".$_string."---------------\n";
    return;
}

sub before_test {
    $main::EXTRA_VERBOSE = 1;

    _init_main_loop_variables();
    _init_retry_loop_variables();
    $main::case{retry} = '0';
    set_number_of_times_to_retry_this_test_step();
    undef %main::case;
    $main::case{url} = 'http://example.com/jobs/search.cgi?query=Test%Automation&Location=London';
    $main::results_stdout = q{};
    $main::response = HTTP::Response->parse('HTTP/1.1 200 OK');
    $main::resp_content = q{};
    $main::resp_headers = q{};
    $main::opt_publish_full = $OUTPUT;
    undef $main::cookie_jar;
    undef $main::useragent;
    $main::testnum = '1';

    undef @main::hrefs;
    undef @main::srcs;
    undef @main::bg_images;
    undef %main::asset;

    undef @main::cached_pages;
    undef @main::cached_page_actions;
    undef @main::cached_page_update_times;

    return;
}


#
# SUPPRESS WARNINGS FOR VARIABLES USED ONLY ONCE
#

$main::response = q{};
$main::resp_content = q{};
$main::resp_headers = q{};
$main::EXTRA_VERBOSE = 0;
$main::results_stdout = q{};
$main::unit_test_steps = q{};
$main::opt_publish_full = q{};
$main::this_script_folder_full = q{};
$main::testnum = q{};
$main::cookie_jar = q{};
undef @main::srcs;
undef @main::bg_images;
undef @main::asset;
undef @main::hrefs;
undef @main::cached_pages;
undef @main::cached_page_actions;
undef @main::cached_page_update_times;
