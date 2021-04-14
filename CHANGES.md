# WebImblaze change log

This project is a fork of WebInject version 1.41, http://webinject.org/.

Version 1.42 onwards - https://github.com/Qarj/WebImblaze

---

## WebImblaze Release History:

### Version 1.4.6 - Apr 14, 2021

-   very minor change - user defined variables from the config file are now substituted before processing the DATE::: substitution modifier

### Version 1.4.5 - Feb 16, 2021

-   added parsematch parameter for returning the nth match of a regex

### Version 1.4.4 - Feb 3, 2021

-   now possible to show dynamic details in custom verifynegative assertion message

### Version 1.4.3 - Jan 5, 2021

-   fix for Linux file path handling when writing grabbed assets

### Version 1.4.2 - Jan 5, 2021

-   handle backslash in path for grabbing assets

### Version 1.4.1 - Jan 5, 2021

-   added an assertnear assertion for non exact value comparison

### Version 1.4.0 - Oct 10, 2020

-   changed the auto assertions to negative assertions and provided a way to capture info (e.g. error references) and display in reporting

### Version 1.3.9 - Sep 29, 2020

-   attempts to identify REACT apps, will now render test result html rather than displaying literal html (useful for SSR)

### Version 1.3.8 - May 30, 2020

-   added {APP_DATA} substitution
-   added {SHELL_QUOTE} substitution
-   added decodebase64 paramater
-   bugfix - don't print directly to STDOUT if runif `paramater` used
-   documented previously undocumented `shell` paramaters substitions {SHELL_ESCAPE}, {SHELL_QUOTE} and {SLASH}

### Version 1.3.7 - Mar 24, 2020

-   added {SYS_TEMP} substitution

### Version 1.3.6 - Mar 10, 2020

-   added removecookie parameter

### Version 1.3.5 - Mar 4, 2020

-   bugfix - do not get html source assets for Selenium tests

### Version 1.3.4 - Mar 2, 2020

-   grabbing href= and src= assets for css, gifs, pngs, JavaScript etc is less buggy and works with single or double quotes

### Version 1.3.3 - Jan 31, 2020

-   file name of include file is now given if it fails to parse instead of the master file name

### Version 1.3.2 - Jan 30, 2020

-   fixed infinite loop when a multi-line comment is not closed
-   reviewed, improved and sped up self tests

### Version 1.3.1 - Nov 11, 2019

-   assertion failure custom messages are now displayed on STDOUT in yellow

### Version 1.3.0 - Sep 18, 2019

-   new `redact` parameter can remove sensitive information like passwords and API keys from the results

### Version 1.2.3 - Sep 13, 2019

-   dependency on Math::Random::ISAAC is overkill so has been removed in favour of Perl standard rand() function

### Version 1.2.2 - Aug 21, 2019

-   `logresponseasfile` output folder is no longer hard coded to the {PUBLISH} location

### Version 1.2.1 - Aug 6, 2019

-   File::Slurp package is no longer required

### Version 1.2.0 - July 31, 2019

-   added DATE_GMT_NOW substitution modifier since it is not affected by daylight saving

### Version 1.1.1 - June 10, 2019

-   recoded the http auth for basic and NTLM authentication, added verbose output

### Version 1.1.0 - May 24, 2019

-   UTF-8 is now the default and Unicode is well supported (though on Windows the console output is garbled)
-   gzip content is now decoded
-   corrected the Nagios exit code for 'UNKNOWN'
-   if a test step is aborted, when using Nagios reporttype WebImblaze will exit with code 'UNKNOWN'

### Version 1.0.1 - Nov 10, 2018

-   fixed substitution modifier regression

### Version 1.0.0 - Oct 31, 2018

-   initial release of WebImblaze
-   addcookie parameter removed (use setcookie instead)
-   removed parsing of .xml test case files (use .test instead)
-   renamed description1 to step, renamed description2 to desc
-   updated manual to reflect .test file format
-   removed parms parameter
-   if posttype is test/xml or application/soap+xml, uploaded file will have standard substitutions applied
-   removed retryfromstep parameter (use checkpoint instead)

