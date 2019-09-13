# Manual for WebImblaze version 1.2.3

## Overview

- [Architecture Diagram](#architecture-diagram)

- [Summary](#summary)

## Configuration

- [config.xml](#configxml)

    - [Proxy Server (proxy)](#proxy)

    - [User-Agent (useragent)](#useragent---config)

    - [HTTP Authentication (httpauth)](#httpauth)

    - [Base URL (baseurl, baseurl1, baseurl2)](#baseurl)

    - [Response Delay Timeout (timeout)](#timeout)

    - [Global Retry (globalretry)](#globalretry)

    - [Global Jumpbacks (globaljumpbacks)](#globaljumpbacks)

    - [Auto Retry (autoretry)](#autoretry---config)

    - [Ports Variable (ports_variable)](#ports_variable)

    - [Environment (environment)](#environment)

    - [Auto Controller Only (autocontrolleronly)](#autocontrolleronly)

    - [User Defined (userdefined)](#userdefined)

    - [Auto Assertions (autoassertions)](#autoassertions)

    - [Smart Assertions (smartassertions)](#smartassertions)

    - [Report Type (Nagios Plugin mode) (reporttype)](#reporttype)

    - [Global Timeout (Nagios Plugin mode) (globaltimeout)](#globaltimeout)

    - [WebImblaze Framework (webimblazeframework)](#wif)

    - [Selenium Binaries Location](#selenium-binary)

    - [Test Step Files (specifying in configuration file)](#teststepfile)

- [Command Line Options](#command-line-options)

    - [Command Line Options - full description](#command-line-options---full-description)

    - [Passing a Test Step Filename](#passing-a-test-step-filename)

    - [More Examples of Command Line Usage](#more-examples-of-command-line-usage)

## File level directives

- [include](#include)

- [repeat](#repeat)

- [useragent](#useragent---directive)

## Test Steps

- [Test Step Summary](#test-step-summary)

- [Minimal Example](#minimal-example)

- [Test step internal numbering](#test-step-internal-numbering)

## Step Parameters

- [Core Parameters](#core-parameters)

    - [step](#step)

    - [desc](#desc)

    - [url](#url)

    - [posttype](#posttype)

    - [postbody](#postbody)

    - [verifypositive](#verifypositive)

    - [verifynegative](#verifynegative)

    - [parseresponse](#parseresponse)

    - [var](#var)


- [Additional Test Driver Parameters](#additional-test-driver-parameters)

    - [shell shell1 ... shell20 readfile echo](#shell)

    - [commandonfail](#commandonfail)

    - [commandonerror](#commandonerror)

    - [addheader](#addheader)

    - [setcookie](#setcookie)

    - [useragent](#useragent---parameter)

    - [maxredirect](#maxredirect)

    - [method](#method)


- [Additional Assertion Parameters](#additional-assertion-parameters)

    - [assertcount](#assertcount)

    - [verifyresponsecode](#verifyresponsecode)

    - [verifyresponsetime](#verifyresponsetime)

    - [ignoreautoassertions](#ignoreautoassertions)

    - [ignoresmartassertions](#ignoresmartassertions)

    - [ignorehttpresponsecode](#ignorehttpresponsecode)


- [Retry Failed Test Step Parameters](#retry-failed-test-step-parameters)

    - [autoretry](#autoretry---parameter)

    - [checkpoint](#checkpoint)

    - [ignoreautoretry](#ignoreautoretry)

    - [retry](#retry)

    - [restartbrowseronfail](#restartbrowseronfail)

    - [restartbrowser](#restartbrowser)

    - [sleep](#sleep)


- [Test Response Output Control Parameters](#test-response-output-control-parameters)

    - [decodequotedprintable](#decodequotedprintable)

    - [decodesmtp](#decodesmtp)

    - [dumpjson](#dumpjson)

    - [errormessage](#errormessage)

    - [formatjson](#formatjson)

    - [formatxml](#formatxml)

    - [getallhrefs](#getallhrefs)

    - [getallsrcs](#getallsrcs)

    - [getbackgroundimages](#getbackgroundimages)

    - [logastext](#logastext)

    - [logresponseasfile](#logresponseasfile)

    - [section](#section)


- [Parameters to conditionally skip test steps](#parameters-to-conditionally-skip-test-steps)

    - [autocontrolleronly](#autocontrolleronly)

    - [donotrunon](#donotrunon)

    - [eval](#eval)

    - [firstlooponly](#firstlooponly)

    - [gotostep](#gotostep)

    - [lastlooponly](#lastlooponly)

    - [runif](#runif)

    - [runon](#runon)


- [Parameters to end execution early due to assertion failures](#parameters-to-end-execution-early-due-to-assertion-failures)

    - [abort](#abort)


- [Advanced parameters](#advanced-parameters)

    - [readsharedvar](#readsharedvar)

    - [writesharedvar](#writesharedvar)


## Full Examples

- [Simple form](#simple-form)

- [Multipart form](#multipart-form)

- [Data driven](#data-driven)


## Valid test step files

- [parameters](#parameters)

- [steps](#steps)

- [directives](#directives)

- [quotes](#quotes)

- [comments](#comments)


## Variables and Constants

- [Variables and Constants Overview](#variables-and-constants-overview)

- [Variables updated before each retry](#variables-updated-before-each-retry)

- [Variables updated once only per test step](#variables-updated-once-only-per-test-step)

- [Constants set at test run start time](#constants-set-at-test-run-start-time)

- [Constants affected by substitution modifiers](#constants-affected-by-substitution-modifiers)

- [Setting Custom Variables](#setting-custom-variables)


## Auto Substitutions

- [Auto Substitutions](#auto-substitutions-overview)

- [{NAME}](#name)

- [{DATA}](#data)


## Pass/Fail Criteria

- [Verifications](#verifications)

- [HTTP Response Code Verification](#http-response-code-verification)

- [Test Step Pass/Fail Status](#test-step-passfail-status)

## Test results output

- [results.html](#resultshtml)

- [results.xml](#resultsxml)

- [STDOUT Results](#stdout-results)

- [http.txt](#httptxt)

- [Individual step html files](#individual-step-html-files)

## Session Handling and State Management

- [State Management Summary](#state-management-summary)

- [Cookies](#cookies)

- [Cookieless Session Management](#cookieless-session-management)

- [ASP.NET __VIEWSTATE](#aspnet-__viewstate)

- [Session ID in HTTP response header](#session-id-in-http-response-header)

## Additional Info

- [Parallel Automated Test Execution](#parallel-automated-test-execution)

- [Advanced Assertions](#advanced-assertions)


## Hints and tips

- [Modify a variable using regular expressions](#modify-a-variable-using-regular-expressions)

- [Post a message to a Slack Channel](#post-a-message-to-a-slack-channel)

- [Conditionally run a test step based on multiple criteria](#conditionally-run-a-test-step-based-on-multiple-criteria)

<br /><br />


## Software Architecture

### Architecture Diagram

![Alt text](images/WebImblaze_Arch.png?raw=true "Architecture Diagram")

### Summary

WebImblaze is a HTTP level test automation tool initiated from the command line. WebImblaze sends
HTTP GET, POST, PUT or DELETE requests to the target web site (System Under Test), and runs assertions against the response.

WebImblaze is well suited to running large suites of functional automated regression tests / checks against multiple
test environments, or even production.

When using WebImblaze with HTTP GET or POST commands, it is much faster than Selenium WebDriver. It is also less
likely to suffer from the test flakiness that is inherit with Selenium WebDriver.

<br/>


## Configuration

### config.xml

There is a configuration file named 'config.xml' that is used to store configuration settings for your project.  You can
use this to specify which test step files to run (see below) and to set some constants and settings to be used by WebImblaze.

If you use WebImblaze in console mode, you can specify an alternate config file name by using the option -c or --config. See the
"Command Line Options" section of this manual for more information.

All settings and constants must be enclosed in the proper tags, and simply need to be added to the config.xml file
(order does not matter).

Available config settings are:

<br />


#### proxy
Specifies a proxy server to route all HTTP requests through.

```xml
<proxy>http://127.0.0.1:8080</proxy>
```

You can also do proxy authentication like this:

```xml
<proxy>http://username:password@127.0.0.1:8080</proxy>
```

<br />


#### useragent - config
Specifies a User-Agent string to be sent in outgoing HTTP headers.  If this setting is not used, the default
User-Agent string sent is "WebImblaze".  A User-Agent string is how each request identifies itself to the web server.

```xml
<useragent>Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0)</useragent>
```

<br />


#### httpauth

Specifies authorization headers to your request for HTTP Basic Authentication.  HTTP provides a simple challenge-response
authentication mechanism which may be used by a server to challenge a client request and by a client to provide authentication
information.  This configuration parameter takes a list of 5 delimited values that correspond to:
`:servername:portnumber:realm-name:username:password`

The port number typically will be 80 for `http://` requests, and 443 for `https://`.

Sometimes the port number is specifically mentioned in the url - for example the default Apache Tomcat port is 8080.

Note that you specify the delimiter with the first character.

```xml
<httpauth>|www.fakedomain.com|80|my_realm|foo|welcome</httpauth>
```

You can use also use NTLM authentication in the following format. You'll need to use Authen::NTLM at least version 1.05 for this to work.
```
cpan Authen::NTLM
```

```xml
<httpauth>|server.companyintranet|80||ntdomain\\username|password</httpauth>
```

When using NTLM is is also recommended to set a high maxredirect.

```
step:                   Get an NTLM page
url:                    https://sharepoint.internal/login
maxredirect:            10
```

Note: You can have as many httpauth entries as you need.

```xml
    <httpauth>!my.corporate.internal!8080!my_area!foo2!welcome2</httpauth>
    <httpauth>?github.com?443?darkmoon?user?pass</httpauth>
    <httpauth> tfl.gov.uk 80 realm username password</httpauth>
```

_*Basic Authentication Example*_

For basic authentication you need to set maxredirect to at least 1.

In your config.xml file, add the following line:
```
    <httpauth>|postman-echo.com|443|Users|postman|password</httpauth>
```

Now create a test step file with the following step:
```
step:                   Postman Echo - basic-auth
url:                    https://postman-echo.com/basic-auth
maxredirect:            1
```

If you run it, you get an `{"authenticated":true}` response from the Postman Echo service.

<br />


#### baseurl
Creates the constant {BASEURL} which can be used in test steps (see 'Variables and Constants' section below).

```xml
<baseurl>http://myserver</baseurl>
```

<br />


#### baseurl1

Creates the constant {BASEURL1} which can be used in test steps (see 'Variables and Constants' section below).  This works
in the same way as the 'baseurl' example above.

<br />


#### baseurl2
Creates the constant {BASEURL2} which can be used in test steps (see 'Variables and Constants' section below).  This works
in the same way as the 'baseurl' example above.

<br />


#### timeout
Sets a response delay timeout (in seconds) for every test step.  If the response in any test step takes longer than
this threshold, the HTTP request times out and the step is marked as failed.  The default timeout if you do not specify one
is 180 seconds.


```xml
<timeout>10</timeout>
```

Note: This timeout setting may not always work when using SSL/HTTPS.

<br />


#### globalretry
This setting is used along with the retry parameter in a test step. It limits the number of retry attempts in a test run.
For example, consider 3 test steps each set to retry 40 times, along with a globalretry value of 50. If the test run is going
badly, then there will be no more than 50 retry attempts rather than 120.


```xml
<globalretry>50</globalretry>
```

<br />


#### globaljumpbacks

Limits the number of times the checkpoint parameter is invoked. Stops tests potentially running forever.

If not present, defaulted to 20.

<br />


#### autoretry - config

Sets how many times to automatically retry a failed test step.

If a retry parameter is present, or checkpoint is active, that will take preference.

If not present, auto retry defaults to off.

Note that autoretry can also be set in the test file.

```xml
<autoretry>5</autoretry>
```

<br />


#### ports_variable

When set to `convert_back` will change `{:4040}` to `:4040`.

When set to `null` will change `{:4040}` to null.

<br />


#### environment
Used in conjunction with the runon and donotrunon test step parameters. Tests that have the runon parameter will only
be run if one of the environments specified match the environment configure here.

Example - in the config file:
```xml
    <wif>
        <environment>DEV</environment>
    </wif>
```

In the test step specify:
```
runon: DEV|PAT
```

In this example, the test step will be run since the environment is defined as DEV in the config file
and we have specified to allow the test to run on DEV and PAT.

On the other hand, tests that have the donotrunon will be treated inversely.

So with the same config file as above, if we have this parameter:

```
donotrunon: DEV|PAT
```

Then the test step will be skipped.

<br />


#### autocontrolleronly
Allows you to designate certain servers as an automation controller.
This enables you to specify that certain test steps should only be run from the automation controller.

```xml
<automationcontrolleronly>Allow</automationcontrolleronly>
```

In the test step that you only want to run on automation controllers, specify the parameter `automationcontrolleronly="true"`

<br />


#### userdefined
You can create your own arbitrary config values that can be accessed as constants in the test steps.

```xml
<userdefined>
    <adminuser>admin@example.com</adminuser>
    <adminpass>topsecret</adminpass>
</userdefined>
```

In this example, you would refer to the constants in your test steps as {ADMINUSER} and {ADMINPASS}.

<br />


#### autoassertions
It is possible to specify assertions that run automatically on every single test step.

A possible usage is to check that you have not obtained an error page.

```xml
<autoassertions>
   <autoassertion1>^((?!error.stacktrace).)*$|||A Java stack trace has occurred</autoassertion1>
   <autoassertion2>^((?!jobseeker 500 error).)*$|||A jobseeker 500 error has occurred</autoassertion2>
</autoassertions>
```

In the example above, the regular expression is constructed in such a way that the assertion will
pass if the search text is not found. For autoassertion1, `error.stacktrace` is the string that should
not be found in the response. After the three bars, i.e. `|||`, the optional error message that should be shown
on failure is specified.

<br />
```xml
<autoassertions>
   <autoassertion1>Copyright Example Company 2016</autoassertion1>
</autoassertions>
```

This second example automatically asserts that this copyright message appears in every response.

<br />


#### smartassertions
It is possible to specify assertions that run conditionally on every single test step.

The condition is set as part of the smart assertion.

```xml
<smartassertions>
   <smartassertion1>Set\-Cookie: |||Cache\-Control: private|Cache\-Control: no\-cache|||Must have a Cache-Control of private or no-cache when a cookie is set</smartassertion1>
</smartassertions>
```

In the example above, the condition is specified first, before the `|||`.

The condition in this step is that the `Set\-Cookie: ` regular expression finds at least one
match in the response output.

If the condition is met, then the regular expression after the `|||` is executed.

If one or match is found, then the smart assertion passes (silently).

If a match is not found, the message after the final `|||` is logged and the test step is failed.

This feature is really useful for asserting that various standards are followed. In the event
that exceptions are agreed, the ignoresmartassertions parameter can be used.

<br />


#### reporttype

**Nagios Plugin Mode**

Two options:

```xml
<reporttype>nagios</reporttype>
```

or

```xml
<reporttype>standard</reporttype>
```

Setting the report type to `nagios` tells WebImblaze to behave as a Nagios plugin.

When in Nagios mode, all the regular information written to STDOUT is suppressed. Instead at the
end of testing, a single line is output according to Nagios standards.

##### CRITICAL
If one or more test failed, you'll get an output like the following:

```
WebImblaze CRITICAL - Nagios should see this error message |time=0.007;100;;0
```

or

```
WebImblaze CRITICAL - Test step number 10 failed |time=0.008;100;;0
```

In the first example, a test step failed that had an errormessage parameter.

In the second example, no errormessage parameter was present, so the test step number that failed is
reported.

In both scenarios, if more than one test step fails, only the first test step that failed is reported to Nagios.

##### UNKNOWN
If a test step has an abort parameter, and this is invoked, then WebImblaze will exit with the UNKNOWN exit code

```
WebImblaze UNKNOWN - aborted - Test step number 10 failed |time=0.008;100;;0
```

##### WARNING
Another type of message to Nagios is a warning that the globaltimeout was exceeded.

```
WebImblaze WARNING - All tests passed successfully but global timeout (0.01 seconds) has been reached |time=0.026;0.01;;0
```

This message is produced when all test steps passed, but the `globaltimeout` parameter in the config file was exceeded. See
globaltimeout for more information.

##### OK
Finally, if WebImblaze ran the tests without any issues, then a message like this is produced:

```
WebImblaze OK - All tests passed successfully in 0.007 seconds |time=0.007;100;;0
```

When running with the Nagios reporttype, it is recommended to use the `--no-output` option as follows:
```
perl wi.pl --no-output selftest/substeps/nagios.test -c selftest/substeps/nagiosconfig.xml
```

<br />


#### globaltimeout

**Nagios Plugin Mode**

The globaltimeout is only used when in Nagios plugin mode (see reporttype). If the globaltimeout parameter is
present, then total test response time is checked against this parameter. If sum of the test step response times
is higher than this value (in seconds), then a warning is sent to Nagios.

```xml
<globaltimeout>5</globaltimeout>
```

<br />


#### wif

The WebImblaze Framework passes the batch name, the parent folder of the test step file, and the
current run number to WebImblaze. WebImblaze uses this information to create links back to the
WebImblaze Framework results summary. These links can be found in the individual html step files
(e.g. 10.html, 20.html).

This section looks like:

```xml
<wif>
    <batch>security</batch>
    <folder>examples</folder>
    <run_number>1038</run_number>
</wif>
```

If this section is not present, the links will be null.

<br />


#### selenium-binary

**only applicable when using the WebImblaze-Selenium plugin**

In order to support Selenium WebImblaze needs to know where to find the relevant binaries.

The binaries locations can be specified through command line options. They can also be specified
in the config file as follows.

For Windows:
```xml
    <windows>
        <chromedriver-binary>C:\selenium\chromedriver.exe</chromedriver-binary>
        <selenium-binary>C:\selenium\selenium-server-standalone-3.11.0.jar</selenium-binary>
    </windows>
```

For Linux:
```xml
    <linux>
        <chromedriver-binary>$HOME/selenium/chromedriver</chromedriver-binary>
        <selenium-binary>$HOME/selenium/selenium-server-standalone-3.11.0.jar</selenium-binary>
    </linux>
```

It is possible to have the Linux and Windows values in the same config file. WebImblaze works out whether
to use the Windows or Linux variables at run time.

<br />


#### teststepfile

One of the configuration file settings in config.xml is used to name the test step file that you have created.
You may specify one test step file to process by placing the file name inside the (<teststepfile>) xml tags.

A configuration file containing a test step file to process (my_tests.test) may look something like:

```xml
<teststepfile>my_tests.test</teststepfile>
```

Note: You can also use relative path names to point to test step files located in other directories or subdirectories.

Don't specify more than one test step file, it won't work!

<br />


### Command Line Options

WebImblaze is called from the command line and has several command line options.

Usage:

```
perl wi.pl teststep_file <<options>>
```

Example:

```
perl wi.pl examples/simple.test
```

The command line options are:

```
-c|--config config_file           --config config.xml
-o|--output output_location       --output output/
-a|--autocontroller               --autocontroller
-x|--proxy proxy_server           --proxy localhost:9222
-i|--ignoreretry                  --ignore-retry
-z|--no-colour                    --no-colour
-n|--no-output                    --no-output
-e|--verbose                      --verbose
-u|--publish-to                   --publish-to C:\Apache24\htdocs\this_run_home
```

or

```
perl wi.pl --version|-v
perl wi.pl --help|-h
```

<br />


#### Command Line Options - full description

`-c` or `--config`

This option is followed by a config file name.  This is used to specify an
alternate configuration file besides the default (config.xml).  To specify a config file in a different
directory, you must use the relative path to it (from WebImblaze directory).

`-o` or `--output` : This option is followed by a directory name or a prefix to prepended to the output
files.  This is used to specify the location for writing output files (http.txt, results.html, and
results.xml).  If a directory name is supplied (use either an absolute or relative path and make sure to
add the trailing slash), all output files are written to this directory.  If the trailing slash is omitted,
it is assumed to a prefix and this will be prepended to the output files.  You may also use a combination
of a directory and prefix.

To clarify, here are some examples:


To have all your output files written to the /foo directory:
`perl wi.pl -o /foo/`

To have all your output files written to the foo subdirectory under your WebImblaze home directory:
`perl wi.pl -o ./foo/`

To create a prefix for your output files (this will create output files named foohttp.txt, fooresults.html,
and fooresults.xml in the WebImblaze home directory):
`perl wi.pl -o foo`

To use a combination of a directory and a prefix (this will create output files named foohttp.txt,
fooresults.html, and fooresults.xml in the /bar directory):
`perl wi.pl -o /bar/foo`

Note: MS Windows style directory naming also works.

Note: You must still have write access to the directory where WebImblaze resides, even when writing output
elsewhere.

`-a` or `--autocontroller`

Specifies to run autocontrolleronly test steps.

`x` or `--proxy`

Specifies proxy to use, e.g. `--proxy localhost:9222`

`-i` or `--ignoreretry`

Specifies to ignore any retry or checkpoint parameters, and also autoretry.

`-z` or `--no-colour`

Specifies to not output ANSI colour

`-n` or `--no-output`

Specifies to not output anything to standard out (except any Nagios data)

`-e` or `--verbose`

Specifies to display the request and response as_string for each test step

`-u` or `--publish-to`

Specifies where to output the individual html test step results for display by a web server.

E.g., `--publish-to C:\inetpub\wwwroot\this_run_home`

`-v` or `--version`

Displays the version number and other information.

`-h` or `--help`

Displays the command line switches.

<br />


#### Passing a Test Step Filename

When you launch WebImblaze in console mode, you can optionally supply an argument for a test step file to run.  It will look for this
file in the directory that wi.pl resides in.


`perl wi.pl mytests.test`


If no filename is passed from the command line, it will look in config.xml for a `teststepfile` declaration. If none of these are
found, the engine will stop and give you an error.


Note: If you pass a test step filename from the command line and also have a teststepfile declaration in your
config file, the file specified in the config file will not be processed (but all other config options are still used).

<br />


#### More Examples of Command Line Usage

Here are some examples to illustrate using wi.pl from the command line:

1) Launching wi.pl using the default config file and test step file:


`perl wi.pl`


2) Launching wi.pl specifying an alternate test step file and config file:


`perl wi.pl mytests.xml -c myconfig.xml`


3) Launching wi.pl from a different directory. As an example, you installed WebImblaze in /usr/local/webimblaze.  This will  
use the default config.xml file located in the same directory as wi.pl:


`perl /usr/local/webimblaze/wi.pl`


4) Launching wi.pl from a different directory and specifying an alternate test step file and config file. As an example,
you installed WebImblaze in /usr/local/webimblaze.  This will use myconfig.xml and mytests.test files located in the same directory
as wi.pl:


`perl /usr/local/webimblaze/wi.pl mytests.test -c myconfig.xml`


4) Launching wi.pl and specifying a relative path to an alternate test step file and config file. As an example, you have
your test step file and config file are located in a subdirectory named 'myfiles':


`perl wi.pl ./myfiles/mytests.test -c ./myfiles/myconfig.xml`

<br />


### File level directives

#### include

The "include" directive will import another test file.

```
include: examples/include/include_demo_1.test
```

What this will do is include the test steps in `include_demo_1.test` at id 10 if it was
the first step in the test file. It uses numbering to the right of the decimal point.

So if `include_demo_1.test` had 5 steps, they could be numbered 01, 02, 03, 04 and 05.

Then when they get included in the master test step file, they will become 10.01, 10.02, 10.03, 10.04 and 10.05 (given
this example).

```
include: includes/create_new_user.test

include: includes/login.test
```
You can have as many includes as you need, but it will only go one level deep.

To do this effectively, you need to setup the the variables the test steps require. 
Then you put in the include step.

<br />


#### repeat

There is a "repeat" directive you can set on a line by itself.

For example, to have a test step file run 5 times, your file should have
```
repeat: 5
```
followed by a blank line. This can be anywhere in the file,
but it cannot be part of a step. It can only appear once in the file.

<br />


#### useragent - directive

Sets the useragent at a test file level.
```
useragent:  My file level useragent
```

The useragent can be set in `config.xml`, at the file level and at the step level.
Step level overrides, file level, and file level overrides `config.xml`.

<br />


## Test Steps

### Test Step Summary

Test steps are written in `.test` files and passed to the WebImblaze engine for execution against
the application/service under test. This abstracts the internals of WebImblaze's
implementation away from the non-technical tester, while using an open architecture [written in Perl]
for those that require more customization or modifications.

There are many parameters you can use in your steps, depending on what you are trying to
accomplish.  The only required parameter is 'step'. If no verification parameters
(verifypositive, verifynegative, verifyresponsecode, etc.) are provided, the test step will be marked as
"FAILED" if the HTTP request returns an HTTP Response Code that is not in the 100-399 range.  
See the "Pass/Fail Criteria" section of this manual for more information.

<br />


### Minimal Example

A minimal test step file may look something like, say `minimal.test`:
```
step: Check test.html
url:  http://myserver/test/test.html
```

In this example, WebImblaze will get the specified url and ensure it passes:
- built-in validations, like response code is not in the error range
- any auto assertions you may have specified in the config file
- any smart assertions you may have specified in the config file, if applicable

<br />

### Test step internal numbering

Test steps are numbered internally in multiples of 10. So if your test file has three
steps, they will be called 10, 20 and 30 in the test result output.

Include steps are numbered with the decimal point starting from .01 in multiples of 0.01.

So if you have an include directive for the second step, the sub steps will be called
20.01, 20.02, 20.03 and so on.
```
step:       This is step 10

# Login script with 3 steps - will be called 20.01, 20.02, 20.03
include:    includes/login.test

step:       This is step 30
```

If the repeat directive is used, 10000 will be added to each step number each time
test execution repeats.

<br />


## Step Parameters

### Core Parameters

#### step

Name of the test step.

```
step: Get Search Form
```

`step` is mandatory.

`step` must always be the first parameter in a step block.

<br />    


#### desc

Optional further description.

```
desc: Check that new user analytics fired
```

`desc` is optional.

<br />


#### url

Full HTTP URL to request.  You can use an IP Address or Host Name.

```
url: http://www.example.com/search.aspx
```

<br />


#### posttype

This parameter specifies the content type encoding used in submitting a form to the server ("Content-Type" field
in the HTTP Header).  The possible values are:

```
posttype: application/x-www-form-urlencoded
```

```
posttype: multipart/form-data
```

```
posttype: text/xml
```

```
posttype: application/soap+xml
```

```
posttype: application/json
```

Defaults to "application/x-www-form-urlencoded" if this parameter is omitted.

<br />


#### postbody

This is the data (body) of the request to be sent to the server. (For "post" or "put".)

If you are sending "application/x-www-form-urlencoded" data, this parameter contains the string of text data you wish to send.

```
method:     put
posttype:   application/x-www-form-urlencoded
postbody:   txtUsername=admin&txtPassword=password1
```

If you are sending "multipart/form-data" (used for form-based file upload as specified in RFC 1867), this parameter contains
a string that represents the Perl code used to define the "Content" parameter of the Perl "POST" function. This string
will be evaluated by the Perl interpreter using "eval".  More details about the syntax can be found in the Perl documentation
of the HTTP::Request::Common module.

```
posttype: multipart/form-data
postbody: ( 'companyName' => 'Example', 'companyId' => '55201', 'companyLogo' => ['testdata\logos\Example.jpg'] )
```

JSON can be sent as follows.

```
posttype: application/json
postbody: {"application": "search", "searchtype": "postcode", "criteria": "WC1X 8TG"}
```


If you are sending "text/xml" or "application/soap+xml" (used for web services), this parameter contains a link to an external file
that contains the text (xml payload) that will be sent in the body of your request.  This is done using the `file=>` syntax.
Example: `postbody="file=>soap_payload.xml"`

```
posttype:   text/xml
postbody:   file=>testdata\GetJobs.xml
addheader:  SOAPAction: "http://www.example.com/ns/1.0/GetNewJobs"
```

Standard substitutions are supported when posting a file using the "text/xml" or "application/soap+xml" posttype.
In the example above, `GetJobs.xml` could look like the following.
```xml
<?xml version="1.0" encoding="UTF-8"?>
<search>
	<seq>1</seq>
	<title>{TITLE}</title>
	<location>{LOCATION}</location>
</search>
```


<br />


#### verifypositive

String in response for positive verification. Verification fails if this string does not exist in the HTTP response.  This is matched
as a Perl regular expression, so you can do some complex verification patterns if you are familiar with using regex matching.  

You can also specify that a custom message be output if the verification fails by placing ||| then your message on the right hand side
of the verifypositive. This is really useful if you need to verify a number of really cryptic strings in a test step. You are able
to specify a custom message for each verification that fails. See the examples.

Example - check for "Saved OK" in response:
```
verifypositive: Saved OK
```

Example - check for various Webtrends tags in response, and output a custom message if it isn't found:
```
verifypositive:     WT897234|||Webtrends Profile Saved tag not found
verifypositive1:    WT897264|||Webtrends New User tag not found
verifypositive2:    WT897292|||Webtrends Full Profile tag not found
```

Note: Because your verification string is used as a regex, the following characters within it must be escaped with a
backslash:  `{}[]()^$.|*+?\`

You can have as many verifypositive parameters as you want, so long as they start with verifypositive. For example, you can have
verifypositive20, verifypositive5000, verifypositiveHTML or whatever.

It is also possible to disable an assertion without removing it. This is useful if you have a temporary problem. You do this by adding
another three `|||` and writing any message after the custom error message.

```
verifypositive: Record 5520|||Record 5520 is within 15 miles so should show|||Production Bug
```

In addition, you can prepend a `fail fast!` flag to the start of the assertion to indicate that in the event the assertion fails,
WebImblaze should not retry the current test step.

```
verifypositive: fail fast!All Canary Tests Passed OK
```

<br />


#### verifynegative

String in response for negative verification. Verification fails if this string exists in the HTTP response.  This is matched
as a Perl regular expression, so you can do some complex verification patterns if you are familiar with using regex matching.  

Note: Because your verification string is used as a regex, the following characters within it must be escaped with a
backslash:  `{}[]()^$.|*+?\`

As per verifypositive, you can have as many verifynegatives as you want, so long as they all start with verifynegative.

```
verifynegative:     The system cannot find the file specified
verifynegative1:    OutOfMemoryException
```

And also as per verifypositive, you can specify a custom message if that verification fails.

```
verifynegative: additional-search-results-btn|||Additional Search Results button should not be shown
```

As with verifypositive, it is possible to disable a negative assertion without removing it. You do this by adding
another three `|||` and writing any message after the custom error message.

```
verifynegative: Record 5550|||Record 5550 is across county border - should not show|||Bug introduced with build 15221
```

In addition, you can prepend a `fail fast!` flag to the start of the assertion to indicate that in the event the assertion fails,
WebImblaze should not retry the current test step.

```
verifynegative: fail fast!A critical error has occurred
```

<br />


#### parseresponse

Parse a string from the HTTP response for use in subsequent requests.  This is mostly
used for passing Session ID's, but can be applied to any step where you need to pass a
dynamically generated value.  It takes the arguments in the format
"leftboundary|rightboundary", and one of two optional third arguments.

Use "leftboundary|rightboundary|escape" when you want to force escaping of all
non-alphanumeric characters. See the "Session Handling and State
Management - Parsing Response Data &amp; Embedded Session ID's"
section of this manual for details and examples on how to use this parameter.

Use "leftboundary|rightboundary|decode" when you want to decode html entities - for example
converting &amp;amp; back to &amp; and &amp;lt; back to < - which you may need to do in some circumstances.

Use "leftboundary|rightboundary|quotemeta" to quote meta characters (i.e. with backslashes). This is useful if you want
to use the result of a parseresponse in a regular expression - any special characters will be treated
as literal characters.

If you specify the text "regex" as the right boundary, the left boundary will be treated as a custom regular expression.

Note: You will need to prepend a backslash before these reserved characters when parsing:
`{}[]()^$.|*+?\`


Note: Newlines (\n) are also valid boundaries and are useful when you need to use the end of the line as a boundary.

Example - match from the first instance of START until END is found:
```
parseresponse: START|END|
```

Example - match from the first instance of START until END is found, then escape the matched text:
```
parseresponse: START|END|escape
```

Example - custom regex - parsed characters are the ones matched inside the parentheses:
```
parseresponse: a id="\w*" class="first" href="/careers-advice/(\d*)"|regex|escape
```

Example - when what we know is on the RHS - this pattern extracts option values:
```
parseresponse: option value="([0-9]+)".AutoTESavedSearch1|regex|escape
```

Example - Will find user@example.com in a response containing <email>user@example.com</email>
```
parseresponse: email.([^\<]+)
```

Example - the {5,60} specifies that the number of characters matched must be between 5 and 60:
```
parseresponse: name="(.{5,60}?)"
```

Example - in this regex, the .* at the front tells it to return the last match, rather than the first:
```
parseresponse: .*UserId="(.*?)"\<
```

Example - match a date in 31/12/2010 format (will also match invalid dates like 42/79/2010):
```
parseresponse: ([\d][\d]/[\d][\d]/[\d]{4,4})
```

Example - match the ctl number for a field:
```
parseresponse: ctl(\d\d).ctl00.btnApplyOnline
```

Example - match a GUID in format "91072487-558b-43be-a981-00b6516ef59c"
```
parseresponse: [a-z0-9\-]{36,36}?
```

Example - match third occurrence
```
varREGEX_THAT_GRABS_FIRST_MATCH:    "Result_Id":(\d*)
parseresponseSEARCH_RESULT_ID_3:    (?:.*?{REGEX_THAT_GRABS_FIRST_MATCH}){3,3}
```
Note here that the {3,3} is much safer than {3} since WebImblaze might have a variable called {3} that takes preference

**Referencing the results of a parseresponse in later test steps**

`parseresponse1` would be referred to as `{1}`,  `parseresponse5000` as `{5000}` and `parseresponseUSERID` as
`{USERID}`. `parseresponse` is referred to simply with `{}`.

Full Example - parse the redirect location from the response header
```
step:                   Search for WebDriver Jobs
url:                    http://www.example.com/JobSearch/Results.aspx?Keywords=WebDriver
parseresponseREDIRECT:  Location: |\n|decode

step:                   (redirect) Get search results
url:                    http://www.example.com{REDIRECT}
```

You can have as many parseresponses as you want, so long as they all start with parseresponse. Examples are
parseresponse1, parseresponse5000 and parseresponseUSERID.

<br />


#### var

Set a variable that can be used in the same test step.

```
step:               Creating new user: {TESTEMAIL}
varTESTEMAIL:       newuser_{JUMPBACKS}_{RETRY}_{COUNTER}@example.com
url:                http://{MYWEBSITE}/RegisterUser
postbody:           txtUsername={TESTEMAIL}&txtPassword=topsecret
verifypositive:     Registration Success!
verifypositive1:    New user {TESTEMAIL} created OK
retry:              3
```

<br />


### Additional Test Driver Parameters

#### shell

Allows you to run a OS level command using the backtick operator in Perl.

Cannot be used in conjunction with `selenium` or `url` in a single test step.

```
shell:                  cat test_data_file.txt
shell1:                 ls -asl
parseresponseUSERNAME:  USERNAME5="|"|
parseresponsePASSWORD:  PASSWORD5="|"|
```

In addition to shell, you can specify `shell1`, `shell2` ... up to `shell20`.
The shell commands are run in numerical order starting from `shell`.

Two special case parameters are also available.

##### readfile
```
step:                   Read a file and treat it as the response
readfile:               path/to/file.txt
```

##### echo
```
step:                   Echo a string and treat it as the response
echo:                   Var1 - {VAR}, Var2 - {VAR}
```

These two parameters can be used in conjunction with `shell` and each other, but 
not `selenium` or `url`.

<br />


#### commandonfail

Will run the specified command only if the test step is declared as having failed - after all
retries exhausted.

```
commandonfail: python emailsupportteam.py
```

<br />


#### commandonerror

Will run the specified command if an assertion fails - regardless of whether the test step
will be retried or not.

```
commandonerror: ./log_failure_statistic.py
```

<br />


#### addheader

This is used to add an addition header to an outgoing HTTP request.

```
addheader: SOAPAction: urn:example-org:demos#Method
```

```
addheader: Cookie: SoftLoggedInCookie=${SOFT_LOG_COOKIE}; MobileWebsite=1
```

You may add multiple headers, separating each with a pipe character.

```
addheader: Foo: bar|Boo: far
```

Note that when you use addheader, any existing header cookies will be clobbered.

Note also that HTTP::Headers class converts header field names to be title case
by default to make them look consistent. It can do this because the RFC says that
header field names are case insensitive. Unfortunately some people are not aware
of this and insist on case sensitive header field names. To get around this problem
preceed the header field name with a colon.

```
addheader: :foo-bar: value
```

In this example the header field name sent will be `foo-bar` and not `Foo-Bar`.

<br />


#### setcookie

Sets a new cookie for the url domain and port. The cookie will be retained for subsequent steps.

```
setcookie: MyCookieName: value_of_cookie
```

Separate multiple cookies with a semicolon:
```
setcookie: MyFirstCookie: cookie_value; MySecondCookie: another_value
```

Note that leading and trailing white space is removed. Cookie values cannot contain a colon or semicolon.

<br />


#### useragent - parameter

Change the user agent per test step. Once the user agent is changed in this way,
it will stay changed for subsequent test steps.

```
useragent: My user agent
```

<br />


#### maxredirect

Changes the maximum number of times WebImblaze will redirect for GET requests.

```
maxredirect: 5
```

This will be in force for subsequent test steps.

This does not work for POST requests. You can enable it by uncommenting the line in `wi.pl` that reads

```
    #push @{ $useragent->requests_redirectable }, 'POST';
```

However it does not seem to work very well. Presumably because cookies set by the POST response are probably
not captured.

<br />


#### method

HTTP request method, can be "put" or "delete" only.

```
method:     delete
```

```
method:     put
postbody:   txtUsername=admin&txtPassword=password1
```

Internally "post" will be inferred if a `postbody` is found. Otherwise "get" will be
assumed.

<br />


### Additional Assertion Parameters

#### assertcount

Used to assert that the specified text only appears a given number of times within the response. Can optionally give a custom message
if the assertion fails.

```
assertcount: Distance:|||1|||Should only be one job shown
```

You can have as many assertcount parameters as you want.

```
assertcount5000: Distance:|||1|||Should only be one job shown
```

```
assertcountDISTANCE: Distance:|||1|||Should only be one job shown
```


`assertcount` can be disabled without removing it. You do this by adding
another three `|||` and writing any message after the custom error message.

```
assertcount: uniquedata1092311|||2|||Expect 2 records only|||Production Bug
```

<br />


#### verifyresponsecode

HTTP response code for verification. Verification fails if the HTTP response code you specified does not match the HTTP response
code you receive.

```
verifyresponsecode: 500
```

<br />


#### verifyresponsetime

Asserts that the response time is no greater than the specified time.

```
verifyresponsetime: 2.505
```

In this example, the assertion will fail if the response time is greater than 2.505 seconds.

<br />


#### ignoreautoassertions

```
ignoreautoassertions: true
```

Enables you to turn off the auto assertions for various test steps when needed.

See the config file section for information on auto assertions.

<br />



#### ignoresmartassertions

```
ignoresmartassertions: true
```

Enables you to turn off the smart assertions for various test steps when needed.

See the config file section for information on smart assertions.

<br />


#### ignorehttpresponsecode

```
ignorehttpresponsecode: true
```

Normally we automatically fail a test step if the http response code wasn't in the 100-399 range.
Specifying this parameter allows us to ignore this verification.

<br />


### Retry Failed Test Step Parameters

#### autoretry - parameter

See the description of [autoretry](#configautoretry) in the config file section for the full description of this feature.

```
autoretry: 5
```
Sets auto retry to 5 from this step onwards.

```
autoretry: 0
```
Turns off auto retry from this step onwards.

<br />


#### checkpoint

In a video game when you fail, you are often returned to the last checkpoint to try again.

This is the same concept. You set a checkpoint as follows:
```
checkpoint: true
```
No when a subsequent test step fails, instead of failing the test, testing resumes from the checkpoint so we can try again.

This gives us a great way of dealing with a flaky, unstable or overloaded environment (like many development environments!).
Instead of failing immediately, we try a few more times before giving up.

The maximum number of attempts is governed by the `globaljumpbacks` configuration element.

Note that the session will be restarted before jumping back to the checkpoint. This means you need to think carefully about
at what points checkpoints are placed in the workflow.

To turn checkpoints off for subsequent steps, set the checkpoint parameter to `false`:
```
checkpoint: false
```

<br />


#### ignoreautoretry

Ignores auto retry for this step only.

```
ignoreautoretry: true
```

<br />


#### retry

This is used to retry a test step that has failed. You specify the maximum number of times
to retry the test step. Use this parameter if you need to wait for a database to update in
an asynchronous manner, but you don't know how long it will take.

```
retry: 5
```

You normally would use this parameter in conjunction with the sleep parameter so that there is a pause
before the test step is tried again.

In this example, if any of the verifypositives fail, or the assertcount fails, then WebImblaze
will wait 5 seconds, then retry the test step - up to 10 times. (After each failure, WebImblaze will
wait 5 seconds.) If and when the test step passes, WebImblaze will not wait 5 seconds before proceeding.
```
retry: 10
sleep: 5
```

Note that if a `fail fast!` flag is present on a verifypositive or verifynegative assertion, the test step
will not be retried.

```
verifynegative: fail fast!ErrorPage.aspx|||Error detected
```

Note that you can specify a global retry limit to prevent more than a specified number of retries
in a run. This is useful if you would like to specify the retry parameter in many test steps. If, when running,
things are going badly, the global limit will be enforced preventing your test run from taking
(seemingly) forever. See the Configuration File section to see how to set this up.

<br />


#### restartbrowseronfail

When present, will restart the WebImblaze session if any of the verifications fail.

If a Selenium WebDriver browser session is also present, that will be restarted too.

```
restartbrowseronfail: true
```

This has the effect of dumping all cookies and getting the session back to a known state.

This is useful if a request only partially succeeded thereby putting the session into an incorrect state.

```
step:                   Submit login details
url:                    http://{BASEURL}
postbody:               username=admin&password=12345
verifypositive:         Welcome admin
retry:                  5
restartbrowseronfail:   true
```

<br />


#### restartbrowser

Will restart the WebImblaze http session after execution of the current step.

If a Selenium WebDriver browser session is also present, that will be restarted too.

```
restartbrowser: true
```

All cookies will be dumped. Useful for logging a user out instantly.

<br />


#### sleep

Number of seconds to sleep after the test step.  This used to add spacing between steps in order to
throttle the rate it sends requests.

Sleep 5 seconds before proceeding:
```
sleep: 5
```

Since there is a retry parameter present in this example, WebImblaze will only sleep 5 seconds
if the test step fails any of the verifypositives or the assertcount.
```
sleep: 5
retry: 5
```

<br />


### Test Response Output Control Parameters

#### decodequotedprintable

Decodes a quoted-printable response and replaces the response with the decoded version. The decoded
version will be available to the parseresponse parameter.

```
decodequotedprintable: true
```

Note: This feature was added to deal with intermediate email files in quoted-printable format.

<br />


#### decodesmtp

Decodes the so called double dot encoding (see RFC 5321 Section-4.5.2) used by SMTP.

```
decodesmtp: true
```

<br />


#### dumpjson

If you have a JSON response, dumpjson will parse the JSON into a hash, then replace result
content with the dumped JSON.

This is useful in situations where your raw JSON contains a lot of encoded/escaped content, for example an email.

In the example of your JSON containing an email that is also quoted printable, if you chain this with
`decodequotedprintable`, it will be possible to see the rendered HTML email when viewing the test step
result in a browser.

```
dumpjson: true
```

Note that if you use this parameter with a non JSON response content, you will get a blank result.

<br />


#### errormessage

If a test step fails, this custom 'errormessage' will be appended to the 'TEST STEP FAILED' line
(on STDOUT and the HTML Report). This may be useful to give a bit more information on what a failed
test means, like "couldn't connect to the application" or "couldn't access the login page".

```
retry:          20
sleep:          5
errormessage:   Job still not in index after 20 tries, perhaps indexer is offline
```

<br />


#### formatjson

Improves readability of json responses.

```
formatjson: true
```

Inserts carriage returns at various places using a simple regular expression.

<br />


#### formatxml

Improves readability of xml responses.

```
formatxml: true
```

Sometimes when you receive a response in xml format, the response comes back without a single carriage return. It can be difficult to read.
Specifying this parameter puts a carriage return between every >< found in the response.

<br />


#### getallhrefs

Gets the hrefs referred to in the html response, and writes them to the output folder.

Multiple patterns are separated with a `|`. The pattern specifies the end of the filenames to match.

```
getallhrefs: \.css|\.less
```
From this step onwards, grab all resources ending with `.css` or `.less`.

WebImblaze will modify the individual step html to refer to these grabbed resources instead of the web server.

This means when you look at the actual result html rendered, it will look very similar to the actual website. HTML
without the resource files being available is often unreadable when trying to understand a test failure, so by having
the actual assets available, it makes it much easier to interpret the results.

If you specify `getallhrefs` a second time in a later test step, WebImblaze will look for a new version of that resource.
This means that if a resource file name has different content, you will be able to get it again. This is useful in the situation
where you have a common platform serving up many brands.

WebImblaze will remember the names of resources it has grabbed, and will not grab a resource with the same name and version a second time
during test execution. This means grabbing the resources will add very little overhead - most pages in a workflow will share the same CSS
and other assets.

<br />


#### getallsrcs

Gets the srcs referred to in the html response, and writes them to the output folder.

Multiple patterns are separated with a `|`. The pattern specifies the end of the filenames to match.

```
getallsrcs: \.jpg|\.png|\.js|\.gif
```

Works in the same way as getallhrefs.

<br />


#### getbackgroundimages

Gets the background images referred to in the html response, and writes them to the output folder.

Multiple patterns are separated with a `|`. The pattern specifies the end of the filenames to match.

```
getbackgroundimages: .jpg
```

This will match css background images that look like this in the html source:

```
<div style="background-image: url(/site-assets/teacup.jpg);" class="product-image item active"></div>
```

Only gets background images for the current step.

<br />


#### logastext

Putting this parameter on a test step will put tags around the test step in the http.txt file.

```
logastext: true
```

This is useful if you parse the http.txt into separate .html files and attempt to render it in the browser. This
parameter lets you mark particular test steps to treat as text output (e.g. SOAP or AJAX tests) so that you render it as plain text rather
than html.

<br />


#### logresponseasfile

Saves the test step response in a file.

Example:

```
step:               Get Responsive.css
url:                https://www.example.com/resources/css/Responsive.css
logastext:          true
logresponseasfile:  {PUBLISH}Captured.css
/>
```

<br />


#### section

Indicates in the results.xml that a section break occurs before this test.

Use in your Test Automation Framework when displaying the results.xml with a style sheet.

```
section: Ensure it is not possible to apply for the same job twice
```
<br />


### Parameters to conditionally skip test steps

#### autocontrolleronly

You can flag test steps as being "autocontrolleronly". Then when you invoke WebImblaze, specify
a command line option to indicate you are invoking it from the automation controller. WebImblaze will
then run test steps flagged as being "autocontrolleronly", which will otherwise be skipped.

```
autocontrolleronly: true
```

It is probably quite rare that you would have a need for this feature. One example is that you may have a
website that accepts document uploads. Your web server may check the uploaded documents for viruses. To test that
this works, you might have a test step that uploads a document containing an industry standard test virus.
However your organisation may have stringent virus checking that deletes any file suspected of containing a virus
immediately. You might be able to negotiate an exemption to virus checking for a particular file on your automation
controller. So with this feature you can skip the test steps in your regression pack on your workstations, but still run
the virus checking test steps on your automation controller. This is a real example of how this feature is used.

When you start WebImblaze, you will need to specify the -a parameter, otherwise test steps with the autocontrolleronly
parameter will be skipped:
```
wi.pl -a
```

<br />


#### donotrunon

As per runon, but the opposite.

```
donotrunon: PAT|PROD
```

In your config.xml, if you had the following, then the test step would be skipped:

```xml
    <wif>
        <environment>PROD</environment>
    </wif>
```

<br />


#### eval

The `eval` parameter is designed to be used in conjunction with `runif`. Though
it can also be used to do simple calculations.

```
evalRESULT:         5*3
```
{RESULT} will be 15.

```
evalOLD_DATA:       48-50>6
```
{OLD_DATA} will be falsy.

```
evalSHA1:           use Digest::SHA qw(sha1_hex); sha1_hex q|sha this text|;
```
{SHA1} will be `c1afc46a1e23b4006d66fb94a38929d9410de27f`.

```
evalNONCE:          use Digest::MD5 qw(md5_hex); md5_hex q|{RANDOM:5}|;
```
then in the next step
```
evalBASE64_NONCE:   use MIME::Base64; encode_base64(q|{NONCE}|, '');
```
{BASE64_NONCE} will not have carriage return due to `''` parameter.

<br />


#### firstlooponly

Step will only be run on first loop. Use with `repeat` directive.
```
firstlooponly: true
```

<br />


#### gotostep

After executing current step, continue execution from the step defined by step.
```
gotostep: Teardown
```

If there is a step with step `Teardown`, execution will continue from there.
```
step: Teardown
```

If a matching step cannot be found, execution will end immediately without failing the current step.

In practice, you would use this parameter with `runif`:
```
runif:      {SOME_VARIABLE}
gotostep:   Teardown
```

<br />


#### lastlooponly

Step will only be run on last loop. Use with `repeat` directive.
```
lastlooponly: true
```

<br />


#### runif

Conditionally skip a test step - if this parameter is present, the step will only be run
if the parameter is 'truthy'.

This test step is run, since 'abcd' is truthy.
```
runif:      abcd
```

This test step is not run, since the empty string '' is falsy.
```
runif:':    ''
```
Note in the above example we had to specify a quote character to make an empty string.


This test step is not run, since '0' is falsy.
```
runif:      0
```

In practice, you would use this parameter with a variable:
```
runif:      {SOME_VARIABLE}
```

<br />


#### runon

You can specify that selected test steps are skipped depending on the environment defined in the
config file. See the environment section of the configuration file section for information on how to configure the config file.

```
runon:      PAT|PROD
```

In your config.xml, if you had the following, then the test step would be skipped:

```xml
    <wif>
        <environment>DEV</environment>
    </wif>
```

<br />


### Parameters to end execution early due to assertion failures

#### abort

Used to abort a test run early. If you specify the abort parameter on a test step, and the
test step fails (after all retries have been exhausted), then the test run is aborted.

This feature is very useful if your automation regression suite takes a long time to run. If a very basic test,
like getting the home page, fails, then there little point running the rest of the tests.

```
abort:  true
```

You can also jump to the tear down section of your tests so you can do any necessary data clean up.

```
abort:  Teardown
```
In the above example, if the abort is invoked, then it will continue execution from the first step
it finds called "Teardown", as in:
```
step:   Teardown
```

<br />


### Advanced parameters

#### readsharedvar

Will read a variable created by a previous instance of `wi.pl`, or indeed, even one running concurrently.

```
readsharedvar: SESSION_COOKIE
```
In this example, the contents of the shared variable named SESSION_COOKIE will be read into a local variable called SESSION_COOKIE.
If there is no shared variable called SESSION_COOKIE, then the local variable of the same name will have no value.

Note that the `readsharedvar` will be performed regardless of whether runif passes or fails for the current step.

<br />


#### writesharedvar

Will write a shared variable to the file system. Another instance of `wi.pl` running under the same account will be able to read it.

```
writesharedvar: SESSION_COOKIE|SessionID: {PARSED_COOKIE};
```
Will create a shared variable called `SESSION_COOKIE` with the contents after the pipe parameter.

<br />


### Full Examples

#### Simple form

```
step:                   Get the admin login page
desc:                   Check page is available
url:                    http://example.com/test/login.jsp
verifypositive:         Please enter Username and Password
sleep:                  3

step:                   Post the username and password
desc:                   Check login success
url:                    http://example.com/test/admin_home.jsp
postbody:               username=admin&password=welcome
verifypositive1:        Welcome admin!
verifypositive2:        Your last login was at
verifynegative:         Login details incorrect
```

#### Multipart form

```
step:                   Multipart POST example
desc:                   Check file upload
url:                    http://cgi-lib.berkeley.edu/ex/fup.cgi
postbody:               ( upfile => ['config.xml'], note => 'MYCOMMENT' )
posttype:               multipart/form-data
verifypositive:         File uploaded OK
/>
```

#### Data driven
```
repeat: 3

step:                   Get row {COUNTER} from test data file
shell:                  perl -ne "print" examples/data.txt
parseresponseNAME:      NAME{COUNTER}:([\w ]+)
parseresponseTITLE:     TITLE{COUNTER}:([\w ]+)

step:                   Row {COUNTER}: {NAME}, {TITLE}
```

`examples/data.txt` could look like:
```
NAME1:Sarah Wu
TITLE1:Manager

NAME2:Steve Hain
TITLE2:Trader

NAME3:Jane Blog
TITLE3:Supervisor
```

Then the output would look like
```
perl wi.pl examples/data_driven.test

Starting WebImblaze Engine...

-------------------------------------------------------
Test:  examples\data_driven.test - 10
Get row 1 from test data file
Passed HTTP Response Code Verification
TEST STEP PASSED
Response Time = 0.014 sec
-------------------------------------------------------
Test:  examples\data_driven.test - 20
Row 1: Sarah Wu, Manager
Passed HTTP Response Code Verification
TEST STEP PASSED
Response Time = 0 sec
-------------------------------------------------------
Test:  examples\data_driven.test - 10010
Get row 2 from test data file
Passed HTTP Response Code Verification
TEST STEP PASSED
Response Time = 0.014 sec
-------------------------------------------------------
Test:  examples\data_driven.test - 10020
Row 2: Steve Hain, Trader
Passed HTTP Response Code Verification
TEST STEP PASSED
Response Time = 0 sec
-------------------------------------------------------
Test:  examples\data_driven.test - 20010
Get row 3 from test data file
Passed HTTP Response Code Verification
TEST STEP PASSED
Response Time = 0.017 sec
-------------------------------------------------------
Test:  examples\data_driven.test - 20020
Row 3: Jane Blog, Supervisor
Passed HTTP Response Code Verification
TEST STEP PASSED
Response Time = 0 sec
-------------------------------------------------------
Start Time: Thu 25 Oct 2018, 22:29:25
Total Run Time: 0.149 seconds

Total Response Time: 0.045 seconds

Test Steps Run: 6
Test Steps Passed: 6
Test Steps Failed: 0
Verifications Passed: 12
Verifications Failed: 0

Results at: output\Results.html
```

<br />


### Valid test step files

#### parameters

Parameters must begin on the first column of the line.

The parameter name must end with a colon followed by at least one space, `: `.

```
step: This is is valid

 step: not valid

step:not valid
```

Note that tabs are not allowed between the colon and the start of the parameter value.

#### steps

Each step block must be separated by at least one blank line.

```
step: Get page 1
url:  http://www.example.com/page1

step: Get page 2
url:  http://www.example.com/page2
```

Note that comments do not count as blank lines.

#### directives

The directives are not steps, but are file level instructions to WebImblaze. They
are processed before execution begins.

They can appear anywhere in the file, but must be separated from steps by at least
one blank line.

```
useragent:  Custom

step:       Get example
url:        http://www.example.com

repeat:     2
```

#### quotes

WebImblaze does not need to use quotes in most circumstances. It disregards leading
and trailing blank space for parameter values.

Example - verifypositive will have the value of `my text`.
```
verifypositive:     my text    
```

Example - verifypositive will have the value of `'my text'` - i.e. single quotes included.
```
verifypositive:     'my text'    
```
The fact that a single or double quote normally represents a quote is ignored, it is
treated literally.

This is fine for most circumstances, but sometimes you will really need a quote:
- if you want to set a parameter to a null value
- if you need leading or trailing white space to be part of the value
- if you need a multi-line value

WebImblaze lets you define your own quotes by specifying it immediately after the
parameter colon `:`. You end the quote definition by placing another colon followed
by a space. (No white space is allowed in the quote).

Example - verifypositive will have the value of ` my text ` (leading and trailing space included).
```
verifypositive:/:   / my text /
```

Example - varNULL will have the value of `` (empty string)
```
varNULL:(:          ()
```
If your quote contains `(`, `{`, `[` , or `<`, for the end quote it will be flipped, e.g. `[` becomes `]`.

Multi character quotes are also supported.
```
verifypositive:///:     ///my text///
```

When doing a multi-line quote, you *must* have the beginning quote on the first line.
```
postbody:_BIGQUOTE_:   _BIGQUOTE_
<xml>
    <tag>data</tag>
</xml>
_BIGQUOTE_
```

#### comments

A single line comment is done with the hash symbol, `#`.
```
step:   Get home page
url:    http://example.com
#verifypostive1: domain
verifypositve2: permission
```
Here, `verifypositive1` is ignored.

Multi line comments are have the opening tag `--=` and the closing tag `=--`.

```
--=
    HOME PAGE CHECKS
    ----------------
    1. check links
    2. check content
=--

step:   Get home page
url:    http://example.com
```


<br />


## Variables and Constants Overview

Certain constants and variables can be passed from your test steps to the WebImblaze engine.  They may be used in a test step
as a keyword contained within curly braces, and are evaluated/substituted at runtime.

### Variables updated before each retry

The first set of variables are the most dynamic. They can change each time a test step is retried as
a result of the invocation of the `retry` parameter.

Dynamic Variable | Description
:--------------- | :----------
**{RETRY}** | How many times the current test step has been retried. E.g. 0, 1, 2, 3 ...
**{ELAPSED_SECONDS}** | Elapsed seconds so far - always rounded up
**{ELAPSED_MINUTES}** | Elapsed minutes so far - always rounded up
**{NOW}** | Current date and time in format day/month/year_hour:minute:second

<br />


### Variables updated once only per test step

The next set of variables can hold different values between test steps, but will not change
between retries while a test step is being run.

Variable | Description
:------- | :----------
**{TIMESTAMP}** | Current time stamp (floating seconds since the epoch, accurate to microseconds)
**{EPOCHSECONDS}** | Integer seconds since the epoch
**{EPOCHSPLIT}** | Microseconds split component of {TIMESTAMP} - i.e. after the decimal point
**{TESTNUM}** | Id number of the current test step
**{LENGTH}** | Length of the response for the previous test step
**{TESTSTEPTIME:510}** | Latency for test step number 510
**{RANDOM:15}** | Random string of 15 alphanumeric characters (upper case only)
**{RANDOM:5:ALPHA}** | Random string of 5 alphabetic characters (upper case only)
**{RANDOM:8:NUMERIC}** | Random string of 8 numeric characters
**{COUNTER}** | What loop number we are on - corresponding to the `repeat="5"` (say) parameter at the start of the test steps
**{JUMPBACKS}** | Number of times execution has jumped back due to invocation of `checkpoint` parameter
**\[\[\[\|68656c6c6f\|\]\]\]** | Packs 68656c6c6f - which converts to the string `hello`. You can unpack a string (i.e. mask it to the casual observer) with the following Perl code `perl -e "print unpack('H*', 'hello')"`
**{}** | Result of the response parsing from a `parseresponse` test step parameter
**{1}** | Result of the response parsing from a `parseresponse1` test step parameter
**{5000}** | Result of the response parsing from a `parseresponse5000` test step parameter
**{ANYTHING}** | Result of the response parsing from a `parseresponseANYTHING` test step parameter

(See the "Parsing Response Data & Embedded Session ID's" section for details and examples on how to use these variables
created by means of a `parseresponse`.)

#### Special note on random

Due to the nature of the systems being tested by the author, the randomly generated strings will not
contain two characters in a row that are the same.

In addition, 0 will never be generated as the first character.

<br />

### Constants set at test run start time

The values of the constants are set at the run start time. They will not change while the test step file is being run.

Constant | Description
:------- | :----------
**{STARTTIME}** | WebImblaze start time, similar to {TIMESTAMP} - but remains constant during a run
**{AMPERSAND}** | Gives you a &
**{LESSTHAN}** | Gives you a <
**{SINGLEQUOTE}** | Gives you a '
**{CWD}** | Current working directory
**{PUBLISH}** | Folder where test results are written to if `--publish-to` option specified 
**{OUTPUT}** | Temp folder for WebImblaze, also default location of test results output, or "no output" if output is suppressed
**{HOSTNAME}** | Name of the computer currently running WebImblaze
**{OUTPUTFOLDERNAME}** | Output folder name only - not the full path
**{TESTFILENAME}** | Test file name
**{OPT_PROXY}** | What proxy option was specified via the command line to wi.pl
**{BASEURL}** | Value of `baseurl` specified in your config file
**{BASEURL1}** | Value of `baseurl1` specified in your config file
**{BASEURL2}** | Value of `baseurl2` specified in your config file

**{BASEURL} Example:**

If you a have a test step that uses the parameter:
```
url:    http://myserver/test/login.jsp
```

You could create this line in your config.xml file:
```xml
    <baseurl>http://myserver</baseurl>
```

You can then rewrite the test step parameter as:
```
url:    {BASEURL}/test/login.jsp
```

This is helpful if you want to point your tests at different environments by changing a single setting.

<br />

### Constants affected by substitution modifiers

Constants related to date are also set at execution start time.

Date Variable | Description
:------- | :----------
**{DAY}** | The day of the month at run start with leading 0, e.g. 06 [denoting the 6th]
**{DAYTEXT}** | The three letter day of the week, e.g. Sat
**{MONTH}** | The month number of the year at run start with leading 0, e.g. 05 [denoting May]
**{MONTHTEXT}** | The three letter month of the year, e.g. Mar
**{YEAR}** | The year at run start as 4 digits, e.g. 2016
**{YY}** | The year at run start as 2 digits, e.g. 16
**{HH}** | The run start hour in 24hr time with leading 0, e.g. 15
**{MM}** | The run start minute with leading 0, e.g. 09
**{SS}** | The run start second with leading 0
**{WEEKOFMONTH}** | The run start week number of month with leading 0 e.g. 05 [fifth week of the month]
**{DATETIME}** | The run start date and time without formatting - yearmonthdayhourminutesecond
**{FORMATDATETIME}** | The run start date and time with formatting - day/month/year_hour:minute:second

These constants also do not change value during the test run.

However they can be modified on a temporary basis to generate different dates during the substitution.

```
step:   {DATE:::-2*3}Day_Month_Year: {DAY}_{MONTH}_{YEAR}
```
In this example, 6 days are subtracted from the test run start date - for the step parameter only.

```
step:   Time in one hour: {DATE:::+1/24}Hour_Minute_Second: {HH}_{MM}_{SS}
```
In this example, 1 hour is added to the test run start date.

It does not matter where you put the `{DATE:::expression}` modifier in the parameter. It will be removed
(so long as the expression is valid) and the date variables will be modified accordingly. The date modification
is valid only for that parameter.

The expression can contain the digits 0 to 9 and the operators + - * /.

Consider this example:
```
verifypositive1: {DAY}/{MONTH}/{YEAR}
verifypositive2: {DATE:::1}{DAY}/{MONTH}/{YEAR}
verifypositive3: {DATE:::2}{DAY}/{MONTH}/{YEAR}
```
If today is 31/10/2017 then 31/10/2017, 01/11/2017 and 02/11/2017 will be asserted.

If you need to modify from the current time rather than the test start time, do this using `DATE_NOW`:
```
step:   {DATE_NOW:::-1/23}Day_Month_Year: {DAY}_{MONTH}_{YEAR}
```

It is also possible to modify from the current GMT time (which is not affected by daylight saving) using `DATE_GMT_NOW`:
```
step:   {DATE_GMT_NOW:::-1/23}Day_Month_Year: {DAY}_{MONTH}_{YEAR}
```

<br />


### Setting Custom Variables

You may also set constants in your test step file that you can reference from your test steps.  This makes it
convenient to change data in a single place that is easy to reference from multiple test steps.


The following example of a test step file shows how you can use them:

```
step:           Set variables
varLOGIN_URL:   http://myserver/login.php
varLOGIN1:      bob
varPASSWD1:     sponge
varSUCCESSFULL_TEST_TEXT:   Welcome Bob

step:           Login test step
desc:           Check login success message
url:            {LOGIN_URL}
postbody:       login={LOGIN1}&passwd={PASSWD1}
verifypositive: {SUCCESSFULL_TEST_TEXT}
```

<br />


### Auto Substitutions

#### Auto Substitutions Overview

In the postbody, two special variables are available - `{NAME}` and `{DATA}`.

These variables automatically work out the missing form name or hidden data
you need and substitute it for you.

This makes dealing with session management or dynamically named fields very
easy.

#### `{NAME}`

If you ever have to deal with postbody fields that are frequently renamed for one reason or another,
then `{NAME}` may help you. Typically these fields will have a component that is static, and another
component that changes.

For example, if you use a content management system like SiteCore, you might
have a field with a name like `ctl00$CentralPanel$txtUsername`. Later the name might change to
`ctl01$BottomPanel$txtUsername`. Normally you would have to update your automated tests. If you use
the `{NAME}` auto substitution, WebImblaze will work out the missing component for you.

So you can have a postbody like:

```
postbody: {NAME}txtUsername=TestUser&{NAME}txtPassword=secure&{NAME}BtnSubmit=Submit
```

instead of:

```
postbody: ctl01$CentralPanel$txtUsername=TestUser&ctl01$CentralPanel$txtPassword=secure&ctl02$BottomPanel$BtnSubmit=Submit
```

#### `{DATA}`

Sometimes you need to post hidden fields on a form back to the server. WebImblaze can take care of this
automatically if you use the `{DATA}` auto substitution. Let WebImblaze find and parse the necessary data values
for you!

Typical examples include when you have to deal with `__VIEWSTATE`, `__EVENTVALIDATION` or even
`__RequestVerificationToken`.

This means you can write a postbody like this:

```
postbody: RecipeName=Pesto&Cuisine=Italian&PrepTime=20&__RequestVerificationToken={DATA}&SomeOtherHiddenField={DATA}&BtnSubmit=Search+Recipes
```

#### How the `{NAME}` and `{DATA}` auto substitutions work

WebImblaze remembers the html content of the last 5 or so pages you visited. Normally you get the page first with a form,
then post the completed form. The form field names and hidden data can be found on the page with the form.

Pages with forms will have a `method="post" action="Some/Destination"` in the html. This helps WebImblaze identify
which page in its cache to get the appropriate information from.

You can enable the debug output of this feature by doing a replace all on wi.pl: Replace `#autosub_debug `
with nothing or just spaces.


## Pass/Fail Criteria

### Verifications

In each test step, you can set Verifications that will pass or fail depending on the existence of a specified text string
(or regex) in the content of the HTTP response you receive.

`verifypositive` - This Verification fails if the string you specified does not exist in the HTTP response you receive.

`verifynegative` - This Verification fails if the string you specified exists in the HTTP response you receive.


`verifypositive5000`, `verifypositiveANYTHING`, `verifynegative1234`, `verifynegativeWHATEVERYOUWANT`,  
work the same way.

<br />


### HTTP Response Code Verification

In each test step, you can set a Verifications that will pass or fail depending on the HTTP response code.

`verifyresponsecode` - This Verification fails if the HTTP response code you specified does not match the HTTP response code
you receive.

If you do not specify this test step parameter, the HTTP Response Code Verification is marked as "Failed" if the HTTP request
returns an HTTP response code that is not in the success range (100-399).  It is marked as "Passed" if the HTTP
Response Code is in the success range (100-399).

If you are testing an error page, you will need to use this parameter.

```
verifyresponsecode: 404
```

```
verifyresponsecode: 500
```

<br />


### Test Step Pass/Fail Status

If any of the Verifications defined within a test step fail, or if the HTTP Response Code Verification fails,
the test step is marked as "FAILED".  If all of the Verifications defined within a test step pass, and the
HTTP Response Code Verification passes, the test step is marked as "PASSED".  These items are updated in
real-time during execution.

<br />


## Test results output

### results.html

An HTML file (results.html) is generated to display detailed results of the test execution.
It is written into the WebImblaze output folder and is overwritten each time the tool runs.

The file contains data passed from the test step file (test step identifiers/descriptions, etc) as
well as information generated from the test engine (test step pass/fail status, execution times, etc).

<br />


### results.xml

An XML file (results.xml) is generated to display results of the test execution.
It is written into the directory that WebImblaze runs from and is overwritten each time the tool runs.

The file contains data passed from the test step file (test step identifiers/descriptions, etc) as
well as information generated from the test engine (test step pass/fail status, execution times, etc).

If you put an xsl style sheet against this file, you can get a customised display of the test run results.

<br />


### STDOUT Results

Results are also sent [in plain text format] to the STDOUT channel as the tests execute.

<br />


### http.txt

A log file (http.txt) is generated to capture HTTP requests that are sent to the web server of the system
under test and HTTP responses that are received from the system under test.  Whether or not HTTP logging is
turned on depends on a setting in the configuration file and if you have logging parameters turned on in each
test step.  See the "Configuration - Configuration File (config.xml)" and "Test Step Setup - Available Parameters"
sections of this manual for more information on logging to the http.txt file.

Note: "Content-Length" and "Host" HTTP headers are automatically added to outgoing HTTP POST requests, but are not shown in http.txt.  

<br />


### Individual step html files

For each test step, an html file will be created according to the step internally created step id. (10.html, 20.html, ...)

This allows you to review the actual result as html, rather than having to try and make sense
of the html code itself.

In order to provide a reasonable render of the html, the relative href links to the css and JavaScript
will be replaced with absolute references back to your target test server. The target server will need to be
available for this to work effectively.

<br />


## Session Handling and State Management

### State Management Summary

HTTP is a stateless protocol, meaning each request is discrete and unrelated to those that precede or follow.  Because of the
stateless nature of the protocol itself, web applications or services use various other methods to maintain state.  This allows
client connections to be tracked and connection-specific data to be maintained.  If your server requires the client to maintain
state during a session, then your test tool must be able to handle this as well.

<br />


### Cookies

One way to maintain session state is with HTTP Cookies.  WebImblaze automatically handles Cookies for you (like a browser would).
When a "Set-Cookie" is sent back in the HTTP header from the web server, the Cookie is automatically stored and sent back with
subsequent requests to the domain it was set from.

<br />


### Cookieless Session Management

Embedded Session ID's ("Cookieless" session management) is another approach to maintaining state.  Session ID's are written
to the content of the HTTP response that is sent to the client.  When the client makes a subsequent HTTP request, the Session
ID string must be sent back to the server so it can identify the request and match it with a unique session variable it is
storing internally.  The client sends the string embedded in the URL or embedded in the post body data of each HTTP request.

In order to do this, WebImblaze provides a method of parsing data from an HTTP response to be resent in subsequent requests.  This
is done using the `parseresponse` parameter and the `{}` variable in your test steps.

You can use additional parsing parameters if you need to parse multiple values from a single response.  

Here are some examples:

Parse Parameter | Corresponding Variable
:-------------- | :---------------------
parseresponse1 |{1}
parseresponse5000 | {5000}
parseresponseUSERNAME | {USERNAME}
parseresponseUSERGUID | {USERGUID}
parseresponseCOMPANYID | {COMPANYID}
parseresponsePARSEDRESULT3 | {PARSEDRESULT3}

Note: This parsing mechanism may be used for any situation where you need to resend data to the server that was sent to you in
a previous response.  There are other circumstances besides maintaining session where this may be useful.

<br />


#### ASP.NET __VIEWSTATE

ASP.NET may use a "__VIEWSTATE" variable to maintain state between requests.  When you request a page that uses this, you will see it
as a hidden form field within the HTML source:


```xml
<html>
...
<form method="post" action="default.aspx">
<input type="hidden" name="__VIEWSTATE" value="dDwtMTA4NzczMzUxMjs7Ps1HmLfiYGewI+2JaAxhcpiCtj52" />

...
</html>
```


To maintain state, you need to grab this value so you can resend it in subsequent requests.  To do this, you would add the
following parameter to your test step:


```
parseresponse: __VIEWSTATE" value="|"|escape
```


This will grab whatever is between the left boundary (__VIEWSTATE" value=") and the right boundary (") and assign to the system variable
named {}.  Since the 'escape' argument was used, it will also escape all of the non-alphanumeric characters with
their url hex values (.NET requires this).


Whenever you use the {} variable in a subsequent test step, it will be substituted with the last value you parsed:

```
postbody: value=123&__VIEWSTATE={}
```

Will be sent to the server as:

`value=123&__VIEWSTATE=dDwtNTA4NzczMzUxMjs6Ps1HmLfiYGewI%2b2JaAxhcpiCtj52`

<br />


#### Session ID in HTTP response header

You may receive a Session ID in a HTTP response header that needs to be parsed
and resent to the server as part of a URL rather than in a cookie.


To parse the Session ID from a header that contains:


`Set-Cookie: JSESSIONID=16CD67F723A6D2218CE73AEAEA899FD9; Path=/`


You would add the following parameter to your test step:


```
parseresponse: JSESSIONID=|;
```


This will grab whatever is between the left boundary (JSESSIONID=) and the right boundary (;) and
assign to the system variable named {}.



Now whenever you use the {} variable in a subsequent test step, it will be substituted with the last value you parsed:


```
url: http://myserver/search.jsp?value=123&JSESSIONID={}
```


Will be sent to the server as:

`http://myserver/search.jsp?value=123&JSESSIONID=16CD67F723A6D2218CE73AEAEA899FD9`

<br />


## Additional Info

### Parallel Automated Test Execution

WebImblaze can be run in parallel / concurrently with no problem.

The only thing to keep in mind is to be sure to
specify different output locations for each instance of WebImblaze.

```
perl wi.pl test1.test -o output/test1
perl wi.pl test2.test -o output/test2
perl wi.pl test3.test -o output/test3
```

### Advanced Assertions

Since WebImblaze uses regular expressions for the verifypositive and verifynegative assertions, it is possible
to concoct advanced assertions. Unfortunately regular expressions are a complicated topic, so this section
contains some patterns that are easy to apply to your test suites.

#### Advanced assertion - at least n occurrences

Imagine we have a dashboard that contains statistics on jobs processed per day. Say data returned looks like this:

```
01/01/2018 00:35 00:52 67945 589 2
02/01/2018 00:35 00:52 98231 129 9
03/01/2018 00:35 00:52 88331 381 0
04/01/2018 00:35 00:52 76235 239 35

...
```

Statistics for the last 20 days are shown. Note the last 3 numbers for each row, the first number is the number
of jobs processed per day, the second is the number of matches, and the third is the number of failures.

As a bare minimum, in production, there should be at least 10000 jobs processed per day. At least 100 matches
should be made, and there will be 0 or more exceptions. 

We can make a regular expression to match the first row like this: `\d{5,} \d{3,} \d{1,}`

If we want to ensure that there are 20 rows that match this pattern, you could use this test step:

```
step:                   Check job processing dashboard statistics
varREGEX_THAT_GRABS_FIRST_MATCH='\d{5,} \d{3,} \d{1,}
varMINIMUM_OCCURRENCES: 20
varFAILURE_MESSAGE:     Should at {MINIMUM_OCCURRENCES} of at least 10000 jobs processed per day
url:                    http://example.com/JobProcessingDashboard
verifypositive1:        Job Match Dashboard
verifypositive2:        (?:.*?(?>{REGEX_THAT_GRABS_FIRST_MATCH})){{MINIMUM_OCCURRENCES},}?|||{FAILURE_MESSAGE}
```

All you need to do is change the three `var` values.

Note that in this example that back tracking is turned off by the `?>` to prevent catastrophic back tracking.

If your regular expression requires back tracking, then you should remove the `?>`. If you do this you should
modify your target regular expression so that it is more exact, otherwise WebImblaze will hang if it can't find
all occurrences. https://www.regular-expressions.info/catastrophic.html

<br />


## Hints and tips

### Modify a variable using regular expressions

You can use a Perl one-liner by executing a shell command through WebImblaze.

Here is an example using Windows (Linux syntax is likely slightly different).

```
step:  Remove commas from {NUMBER}
shell: echo NUMBER[{NUMBER}] | perl -pe "s/,//g;"
parseresponseNUMBER_WITHOUT_COMMAS: NUMBER\[(\d+)]
```

<br />


### Post a message to a Slack Channel

```
step:           Post result to Slack Channel
url:            https://hooks.slack.com/services/J91AC2JRL/C8RAJAZZQ/iR3q4C19XKmgjggrSuuZxCJ2
postbody:       {"text": "Total Searches Yesterday\n www.example.com: {WEBSITE_SEARCHES}]"}
posttype:       application/json
formatjson:     true
```

<br />


### Conditionally run a test step based on multiple criteria

```
step:               Check we have all statistics
evalHAVE_ALL_STATS: {SEARCHES}&&{BOUNCES}
shell:              REM NOP

step:               Write stats to text file
shell1:             mkdir C:\STATS
shell2:             echo date[{YEAR}{MONTH}{DAY}] searches[{SEARCHES}] bounces[{BOUNCES}] >> C:\STATS\key_website_stats.txt
runif:              {HAVE_ALL_STATS}
```

