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
$main::response = HTTP::Response->parse('A response without an action');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('ACTION none', 'save_page_when_method_post_and_has_action : ACTION none');

before_test();
$main::response = HTTP::Response->parse('A response with an action after post - method="post" id="3" action="submit.aspx"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('ACTION submit.aspx', 'save_page_when_method_post_and_has_action : ACTION after method of post');

before_test();
$main::response = HTTP::Response->parse('A response with an action before post - action="submit.aspx" id="3" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('ACTION submit.aspx', 'save_page_when_method_post_and_has_action : ACTION before method of post');

before_test();
$main::response = HTTP::Response->parse('A response with a null action - action="" id="3" method="post"');
save_page_when_method_post_and_has_action ();
is(stdout_contains('ACTION IS NULL'), 1, 'save_page_when_method_post_and_has_action : ACTION IS NULL');
assert_stdout_contains('SAVING /jobs/search.cgi', 'save_page_when_method_post_and_has_action : default action to page path');

before_test();
$main::response = HTTP::Response->parse('A response with full url in action="https://example.com/home/query.cgi?keyword=test" method="post"');
save_page_when_method_post_and_has_action ();
is(stdout_contains('ACTION https:'), 1, 'save_page_when_method_post_and_has_action : full url in action');
assert_stdout_contains('SAVING /home/query.cgi', 'save_page_when_method_post_and_has_action : clean action to just url path');

before_test();
$main::response = HTTP::Response->parse('action="submit.aspx" id="3" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('NO CACHED PAGES', 'save_page_when_method_post_and_has_action : NO CACHED PAGES');

before_test();
$main::response = HTTP::Response->parse('action="submit.aspx" id="3" method="post"');
save_page_when_method_post_and_has_action ();
save_page_when_method_post_and_has_action ();
assert_stdout_contains('MATCH at position 0', 'save_page_when_method_post_and_has_action : MATCH at position 0');

before_test();
$main::response = HTTP::Response->parse('action="submit.aspx" id="3" method="post"');
save_page_when_method_post_and_has_action ();
$main::response = HTTP::Response->parse('action="query.aspx" id="3" method="post"');
save_page_when_method_post_and_has_action ();
save_page_when_method_post_and_has_action ();
assert_stdout_contains('MATCH at position 1', 'save_page_when_method_post_and_has_action : MATCH at position 1');

before_test();
$main::response = HTTP::Response->parse('action="submit.aspx" method="post"');
save_page_when_method_post_and_has_action ();
$main::response = HTTP::Response->parse('action="query.aspx" method="post"');
save_page_when_method_post_and_has_action ();
$main::response = HTTP::Response->parse('action="/register.cgi" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('NO MATCH on 0:submit.aspx', 'save_page_when_method_post_and_has_action : NO MATCH on 0:submit.aspx');
assert_stdout_contains('NO MATCH on 1:query.aspx', 'save_page_when_method_post_and_has_action : NO MATCH on 1:query.aspx');
assert_stdout_contains('NO MATCHES FOUND IN CACHE', 'save_page_when_method_post_and_has_action : NO MATCHES FOUND IN CACHE - different action');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('MATCH at position 2', 'save_page_when_method_post_and_has_action : MATCH at position 2');
$main::response = HTTP::Response->parse('action="/submit.aspx" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('NO MATCHES FOUND IN CACHE', 'save_page_when_method_post_and_has_action : NO MATCHES FOUND IN CACHE - slightly different action');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('MATCH at position 3', 'save_page_when_method_post_and_has_action : MATCH at position 3 - slightly different action saved again');



before_test();
$main::response = HTTP::Response->parse('action="index_0" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Index 0 is free', 'save_page_when_method_post_and_has_action : Index 0 is free');

$main::response = HTTP::Response->parse('action="index_1" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Index 1 is free', 'save_page_when_method_post_and_has_action : Index 1 is free');

$main::response = HTTP::Response->parse('action="index_2" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Index 2 is free', 'save_page_when_method_post_and_has_action : Index 2 is free');

$main::response = HTTP::Response->parse('action="index_3" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Index 3 is free', 'save_page_when_method_post_and_has_action : Index 3 is free');

$main::response = HTTP::Response->parse('action="index_4" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Index 4 is free', 'save_page_when_method_post_and_has_action : Index 4 is free');

$main::response = HTTP::Response->parse('action="index_5" method="post"');
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Index 5 is free', 'save_page_when_method_post_and_has_action : Index 5 is free');

$main::response = HTTP::Response->parse('action="page_7" method="post"');
clear_stdout();
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Overwriting - Oldest Page Index: 0', 'save_page_when_method_post_and_has_action : Overwrite oldest page in cache - index 0');

$main::response = HTTP::Response->parse('action="page_8" method="post"');
clear_stdout();
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Overwriting - Oldest Page Index: 1', 'save_page_when_method_post_and_has_action : Overwrite oldest page in cache - index 1');

$main::response = HTTP::Response->parse('action="page_9" method="post"');
clear_stdout();
save_page_when_method_post_and_has_action ();
assert_stdout_contains('Overwriting - Oldest Page Index: 2', 'save_page_when_method_post_and_has_action : Overwrite oldest page in cache - index 2');

clear_stdout();
save_page_when_method_post_and_has_action ();
assert_stdout_contains('MATCH at position 2', 'save_page_when_method_post_and_has_action : MATCH at position 2 - save overwritten page again');

$main::response = HTTP::Response->parse('action="page_8" method="post"');
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
$main::response = HTTP::Response->parse('action="submit.aspx" method="post"');
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
auto_sub('', 'normalpost', 'http://example.com');
assert_stdout_contains('There are 0 fields in the postbody', 'auto_sub : normal post has 0 fields');

before_test();
auto_sub('a=b', 'normalpost', 'http://example.com');
assert_stdout_contains('There are 1 fields in the postbody', 'auto_sub : normal post has 1 field');

before_test();
auto_sub("( 'name' => 'Upload' )", 'multipost', 'http://example.com');
assert_stdout_contains('There are 1 fields in the postbody', 'auto_sub : multi post has 1 field');

before_test();
auto_sub("( 'fileUpload' => ['examples/multipart_post.csv'], 'name' => 'Upload' )", 'multipost', 'http://example.com');
assert_stdout_contains('There are 1 fields in the postbody', 'auto_sub : multi post has 2 fields');

before_test();
auto_sub('a=b&c=d&e=f', 'normalpost', 'http://example.com');
assert_stdout_contains('Field 1: a=b', 'auto_sub : field 1 display');
assert_stdout_contains('Field 2: c=d', 'auto_sub : field 2 display');
assert_stdout_contains('Field 3: e=f', 'auto_sub : field 3 display');

before_test();
auto_sub("(  'a' => 'b', 'c' => 'd', 'e' => 'f' )", 'multipost', 'http://example.com');
assert_stdout_contains(q|Field 1: \(  'a' => 'b|, 'auto_sub : multipost field 1 display');
assert_stdout_contains(q|Field 2:  'c' => 'd|, 'auto_sub : multimpost field 2 display');
assert_stdout_contains(q|Field 3:  'e' => 'f|, 'auto_sub : multimpost field 3 display'); #'

before_test();
is(auto_sub('a=b&c=d&e=f', 'normalpost', 'http://example.com'), 'a=b&c=d&e=f', 'auto_sub : no change - no cached pages');
assert_stdout_contains('REMOVE PATH', 'auto_sub : remove path');
assert_stdout_contains('DESPERATE MODE - NO ANCHOR', 'auto_sub : desperate mode - no anchor');

before_test();
$main::response = HTTP::Response->parse('action="/search.aspx" method="post"');
save_page_when_method_post_and_has_action ();
auto_sub('a=b&c=d&e=f', 'normalpost', 'http://example.com/search.aspx');
assert_stdout_contains('MATCH at position 0', 'auto_sub : exact action match - assert 1');
assert_stdout_does_not_contain('PAGE NAME ONLY', 'auto_sub : exact action match - assert 2');

before_test();
$main::response = HTTP::Response->parse('action="/search.aspx" method="post"');
save_page_when_method_post_and_has_action ();
auto_sub('a=b&c=d&e=f', 'normalpost', 'http://example.com/premium/search.aspx');
assert_stdout_contains('MATCH at position 0', 'auto_sub : page name only - assert 2');
assert_stdout_contains('REMOVE PATH', 'auto_sub : page name only - assert 2');
assert_stdout_does_not_contain('DESPERATE MODE', 'auto_sub : page name only - assert 3');

before_test();
$main::response = HTTP::Response->parse('action="/search.aspx" method="post"');
save_page_when_method_post_and_has_action ();
auto_sub('a=b&c=d&e=f', 'normalpost', 'http://example.com/premium/search');
assert_stdout_contains('MATCH at position 0', 'auto_sub : desperate mode - assert 2');
assert_stdout_contains('DESPERATE MODE', 'auto_sub : desperate mode - assert 2');

before_test();
$main::response = HTTP::Response->parse('action="/search.aspx" method="post" name="a" type="hidden" value="bee bee"');
save_page_when_method_post_and_has_action ();
auto_sub('a={DATA}&c=d&e=f', 'normalpost', 'http://example.com/search.aspx');
assert_stdout_contains('ID MATCH 0', 'auto_sub : ID MATCH');
assert_stdout_contains('Normal field a has \{DATA\}', 'auto_sub : normal field has {DATA}');
assert_stdout_contains('DATA is bee', 'auto_sub : normalpost {DATA} - field 1 - assert 1');
assert_stdout_contains('URLESCAPE!!', 'auto_sub : normalpost {DATA} - field 1 - assert 2');
assert_stdout_contains('SUBBED FIELD is a=bee%20bee', 'auto_sub : normalpost {DATA} - field 1 - assert 3');
assert_stdout_contains('a=bee%20bee', 'auto_sub : normalpost {DATA} - field 1 - assert 4');

before_test();
$main::response = HTTP::Response->parse('action="/search.aspx" method="post" <input name="c" value="dee" /> <input name="e" value="eff" />');
save_page_when_method_post_and_has_action ();
auto_sub('a=b&c={DATA}&e={DATA}', 'normalpost', 'http://example.com/search.aspx');
assert_stdout_contains('c=dee', 'auto_sub : normalpost {DATA} - field 2');
assert_stdout_contains('e=eff', 'auto_sub : normalpost {DATA} - field 3');

before_test();
$main::response = HTTP::Response->parse('action="/search.aspx" method="post" name="a" type="hidden" value="bee bee"');
save_page_when_method_post_and_has_action ();
auto_sub("(  'a' => '{DATA}', 'c' => 'd', 'e' => 'f' )", 'multipost', 'http://example.com/search.aspx');
assert_stdout_contains('ID MATCH 0', 'auto_sub : ID MATCH');
assert_stdout_contains('Multi field a has \{DATA\}', 'auto_sub : multi field has {DATA}');
assert_stdout_contains('DATA is bee', 'auto_sub : multipost {DATA} - field 1 - assert 1');
assert_stdout_contains(q|SUBBED FIELD is \(  'a' => 'bee bee|, 'auto_sub : multipost {DATA} - field 1 - assert 2'); #'
assert_stdout_contains(q|POSTBODY is \(  'a' => 'bee bee', 'c' => 'd', 'e' => 'f' \)|, 'auto_sub : multipost {DATA} - field 1 - assert 3');
assert_stdout_contains('Auto substitution latency was ', 'auto_sub : latency display');

before_test();
$main::response = HTTP::Response->parse('action="/search.aspx" method="post" <input name="c" value="dee" /> <input name="e" value="eff" />');
save_page_when_method_post_and_has_action ();
auto_sub(q|(  'a' => 'b', 'c' => '{DATA}', 'e' => '{DATA}' )|, 'multipost', 'http://example.com/search.aspx');
assert_stdout_contains(q|'c' => 'dee'|, 'auto_sub : multipost {DATA} - field 2');
assert_stdout_contains(q|'e' => 'eff'|, 'auto_sub : multipost {DATA} - field 3');

before_test();
$main::response = HTTP::Response->parse('action="/search.aspx" method="post" name="Row1_Col1_Field1" type="hidden" value="b"');
save_page_when_method_post_and_has_action ();
auto_sub('Row1_{NAME}_Field1=b&c=d&e=f', 'normalpost', 'http://example.com/search.aspx');
assert_stdout_contains('LHS of \{NAME}: \[Row1_] ', 'auto_sub : normal post - LHS of {NAME}');
assert_stdout_contains('RHS of \{NAME}: \[_Field1] ', 'auto_sub : normal post - RHS of {NAME}');
assert_stdout_contains('NAME is Col1', 'auto_sub : normal post - NAME is');
assert_stdout_contains('SUBBED NAME is Row1_Col1_Field1=b', 'auto_sub : normal post - SUBBED NAME is');

before_test();
$main::response = HTTP::Response->parse('action="/search.aspx" method="post" <input name="Row2_Col2_Field2" value="d" /> <input name="Row3_Col3_Field3" value="f" /> ');
save_page_when_method_post_and_has_action ();
auto_sub('Row1_Col1_Field1=b&Row2_{NAME}_Field2=d&Row3_{NAME}_Field3=f', 'normalpost', 'http://example.com/search.aspx');
assert_stdout_contains('NAME is Col2', 'auto_sub : normal post - NAME is - field 2');
assert_stdout_contains('NAME is Col3', 'auto_sub : normal post - NAME is - field 2');

before_test();
$main::response = HTTP::Response->parse('action="/search.aspx" method="post" name="Row1_Col1_Field1" type="hidden" value="b"');
save_page_when_method_post_and_has_action ();
auto_sub('{NAME}_Field1=b&c=d&e=f', 'normalpost', 'http://example.com/search.aspx');
assert_stdout_contains('LHS of \{NAME}: \[] ', 'auto_sub : LHS of {NAME} is null');

before_test();
$main::response = HTTP::Response->parse('action="/search.aspx" method="post" name="Row1_Col1_Field1" type="hidden" value="b"');
save_page_when_method_post_and_has_action ();
auto_sub('Row1_Col1_{NAME}=b&c=d&e=f', 'normalpost', 'http://example.com/search.aspx');
assert_stdout_contains('RHS of \{NAME}: \[] ', 'auto_sub : RHS of {NAME} is null');

before_test();
$main::response = HTTP::Response->parse('action="/search.aspx" method="post" <input name="Row2_Col2_Field2" value="d" /> <input name="Row3_Col3_Field3" value="f" /> ');
save_page_when_method_post_and_has_action ();
auto_sub(q|(  'a' => 'b', 'Row2_{NAME}_Field2' => '{DATA}', '{NAME}Field3' => '{DATA}' )|, 'multipost', 'http://example.com/search.aspx');
assert_stdout_contains(q|POSTBODY is \(  'a' => 'b', 'Row2_Col2_Field2' => 'd', 'Row3_Col3_Field3' => 'f' \)|, 'auto_sub : multi post - NAME and DATA');

before_test();
$main::response = HTTP::Response->parse('action="/search.aspx" method="post" <input name="strange_xname" value="d" /> <input name="odd_yname" value="f" /> ');
save_page_when_method_post_and_has_action ();
auto_sub(q|(  'a' => 'b', '{NAME}_xname.x' => '{DATA}', '{NAME}_yname.y' => '{DATA}' )|, 'multipost', 'http://example.com/search.aspx');
assert_stdout_contains('DOTx found in ', 'auto_sub : NAME - DOTX');
assert_stdout_contains('DOTy found in ', 'auto_sub : NAME - DOTY');
assert_stdout_contains(q|DOTx restored to  'strange_xname.x'|, 'auto_sub : NAME - DOTX restored');
assert_stdout_contains(q|DOTy restored to  'odd_yname.y'|, 'auto_sub : NAME - DOTY restored');
assert_stdout_contains(q|POSTBODY is \(  'a' => 'b', 'strange_xname.x' => 'd', 'odd_yname.y' => 'f' \)|, 'auto_sub : DOTX and DOTY');

before_test();
$main::response = HTTP::Response->parse('action="/search.aspx" method="post" <input name="odd_xname" value="default" /> <input name="odd_yname" value="default" /> ');
save_page_when_method_post_and_has_action ();
auto_sub('a=b&{NAME}xname.x=d.xtra&{NAME}yname.y=f.ytra', 'normalpost', 'http://example.com/search.aspx');
assert_stdout_contains('odd_xname\.x=d\.xtra', 'auto_sub : DOTX - ensure value not affected');
assert_stdout_contains('odd_yname\.y=f\.ytra', 'auto_sub : DOTY - ensure value not affected');

#
#
# Lean Test Format
#
#

# Do not attempt to parse classic webinject xml style format as lean tests format
before_test();
$main::unit_test_steps = <<'EOB'
<testcases repeat="1">

<case
    id="10"
    description1="Test that WebInject can run a very basic test"
    method="cmd"
    command="REM Nothing much"
    verifypositive1="Nothing much"
/>

<case
    id="20"
    description1="Another step - retry {RETRY}"
    description2="Sub description"
    method="cmd"
    command="REM Not much more - retry {RETRY}"
    verifypositive="retry 1"
    verifynegative="Nothing much"
    retry="3"
/>

</testcases>
EOB
    ;
read_test_case_file();
assert_stdout_contains('Classic WebInject xml style format detected', 'read_test_case_file : can detect classic xml test step format');
assert_stdout_contains('Classic test steps parsed OK', 'read_test_case_file : classic style format parsed ok');

# Lean test format will convert to classic xml style webinject

# XMLin function creates a data structure like the below, the lean parse must produce the same structure
#
#$VAR1 = {
#          'case' => {
#                      '20' => {
#                                'description1' => 'Another step - retry {RETRY}',
#                                'description2' => 'Sub description',
#                                'method' => 'cmd',
#                                'command' => 'REM Not much more - retry {RETRY}',
#                                'retry' => '3',
#                                'verifynegative' => 'Nothing much',
#                                'verifypositive' => 'retry 1'
#                              },
#                      '10' => {
#                                'description1' => 'Test that WebInject can run a very basic test',
#                                'command' => 'REM Nothing: much',
#                                'method' => 'cmd',
#                                'verifypositive1' => 'Nothing: much'
#                              }
#                    },
#          'repeat' => '1'
#        };

before_test();
$main::unit_test_steps = <<'EOB'
step: Test that WebInject can run a very basic test
shell: REM Nothing: much
verifypositive1: Nothing: much

step: Another step - retry {RETRY}
description2: Sub description
shell: REM Not much more - retry {RETRY}
verifypositive: retry 1
verifynegative: Nothing much
retry: 3
EOB
    ;
read_test_case_file();
assert_stdout_contains('Lean test format detected', 'read_test_case_file : can detect lean test format');
assert_stdout_contains('Lean test steps parsed OK', 'read_test_case_file : lean style format parsed ok');
assert_stdout_contains("'repeat' => '1'", '_parse_lean_test_steps : defaults to repeat 1');
assert_stdout_contains("'10' =>", '_parse_lean_test_steps : Step 10 found');
assert_stdout_contains("'description1' => 'Test that WebInject can run a very basic test'", '_parse_lean_test_steps : Step 10, desc1 found');
assert_stdout_contains("'command' => 'REM Nothing: much'", '_parse_lean_test_steps : Step 10, command found');
assert_stdout_contains("'verifypositive1' => 'Nothing: much'", '_parse_lean_test_steps : Step 10, verifypositive1 found');
assert_stdout_contains("'20' =>", '_parse_lean_test_steps : Step 20 found');
assert_stdout_contains("'description1' => 'Another step - retry [{]RETRY}'", '_parse_lean_test_steps : Step 20, desc1 found');
assert_stdout_contains("'description2' => 'Sub description'", '_parse_lean_test_steps : Step 20, desc2 found');
assert_stdout_contains("'method' => 'cmd'", '_parse_lean_test_steps : Step 20, method found');
assert_stdout_contains("'command' => 'REM Not much more - retry [{]RETRY}'", '_parse_lean_test_steps : Step 20, command found');
assert_stdout_contains("'retry' => '3'", '_parse_lean_test_steps : Step 20, retry found');
assert_stdout_contains("'verifynegative' => 'Nothing much'", '_parse_lean_test_steps : Step 20, verifynegative found');
assert_stdout_contains("'verifypositive' => 'retry 1'", '_parse_lean_test_steps : Step 20, verifypositive found');

# can have a lean test case file with a single step
before_test();
$main::unit_test_steps = <<'EOB'
step: Single test step in file
shell: echo Short
EOB
    ;
read_test_case_file();
assert_stdout_contains("'10' =>", '_parse_lean_test_steps : Can have just one test step');

# can have quotes
before_test();
$main::unit_test_steps = <<'EOB'
step: Can handle 'single' and "double" quotes
shell: echo 'single' and "double" quotes
verifypostive: 'single' and "double" quotes
EOB
    ;
read_test_case_file();
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
read_test_case_file();
assert_stdout_contains("'10' =>", '_parse_lean_test_steps : step ids are auto generated - 10');
assert_stdout_contains("'20' =>", '_parse_lean_test_steps : step ids are auto generated - 20');

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
read_test_case_file();
assert_stdout_contains("'method' => 'cmd'", '_parse_lean_test_steps : shell method detected');
assert_stdout_contains("'command20' => 'echo auto2'", '_parse_lean_test_steps : shell converted back to command');

# method="selenium" is auto generated
before_test();
$main::unit_test_steps = <<'EOB'
step: Selenium method is detected
selenium: $driver->get("https://www.totaljobs.com")
selenium20: $driver->get_all_cookies()

step: Next step
selenium5: $driver->get('https://www.totaljobs.com/register')
EOB
    ;
read_test_case_file();
assert_stdout_contains("'method' => 'selenium'", '_parse_lean_test_steps : Selenium method detected');
assert_stdout_contains("'command20' => '.driver->get_all_cookies..'", '_parse_lean_test_steps : selenium converted back to command');

# method="get" is auto generated
before_test();
$main::unit_test_steps = <<'EOB'
step: Get method is detected
url: https://www.totaljobs.com
EOB
    ;
read_test_case_file();
assert_stdout_contains("'method' => 'get'", '_parse_lean_test_steps : get method detected');

# method="post" is auto generated
before_test();
$main::unit_test_steps = <<'EOB'
step: Get method is detected
url: https://www.totaljobs.com
postbody: RecipeName=Sheperds%20Pie&Cuisine=British
EOB
    ;
read_test_case_file();
assert_stdout_contains("'method' => 'post'", '_parse_lean_test_steps : post method detected');

# step: is description1:
before_test();
$main::unit_test_steps = <<'EOB'
step: Parameter rename
url: https://www.totaljobs.com
EOB
    ;
read_test_case_file();
assert_stdout_contains("'description1' => 'Parameter rename'", '_parse_lean_test_steps : step is really description1');

# single line comment is a hash
before_test();
$main::unit_test_steps = <<'EOB'
step: Single line comment
url: https://www.totaljobs.com
#verifypositive: positive
EOB
    ;
read_test_case_file();
assert_stdout_does_not_contain("'verifypositive'", '_parse_lean_test_steps : single line comment first char');
assert_stdout_does_not_contain("'' =>", '_parse_lean_test_steps : single line comment does not generate null parameter');

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
read_test_case_file();
assert_stdout_does_not_contain("'Not found'", '_parse_lean_test_steps : multi line comment');
assert_stdout_does_not_contain("'' =>", '_parse_lean_test_steps : multi line comment does not generate null parameter');

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
read_test_case_file();
assert_stdout_does_not_contain("'verifypositive' => 'positive'", '_parse_lean_test_steps : can have multi line comment in step');
assert_stdout_does_not_contain("'' =>", '_parse_lean_test_steps : multi line comment in step does not generate null parameter');
assert_stdout_contains("'verifynegative' => 'negative'", '_parse_lean_test_steps : can have multi line comment in step - parm after comment is active');

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
read_test_case_file();
assert_stdout_does_not_contain("'verifypositive' => 'positive'", '_parse_lean_test_steps : multi comment ignore in mixed comments');
assert_stdout_does_not_contain("'' =>", '_parse_lean_test_steps : multi line and single line comment does not generate null parameter');
assert_stdout_contains("'verifynegative' => 'negative'", '_parse_lean_test_steps : multi and single line comments mixed ok - 1');
assert_stdout_contains("'verifypositive' => 'sure'", '_parse_lean_test_steps : multi and single line comments mixed ok - 2');
assert_stdout_does_not_contain("'20' =>", '_parse_lean_test_steps : multi line and single line comment - should only be one step');

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
read_test_case_file();
assert_stdout_contains("'verifypositive1' => 'sure --= thing'", '_parse_lean_test_steps : not a multiline quote - 1');
assert_stdout_contains("'verifypositive2' => 'positive'", '_parse_lean_test_steps : not a multiline quote - 2');
assert_stdout_contains("'verifynegative1' => .negative  =--", '_parse_lean_test_steps : not a multiline quote - 3');

# quoted string - one line
before_test();
$main::unit_test_steps = <<'EOB'
step: One line quoted string
url: https://www.totaljobs.com
verifypositive:q:    q sure q   
EOB
    ;
read_test_case_file();
assert_stdout_contains("'verifypositive' => ' sure '", '_parse_lean_test_steps : single line quote - single char');

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
EOB
    ;
read_test_case_file();
assert_stdout_contains("'verifypositive1' => ' sure '", '_parse_lean_test_steps : single line quote - single char $');
assert_stdout_contains("'verifypositive2' => ' sure '", '_parse_lean_test_steps : single line quote - single char ^');
assert_stdout_contains("'verifypositive3' => ' sure '", '_parse_lean_test_steps : single line quote - single char .');
assert_stdout_contains("'verifypositive4' => ' sure '", '_parse_lean_test_steps : single line quote - single char *');
assert_stdout_contains("'verifypositive5' => ' sure '", '_parse_lean_test_steps : single line quote - single char +');
assert_stdout_contains("'verifypositive6' => ' sure '", '_parse_lean_test_steps : single line quote - single char ?');
assert_stdout_contains("'verifypositive7' => ' sure '", '_parse_lean_test_steps : single line quote - single char \\');
assert_stdout_contains("'verifypositive8' => ' sure '", '_parse_lean_test_steps : single line quote - single char |');
assert_stdout_contains("'verifypositive9' => ' sure '", '_parse_lean_test_steps : single line quote - single char -');
assert_stdout_contains("'verifypositiveA' => ' sure '", '_parse_lean_test_steps : single line quote - single char /');
assert_stdout_contains("'verifypositiveB' => ' sure '", '_parse_lean_test_steps : single line quote - single char #');
assert_stdout_contains("'verifypositiveC' => ' sure '", '_parse_lean_test_steps : single line quote - single char @');
assert_stdout_contains("'verifypositiveD' => ' sure '", '_parse_lean_test_steps : single line quote - single char &');
assert_stdout_contains("'verifypositiveE' => ' sure '", '_parse_lean_test_steps : single line quote - single char =');
assert_stdout_contains("'verifypositiveF' => ' sure '", '_parse_lean_test_steps : single line quote - single char "');
assert_stdout_contains("'verifypositiveG' => ' sure '", "_parse_lean_test_steps : single line quote - single char '");
assert_stdout_contains("'verifypositiveH' => ' sure '", '_parse_lean_test_steps : single line quote - single char `');

# quoted string - empty string quote
before_test();
$main::unit_test_steps = <<'EOB'
step: Empty string quote
url: https://www.totaljobs.com
verifypositive1:_: __
EOB
    ;
read_test_case_file();
assert_stdout_contains("'verifypositive1' => ''", '_parse_lean_test_steps : empty string quote - single char :');

# quoted string - quote char is colon
before_test();
$main::unit_test_steps = <<'EOB'
step: Empty string quote
url: https://www.totaljobs.com
verifypositive1::: :hey:
EOB
    ;
read_test_case_file();
assert_stdout_contains("'verifypositive1' => 'hey'", '_parse_lean_test_steps : quote character is colon :');

# unquoted string - preceeding and trailing spaces ignored
before_test();
$main::unit_test_steps = <<'EOB'
step: Empty string quote
url: https://www.totaljobs.com
verifypositive1:   hello   
verifypositive2: world
EOB
    ;
read_test_case_file();
assert_stdout_contains("'verifypositive1' => 'hello'", '_parse_lean_test_steps : before and after spaces ignored for unquoted string - 1');
assert_stdout_contains("'verifypositive2' => 'world'", '_parse_lean_test_steps : before and after spaces ignored for unquoted string - 2');

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
read_test_case_file();
assert_stdout_contains("'verifypositive1' => ' hello '", '_parse_lean_test_steps : multi char single line quotes - 1');
assert_stdout_contains("'verifypositive2' => ' hello '", '_parse_lean_test_steps : multi char single line quotes - 2');
assert_stdout_contains("'verifypositive3' => ' hello '", '_parse_lean_test_steps : multi char single line quotes - 3');

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
read_test_case_file();
assert_stdout_contains("'verifypositive1' => ' hello '", '_parse_lean_test_steps : mirror char for quotes - ()');
assert_stdout_contains("'verifypositive2' => ' hello '", '_parse_lean_test_steps : mirror char for quotes - {{}}');
assert_stdout_contains("'verifypositive3' => ' hello '", '_parse_lean_test_steps : mirror char for quotes [<]>');

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
read_test_case_file();
assert_stdout_contains("'verifypositive1' => 'first'", '_parse_lean_test_steps : multi line value - 1');
assert_stdout_contains("'postbody' => ' first line ", '_parse_lean_test_steps : multi line value - 2');
assert_stdout_contains("'postbody' => [^|]+second line", '_parse_lean_test_steps : multi line value - 3');
assert_stdout_contains("'postbody' => [^|]+third line'", '_parse_lean_test_steps : multi line value - 4');
assert_stdout_does_not_contain("LOGIC ERROR", '_parse_lean_test_steps : multi line value - 5');

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
read_test_case_file();
assert_stdout_contains("'verifypositive1' => 'first'", '_parse_lean_test_steps : multi line min value - 1');
assert_stdout_does_not_contain("LOGIC ERROR", '_parse_lean_test_steps : multi line min value - 2');
assert_stdout_contains("'postbody' => ' first line ", '_parse_lean_test_steps : multi line min value - 3');
assert_stdout_contains("'postbody' => [^|]+second line'", '_parse_lean_test_steps : multi line min value - 4');

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
read_test_case_file();
assert_stdout_contains("'description1' => 'Multi 10'", '_parse_lean_test_steps : multi scenarios - 1');
assert_stdout_contains("'url' => 'https://www.totaljobs.com'", '_parse_lean_test_steps : multi scenarios - 2');
assert_stdout_contains("'postbody' => ' first line ", '_parse_lean_test_steps : multi scenarios - 3');
assert_stdout_contains("second line'", '_parse_lean_test_steps : multi scenarios - 4');
assert_stdout_does_not_contain("'30' =>", '_parse_lean_test_steps : multi scenarios - 5');
assert_stdout_does_not_contain("LOGIC ERROR", '_parse_lean_test_steps : multi scenarios - 6');
assert_stdout_does_not_contain("'ignore' => 'this'", '_parse_lean_test_steps : multi scenarios - 7');
assert_stdout_contains("'description1' => 'Multi 20'", '_parse_lean_test_steps : multi scenarios - 8');
assert_stdout_contains("'url' => 'https://www.cwjobs.co.uk'", '_parse_lean_test_steps : multi scenarios - 9');
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
read_test_case_file();
assert_stdout_contains("'url' => 'https://www.totaljobs.com'", '_parse_lean_test_steps : blank lines between steps - 1');
assert_stdout_contains("'description1' => 'Multiple blank lines between steps'", '_parse_lean_test_steps : blank lines between steps - 2');
assert_stdout_contains("'url' => 'https://www.cwjobs.co.uk'", '_parse_lean_test_steps : blank lines between steps - 3');
assert_stdout_contains("'description1' => 'Step 2'", '_parse_lean_test_steps : blank lines between steps - 4');
assert_stdout_does_not_contain("'30' =>", '_parse_lean_test_steps : blank lines between steps - 5');

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
#read_test_case_file();
#assert_stdout_contains("'verifynegative' => 'bad stuff'", '_parse_lean_test_steps : single line comment in quote - 1');
#assert_stdout_does_not_contain("'20' =>", '_parse_lean_test_steps : single line comment in quote - 2');
#assert_stdout_contains("'verifypositive' => '", '_parse_lean_test_steps : single line comment in quote - 3');
#assert_stdout_does_not_contain("'assert_count' =>", '_parse_lean_test_steps : single line comment in quote - 4');

# multiline strings
    # comment within quote - will it be stripped out?
# special characters utf-8: <> `¬|\/;:'@#~[]{}£$%^&*()_+-=?€
# have to deal with include files
# repeat

# error checking before substitutions
# validate that there are not duplicate attributes
# validate that parameter name starts on first char of line
# validate that parm name ends with ': ' colon space
# validate that block starts with step:
# validate that method is not allowed parm
# validate that id is not allowed parm
# validate that command is not allowed parm (must be selenium or shell)
# validate that posttype is not allowed parm (if possible)
# validate that description1: is not allowed parm
# validate that spaces only for unquoted is an error
# validate that multiline quote starts on parameter line
# validate that multiline comment does not count as lines - so can be within step
# line number of error must be output (presence of comments does not change line number)
# step description must be output also

# optimise main parser loop code

#issues:
# what to do for include step id - make that up too .01 .02
# regex optimisations - possessive ++

#ideas:
# perhaps the id can be the line number of step: ?


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

sub assert_stdout_does_not_contain {
    my ($_must_not_contain, $_test_description) = @_;
    if ($main::results_stdout =~ m/$_must_not_contain/s) {
        isnt($main::results_stdout, $main::results_stdout, $_test_description);
        print '# not expected: '.$_must_not_contain."\n";
    } else {
        is(1, 1, $_test_description);
    }
}

sub clear_stdout {
    $main::results_stdout = '';
}

sub before_test {
    $main::EXTRA_VERBOSE = 1;

    $main::case{url} = 'http://example.com/jobs/search.cgi?query=Test%Automation&Location=London';
    $main::results_stdout = '';
    $main::response = '';

    undef @main::cached_pages;
    undef @main::cached_page_actions;
    undef @main::cached_page_update_times;
    
    return;
}

#
# SUPPRESS WARNINGS FOR VARIABLES USED ONLY ONCE
#

$main::response = '';
$main::EXTRA_VERBOSE = 0;
$main::results_stdout = '';
$main::unit_test_steps = '';
undef @main::cached_pages;
undef @main::cached_page_actions;
undef @main::cached_page_update_times;