---

## WebInject Release History:

### Version 2.11.0 - Aug 10, 2018

-   stabilised the simplified .test format including fixes for Linux
-   fix compilation error under CentOS 7 - Perl 5.16.3
-   abort will now continue execution from the specified step name e.g. Teardown when triggered
-   section breaks increment auto test step numbering system to nearest 100
-   can now specify a useragent in a .test file as a separate directive applying to all steps
-   failure to specify either a url, shell or selenium parameter will result in an action less step
-   additional substitution modifier DATE_NOW modifies the data from the current time (instead of test start time)

### Version 2.10.0 - Jun 22, 2018

-   support a simplified test format in addition to xml, once it is production proven the xml format will be deprecated and later removed
-   support Perl 5.26 (@INC no longer includes '.' by default)
-   refactored auto substitutions, added unit tests for them and fixed some bugs
-   hints and tips section added to the manual
-   minor code tidy ups
-   support ANSI colour for STDOUT
-   fixed Ubuntu 18.04 LTS SSL compatibility issue

### Version 2.9.0 - Mar 3, 2018

-   new dumpjson parameter for decoding emails sent to test email management systems like mailhog and inbucket
-   improved getallhrefs and getallsrcs feature - see manual
-   html actual result now written as UTF-8
-   auto substitutions feature has existed for a long time, now documented in the manual
-   fixed edge cases for var assignment in conjunction with retry and repeat
-   ampersands will now be correctly encoded in the xml results rather than changed to the literal {AMPERSAND}
-   logic has been adjusted for decision to run or skip test step - now done after all variable substitutions
-   examples now point to webinject-check website

### Version 2.8.0 - Nov 25, 2017

-   renamed the sanitycheck parameter to abort, and changed the way that it works, including a bug fix
-   command line options for WebInject-Selenium plugin are now shown by the plugin, for a cleaner display if plugin is not installed
-   removed logic that only loaded the WebInject-Selenium plugin if Selenium tests are detected - simplifies logic for only a slight start-up time hit
-   added a selftest for SSL, updated installation instructions for Linux to ensure LWP::Protocol::https is installed
-   updated instructions for use of perlbrew with a Mac, and fixed a bug so the self tests can run on a Mac
-   added an advanced assertion examples section to the manual
-   now support so called substitution modifiers to alter the date (which is NOW by default)
-   setcookie now supports the colon character in a cookie
-   removed 8192 character line limit size in headers

### Version 2.7.0 - Aug 11, 2017

-   included the Python 3 project search-image.py (finds a sub image within a screenshot)
-   many of the WebInject self tests now refer to webinject-check.azurewebsites.net
-   experimental checkpoint parameter added, if successful it will replace retryfromstep
-   unconditional SLEEPs are bad and ignored by WebInject - now however WebInject will output to STDOUT and html when a sleep is invoked
-   support masked strings (for config files)
-   runif parameter added to only run a step if the parameter evaluates to truthy
-   added setcookie feature and deprecated addcookie, setcookie will permanently set a cookie for the rest of the session
-   added writesharedvar and readsharedvar for advanced use, see manual
-   replaced gethrefs and getsrcs with getallhrefs and getallsrcs - the new parameters have a scope of all subsequent steps
-   removed some redundant code and standardised the config code
-   the Results.xsl is now domain relative
-   added an eval parameter to evaluate simple expressions
-   added {EPOCHSECONDS} and {EPOCHSPLIT} to give more fine grained control as compared to {TIMESTAMP}
-   $start_timer and $end_timer do not need to be global variables
-   Selenium Grid is now supported (when using the WebInjectSelenium.pm plugin - separate project)

### Version 2.6.0 - Mar 24, 2017

-   auto retry feature introduced with autoretry and ignoreautoretry parameters

### Version 2.5.0 - Mar 6, 2017

-   to reduce confusion, the Selenium component of WebInject has been moved into its own project WebInject-Selenium and is now an optional plugin to WebInject
-   random parameter has been changed so it will never generate a 0 as the first character
-   fixed an issue with simple http auth
-   added a new decode parameter - decodesmtp - this will decoded double dot encoded text

### Version 2.4.3 - Feb 27, 2017

-   fix an issue with helper_wait_visible and helper_wait_not_visible finding elements that do not exist

### Version 2.4.2 - Dec 22, 2016

-   major tidy up of "Locators for Testers" and tweaks to heuristics
-   removed many helper functions no longer required

### Version 2.4.1 - Nov 22, 2016

-   optimised the "Locators for Testers" so they use a generic framework rather than copy and pasted code with slight variations
-   helper_send_keys_to_element[_after/_before] now uses Selenium to send the keys rather than setting value directly via JavaScript

### Version 2.4.0 - Nov 20, 2016

-   set of helpers I think of as "Locators for Testers" - heuristics find target element without needing to view source or inspect element
-   these "Locators for Testers" are helper_keys_to_element, helper_keys_to_element_after, helper_click, helper_click_before, helper_click_after
-   additional helpers to easily get current state: helper_get_attribute, helper_get_element_value, helper_get_selection, helper_is_checked
-   put a framework in place for WebInject Selenium self tests

### Version 2.3.1 - Nov 7, 2016

-   helper_keys_to_element_after now will ignore elements with type == 'hidden'

### Version 2.3.0 - Nov 4, 2016

-   httpauth delimiter can now be any character you want - the first character of the httpauth string specifies the delimiter

### Version 2.2.1 - Nov 2, 2016

-   new helper function helper_keys_to_input_after renamed to helper_keys_to_element_after and made compatible with Salesforce
-   helper_keys_to_element_after can now set SELECT i.e. drop down values
-   helper_keys_to_element_after can now check and uncheck check boxes

### Version 2.2.0 - Nov 1, 2016

-   new helper function helper_keys_to_input_after which searches the page for some text and sets the next input field to a desired value

### Version 2.1.0 - Nov 1, 2016

-   new fail fast! feature for assertions, i.e. if assertion fails, do not retry
-   removed retryresponsecode feature - no longer relevant due to fail fast! feature
-   display on STDOUT which verifypositive or verifynegative failed
-   --verbose option will make WebInject show the request and response on STDOUT
-   --basefolder option removed (was used for image comparison which is now implemented differently)
-   --no-output option will now also not create files in the output folder (in addition to no STDOUT) unless the tests specifically create files, or Selenium is used
-   WebInject aborts in a handled way (i.e. with error messaging) when there are connectivity issues with Selenium Server
-   maxredirect parameter added for GET requests
-   fixed a bug with useragent parameter (did not work on first test step)
-   Selenium Server is now started by WebInject using --selenium-binary option (which means WebInject can restart the Selenium Server if it needs a kick)
-   --binary option changed to --chromedriver-binary
-   variables set in the user_defined section of the config file can now refer to variables themselves e.g. {:8080}
-   ignorehttpresponsecode parameter is no longer counted as a passed verification
-   a message is logged to STDOUT when ignorehttpresponsecode is used

### Version 2.0.0 - Aug 7, 2016

-   created a self test for Selenium functionality - works on both Windows and Linux
-   removed Firefox and PhantomJS support
-   removed support for fast screenshot (ChromeDriver inbuilt screenshot is fast)
-   optimised Selenium helper functions
-   renamed local and global variables + subroutine names according to a different naming standard
-   removed reference to Crypt::SSLeay library - no longer needed for SSL
-   ensured call to search-image.py can work on Linux as well as Windows
-   change to semantic version numbering

### Version 1.99 - Jul 19, 2016

-   added back --no-output command line option
-   added back Nagios plugin mode support

### Version 1.98 - Jul 18, 2016

-   removed xnode feature for running a single test step
-   fixed selftest compatibility for Perl 5.24.0
-   log separator now written after a test step, not before (as per original functionality)
-   WebInject now determines whether to try and render a test result based on whether it contains <html and <body tags
-   output of shell command tests were sometimes being treated as http headers, fixed
-   reduced start-up time for tests that do not invoke a http session - makes the self tests much quicker

### Version 1.97 - Jul 3, 2016

-   made core WebInject compatible with Linux (Selenium support still be to addressed)
-   renamed http.log to http.txt - http.txt can be served by web servers without adding a mime type
-   added environments donotrunon feature
-   set exit code of 1 if one or more test steps failed
-   fixed seeding of random numbers
-   made log separator much larger
-   made it easier to debug test files that fail parsing + better messaging
-   file handles are now opened and closed for every test step

### Version 1.96 - Jun 12, 2016

-   replaced liveonly and testonly parameters with all-purpose runon
-   bug fix - searchimage filename should show in results xsl if not found

### Version 1.95 - May 30, 2016

-   {RANDOM:10} was meant to produce 10 random alphanumeric characters but did not do anything - fixed
-   in certain circumstances `<`, `>` and `&` was being written within results.xml tags - now substituted with {LESSTHAN}, {GREATERTHAN} and {AMPERSAND} respectively
-   there is now no need to escape `<` when used in test case attributes
-   stopped Response.pm croaking webinject.pl when the request url is empty
-   renamed image_in_image.py to search-image.py (and separated it to its own project on GitHub)

### Version 1.94 - May 21, 2016

-   added a feature to make it easy to reuse common test steps - e.g. login, register an account

### Version 1.93 - May 16, 2016

-   removed checkpositive, checknegative and checkresponsecode feature - hard to understand and not compatible with verifyresponseTEXT

### Version 1.92 - May 11, 2016

-   link to Selenium page grabs in the step results
-   link to email files in the step results
-   parseresponse before writing log files
-   resources from gethrefs and getcss and getbackgroundimages are now substituted into the step results
-   auto substitution logic improvement
-   can now specify ports in format {:4040} - the port will be removed entirely if desired, or converted to :4040

### Version 1.91 - Apr 23, 2016

-   improved date time format for start_time in results.xml
-   restructured results.xml format for verifypositive, verifynegative, autoassertions, smartassertions and searchimage
-   create a html file for every single test step e.g. 10.html, 20.html

### Version 1.90 - Apr 5, 2016

-   now can generate random strings and numbers {RANDOM:5:NUMERIC} {RANDDOM:10:ALPHANUMERIC} {RANDOM:6:ALPHA}

### Version 1.89 - Apr 4, 2016

-   escape modifier on parseresponse changed to use a uri escape regex

### Version 1.88 - Mar 31, 2016

-   support quotemeta in addition to escape and decode as a parseresponse result modifier (see manual)

### Version 1.87 - Mar 30, 2016

-   absolute output folder path supported (in addition to relative)
-   can now start a Chrome browser without a proxy
-   PUT and DELETE http REST verbs supported

### Version 1.86 - Mar 20, 2016

-   can now specify location of chromedriver.exe instead of a selenium server port
-   chromedriver log file will be written to the output folder (--verbose)
-   improved logic for overwriting pages in the cache
-   refactored sub selenium to make it a lot easier to understand
-   absolute path is now supported for config file and test case file
-   fixed introduced bug - processcasefile needs to be called after startsession so the agent can be set

### Version 1.85 - Mar 5, 2016

-   refactored and improved the auto substitution feature to work in more edge case scenarios

### Version 1.84 - Feb 28, 2016

-   improved the auto substitution feature - should work in a wider range of scenarios - tested with .NET WebForms and MVC

### Version 1.83 - Feb 27, 2016

-   messaging around assertion skips was buggy, now fixed and an appropriate selftest added
-   some code tidy up

### Version 1.82 - Feb 23, 2016

-   removed a feature - specifying multiple test case files to process in the config (classic example of overengineering)
-   more code tidy up

### Version 1.81 - Feb 14, 2016

-   substantial code tidy up
-   recently introduced bug resolved with {TESTFILENAME}

### Version 1.80 - Feb 13, 2016

-   more code tidy up - addressed almost all sev 4 issues

### Version 1.79 - Feb 12, 2016

-   code tidy up - resolved more than 40 sev 4 perl critic issues

### Version 1.78 - Feb 11, 2016

-   made whackoldfiles safer for running WebInject in parallel

### Version 1.77 - Feb 10, 2016

-   reverted eval methods, made whackoldfiles work properly

### Version 1.76 - Feb 9, 2016

-   removed all use of barewords as file handles, changed eval methods

### Version 1.75 - Feb 8, 2016

-   moved the execution of decodequotedprintable to before the assertions
-   changed to 3 argument open, changed many of the opens away from bareword file handles

### Version 1.74 - Feb 6, 2016

-   made loop iterators lexical

### Version 1.73 - Feb 2, 2016

-   changed select statements used as sleep statements to actual sleep statements

### Version 1.72 - Feb 1, 2016

-   fixed the assertionskipsmessage reporting - was missed from many of the different assertion types

### Version 1.71 - Feb 1, 2016

-   changed custom_wait_for_text_visible so that you can supply a locator

### Version 1.70 - Jan 31, 2016

-   removed XML::Parser, no longer needed

### Version 1.69 - Jan 30, 2016

-   made the auto substitutions compatible with .NET MVC as well as .NET Web Forms

### Version 1.68 - Jan 30, 2016

-   verification and screenshot time for Selenium WebDriver tests now output to STDOUT, results.html and results.xml

### Version 1.67 - Jan 27, 2016

-   fixed a bug in sub getassets when an output folder includes a filename prefix

### Version 1.66 - Jan 26, 2016

-   removed (not in error range) text from Response Code Verification to make the output cleaner

### Version 1.65 - Jan 24, 2016

-   support changing the user agent at the test case level

### Version 1.64 - Jan 24, 2016

-   bug fix - httppost_xml was changing the response format even when not requested via formatxml
-   added info about running WebInject in parallel

### Version 1.63 - Jan 24, 2016

-   new variable creation feature that can be used in the same test step e.g. varTIME="{HH}{MM}{SS}" used as desc="{TIME}"

### Version 1.62 - Jan 24, 2016

-   put binmode on logresponseasfile
-   improved usage info when using webinject.pl --help

### Version 1.61 - Jan 24, 2016

-   fixed a bug where response time was bleeding over from previous test step when checkpositive, checknegative or checkresponsecode invoked

### Version 1.60 - Jan 23, 2016

-   reverted baseurl support to only baseurl, baseurl1 and baseurl2 the same as WebInject 1.41 (baseurl is superseded by userdefined config)

### Version 1.59 - Jan 23, 2016

-   removed globalhttplog config feature - we will always log to http.log

### Version 1.58 - Jan 23, 2016

-   removed logrequest and logresponse parameters - we will always log the requests and the responses

### Version 1.57 - Jan 23, 2016

-   removed anything to do with gui or $returnmessage - not supported

### Version 1.56 - Jan 23, 2016

-   removed anything to do with plotting - not supported

### Version 1.55 - Jan 23, 2016

-   removed all references to nooutput - not properly supported or needed, made code simpler

### Version 1.54 - Jan 23, 2016

-   removed all references to reporttype, this branch of WebInject is for functional testing, so the code is now cleaner

### Version 1.53 - Jan 21, 2016

-   removed assertionskipsmessage parameter - it is redundant, use the skip feature on the assertions instead

### Version 1.52 - Jan 20, 2016

-   removed deprecated global1 to global5 - replaced by userdefined config

### Version 1.51 - Jan 19, 2016

-   removed unused feature in sub httppost_xml that checks if xml response is well-formed
-   Error package no longer needs to be downloaded from CPAN for Strawberry Perl

### Version 1.50 - Jan 18, 2016

-   added parameter decodequotedprintable which decodes a quoted-printable response and replaces it with the decoded version

### Version 1.49 - Jan 13, 2016

-   refactored the assertion skips functionality and summary info is now included in results.xml

### Version 1.48 - Jan 12, 2016

-   added {OPT_PROXY} and renamed {PROXYRULES} to {OPT_PROXYRULES}
-   removed erroneous firstlooponly lastlooponly from config for loop
-   tweak to custom_wait_for_text_visible - increased wait checks from 0.1 to 0.5 seconds

### Version 1.47 - Jan 12, 2016

-   added smartassertions feature along with ignoresmartassertions parameter

### Version 1.46 - Jan 11, 2016

-   refactored gethrefs and getsrcs, added getbackgroundimages

### Version 1.45 - Jan 10, 2016

-   Fixed a bug logresponseasfile when used with output folder filename prefix

### Version 1.44 - Jan 9, 2016

-   Fixed a bug with the sleep conditions for retryfromstep

### Version 1.43 - Jan 9, 2016

-   Now support any number of assertcount - e.g. assertcount5000, assertcountDISTANCE

### Version 1.42 - Nov 28, 2015

-   Include additional info about which test case is being run - just after the log file separator
-   Added retry parameter to cater for data replication latency
-   Created a globalretry setting in the config to set a maximum number of retries for a test run
-   Added sanitycheck parameter - all test execution will cease if there has been any error before the check
-   Added testonly parameter - flags that a test case should only be run against test environments
-   Added liveonly parameter
-   Added {STARTTIME} as a substitution value - time stamp of when test execution began
-   Support running of operating system commands through the backtick method
-   Changed the way escape works - to fix an issue with escaping \_\_VIEWSTATE
-   Changed the way addheader works so it takes priority over maintaining cookies
-   Added "application/json" to the error message that is output if you've carried out a POST using an invalid Content Type
-   Added logastext parameter - writes html and xmp tags around the response in the http log
-   Made a tweak to enable NTLM::Authen to work
-   Made it possible to specify a custom regex in the parseresponse
-   Added autocontroller only parameter - test case will only be run if the host is an automation controller (as opposed to a developer desktop)
-   Added the ability to specify a custom message when a specific verifypositive or verifynegative fails
-   Added the ability to decode HTML Entities for parseresponse (use in place of escape)
-   Changed {TEMP} to {OUTPUT}
-   Added {HH}, {MM} and {SS} substitutions
-   Added {COUNTER} substitution - shows current loop number
-   Support Selenium Server 2.0
-   Added parameters checkpositive, checknegative, checkresponsecode - allows specific test cases to be skipped in error scenarios
-   When WebInject loops, 10000 is now added to the test case numbers
-   Added {TESTNUM} substitution
-   Added {OUTSUM} substitution - simple hash of the output folder - was added to increase uniqueness of data when running in parallel
-   Added section parameter - for specifying a section break in the results
-   Added assertcount parameter - asserts that you find a particular regex exactly the specified number of times
-   Added onceonly parameter - when WebInject loops, onceonly test cases will be ignored
-   Added firstlooponly and lastlooponly parameters - test cases will only be run on the first or last loop (for setup and teardown)
-   Added {DATA} substitution - will automatically pull data values from the previous test step result with the same host and path, e.g. the \_\_VIEWSTATE value
-   Added {NAME} substitution - allows simple wildcard for http post field names
-   Added searchimage parameter - finds one image inside of another - requires Python 2.6 and a few other bits to work
-   Added formatxml parameter - does very simplistic formatting of XML response, i.e. adds a few carriage returns here and there so the entire response is not on one line
-   Added formatjson parameter - very simplistic formatting of JSON response
-   Find the Windows browser window handle of the Selenium session to enable a very fast screenshot (much faster than Selenium), needed for running many Selenium tests in parallel
-   Added {CONCURRENCY} substitution - the value is the output folder name only, not full path
-   Added {HOSTNAME} substitution
-   Explicitly state not to verify SSL certificates, required for newer versions of LWP SSL
-   Added a substitution for the test step run time, e.g. {TESTSTEPTIME:510} will substitute in the execution time of test step 510
-   Added {DATETIME} and {FORMATDATETIME} substitutions
-   Added addcookie parameter which will add a single cookie (as opposed to addheader which overwrites all existing cookies)
-   The http log separator is now written out before each test case, in addition, a final log separator is written at the end of the test run
-   Added {RETRY} substitution - shows the current retry attempt number
-   Added retryfromstep parameter - will retry from the specified test case number
-   Added {JUMPBACKS} substitution - the number of times retryfromstep has been invoked
-   Added globaljumpbacks config value - i.e. maximum number of jump backs allowed in a test run
-   Added restartbrowseronfail parameter - will restart the Selenium session and WebInject session if the test case failed
-   Added restartbrowser parameter
-   Added commandonerror parameter - will run an operating system command if the test case failed e.g. to clean things up
-   Added support for automatic assertions to be run against every single test case - the auto assertions are specified in the config file
-   Added support for arbitrary user defined substitutions from the config file so you can specify things like {DOMAIN}, {TEAMNAME}, {WEBSITEURL} or whatever
-   Added {NOW} substitution - the current time, updated with every retry
-   Flush html results to disk immediately before making the web call for each test case
-   Added -i WebInject.pl start up option, all retry and retryfromstep will be ignored
-   Added a way of tagging production issues without having to comment out / remove the test case
-   Added support for as many parseresponses as you desire so you can now go parseresponseMYVARIABLE="..." and refer to it as {MYVARIABLE}
-   As a result of the parseresponse change, parseresponse with numbers will now be referred as {1}, {2}, {50} etc ..., use {} for null
-   Replaced all tabs with 4 spaces
-   Support any number of verifypositive and verifynegative
-   verifypositivenext, verifynegativenext parameters removed - not compatible with retry, also could not think of any scenario where this feature is necessary
-   Added gethrefs and getsrcs parameters - used saving off page assets that match a wildcard
-   Changed the way substitution works, so instead of having a simple for loop over known parameters, all test case attributes are included by way of a foreach
-   Added verifyresponsetime parameter
-   Added retryresponsecode parameter - retry if a particular http response code is found, e.g. 500
-   Added {ELAPSED_SECONDS} and {ELAPSED_MINUTES} substitutions (updated with every retry)
-   Added helper subroutines for Selenium WebDriver to do common tasks e.g. perform a click using JavaScript, the subroutines are
    -   custom_select_by_text
    -   custom_clear_and_send_keys
    -   custom_mouse_move_to_location
    -   custom_switch_to_window
    -   custom_js_click
    -   custom_js_set_value
    -   custom_js_make_field_visible_to_webdriver
    -   custom_check_element_within_pixels
    -   custom_wait_for_text_present
    -   custom_wait_for_text_not_present
    -   custom_wait_for_text_visible
    -   custom_wait_for_text_not_visible
    -   custom_wait_for_element_present
    -   custom_wait_for_element_visible

### Version 1.41 - Jan 4, 2006

-   Added ability to add multiple HTTP Headers within an 'addheader' testcase parameter
-   Added 'addheader' testcase parameter to GET requests (previously only supported POST)
-   Fixed GUI layout for high dpi displays
-   Bugfixes for 'verifyresponsecode' and 'errormessage' parameters

### Version 1.40 - Dec 6, 2005

-   Support for Web Services (SOAP/XML)
-   Added XML parser for parsing and verification of XML responses (web services)
-   Support for 'text/xml' and 'application/soap+xml' Content-Type (web services)
-   Added new 'addheader' testcase parameter so you can specify an additional HTTP Header field for requests
-   Support for setting variables/constants within test case files
-   Added ability to call generic external Perl plugins for easier integration and post-processing
-   More detail added to XML output
-   Code refactoring

### Version 1.35 - April 4, 2005

-   New command line option (-o) to specify location for writing output files (http.log, results.html, and results.xml)
-   Nagios plugin performance data support
-   Allows multiple 'httpauth' elements in config files to support multiple sets of HTTP Authentication credentials
-   New 'verifyresponsecode' test case parameter for HTTP Response Code verification
-   Additional 'baseurl' elements supported in the config file
-   Additional verification parameters supported in test cases
-   Added -V command line option (same as -v) to print version info (necessary for it to run with Moodss)
-   Code refactoring

### Version 1.34 - Feb 10, 2005

-   MRTG External Monitoring Script (Plugin) compatibility
-   Bugfix for using comment tags in config files
-   Suppress logging when running in plugin mode
-   Changed default standalone plot mode to OFF

### Version 1.33 - Jan 26, 2005

-   Nagios Plugin compatibility
-   Support for multipart/form-data encoded POSTs (file uploads)
-   Updated results.html output so it is valid XHTML

### Version 1.32 - Jan 14, 2005

-   Bugfix for erroneous dummy test case printing in GUI status
-   Bugfix for warning that appeared when running GUI with Perl in -w mode

### Version 1.31 - Jan 11, 2005

-   Bugfix for errors and broken status bar in GUI

### Version 1.30 - Jan 07, 2005

-   HTTP Basic Authentication support
-   No longer forced to have test cases in strict incremental numbered order
-   Source code compiles with the "use strict" pragma
-   Ability to run engine from a different directory using alternate test case and config files
-   Comments allowed in config file using <comment></comment> tags
-   Other config.xml options are still used when you pass a test case filename as a command line argument
-   New config option to change response delay timeout <timeout></timeout>
-   New test case parameter to add a custom error message
-   Added separators to http.log for readability
-   Enhanced command line options/switches
-   Nagios Plugin compatibility (beta)
-   More verbose error handling when running from command line
-   Ability to handle reserved XML character "<" within test cases by escaping it with a backslash "<"
-   Changed output when using XPath notation from command line
-   Bugfix for proxy support
-   Bugfix for sending a parsed value in a POST body
-   Bugfix for erroneous errors when running from command line
-   Bugfix for warnings that appeared when running with Perl in -w mode
-   Code refactoring

### Version 1.20 - Sept 27, 2004

-   Real-time response time monitoring (stats display and integration with gnuplot for plot/graph)
-   Added tabbed layout to GUI with 'Status' and 'Monitor' windows
-   Added 'Stop' button to GUI to halt execution
-   New testcase parameter 'sleep', to throttle execution
-   Added timer summary to HTML report
-   Removed HTML tags from STDOUT display and cleaned up formatting
-   GUI enhancements
-   Code refactoring

### Version 1.12 - July 28, 2004

-   New test case file parameter 'repeat', to run a test case file multiple times
-   Added GUI options for Minimal Output and Response Timer Output
-   New config.xml parameter to define a custom User-Agent string to be sent in HTTP headers
-   Added XPath Node selection to optional command line parameters
-   Bugfix for GUI Restart button

### Version 1.10 - June 23, 2004

-   Added XML formatted output (results.xml is created each run)
-   New config.xml parameter for HTTP logging
-   More detailed pass/fail status to HTML report
-   Redefined criteria for test case pass/pail
-   Results summary and additional formatting to STDOUT (for standalone mode)
-   Minor code refactoring

### Version 0.95 - May 17, 2004

-   Added Restart button to GUI
-   Added 5 additional parsing parameters/variables to use in test cases
-   Fixes to GUI positioning

### Version 0.94 - April 29, 2004

-   Bugfix for malformed HTTP Post
-   Added colors to status window text

### Version 0.93 - March 22, 2004

-   Dynamic response parsing support cookieless session handling
-   Added version number to GUI window title bar

### Version 0.92 - March 05, 2004

-   Minor bug fixes
-   Added status light to GUI
-   New config.xml parameter for HTTP proxy support
-   New config.xml parameter for Baseurl constant

### Version 0.91 - Feb 23, 2004

-   Decoupled GUI (webinjectgui) from Test Engine (webinject) so engine can run standalone
-   Testcase name can be passed on command line as well as via config.xml
-   Code cleanup
-   Output sent to STDOUT as well as reports (for standalone mode)

### Version 0.90 - Feb 19, 2004

-   Initial public beta release
-   Contains SSL/TLS support
-   Perl/Tk GUI
-   Automatic cookie handling

---
