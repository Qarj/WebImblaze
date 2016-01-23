#Manual for WebInject version 1.59

Adapted from the original manual written by Corey Goldberg - find it at www.webinject.org

##Table of Contents

###[1.1 - Architecture Diagram](#archdiagram)

###[1.2 - Summary](#archsummary)

##[2 - Configuration](#cfg)

###[2.1 - Configuration File (config.xml)](#cfgfile)

[Proxy Server (proxy)](#cfgproxy)

[User-Agent (useragent)](#cfguseragent)

[HTTP Authentication (httpauth)](#cfghttpauth)

[Base URL (baseurl, baseurl1, baseurl2, baseurl3, baseurl4, baseurl5)](#cfgbaseurl)

[Comments (comment)](#cfgcomment)

[Response Delay Timeout (timeout)](#cfgtimeout)

[Global Retry (globalretry)](#cfgglobalretry)

[Global Jumpbacks (globaljumpbacks)](#cfgglobaljumpbacks)

[Test Only (testonly)](#cfgtestonly)

[Auto Controller Only (autocontrolleronly)](#cfgautocontrolleronly)

[User Defined (userdefined)](#cfguserdefined)

[Auto Assertions (autoassertions)](#cfgautoassertions)

[Smart Assertions (smartassertions)](#smartassertions)

###[2.2 - Test Case Files (specifying in configuration file)](#cfgfilenamescfg)

###[2.3 - Command Line Options and Specifying Alternate Test Case/Config Files](#cfgcmdlineopts)

[Available Command Line Options](#cfgavailopts)

[Passing a Test Case Filename](#cfgpassingfile)

[XPath/XNode](#cfgxpathxnode)

[More Examples of Command Line Usage](#cfgcmdlinexampls)

##[3 - Test Case Setup](#tcsetup)

###[3.1 - Summary](#tcsummary)

###[3.2 - Minimal Example](#tcminexamp)

###[3.3 - Available Parameters](#tcavailparams)

####[3.3.1 - Core Parameters - Learn these first, for most tests these will be enough](#tccore)

[id](#tcparamid)

[description1 description2](#tcparamdesc1)

[method](#tcparammethod)

[url](#tcparamurl)

[posttype](#tcparamposttype)

[postbody](#tcparampostbody)

[verifypositive](#tcparamverpos)

[verifynegative](#tcparamverneg)

[parseresponse](#tcparamparse)


####[3.3.2 - Additional Test Driver Parameters](#tcdriver)

[command command1 ... command20](#tcparamcommand)

[commandonerror](#commandonerror)

[addcookie](#tcparamaddcookie)

[addheader](#tcparamaddheader)

[parms](#tcparamparms)


####[3.3.3 - Additional Assertion Parameters](#tcasserts)

[assertcount](#tcparamassertcount)

[verifyresponsecode](#tcparamvercode)

[verifyresponsetime](#tcverifyresponsetime)

[ignoreautoassertions](#tcignoreautoassertions)

[ignoresmartassertions](#ignoresmartassertions)

[ignorehttpresponsecode](#tcparamignorehttpresponsecode)


####[3.3.4 - Retry Failed Test Step Parameters](#tcretry)

[retry](#tcparamretry)

[retryfromstep](#tcretryfromstep)

[retryresponsecode](#tcparamretryresponsecode)

[restartbrowseronfail](#tcrestartbrowseronfail)

[restartbrowser](#tcrestartbrowser)

[sleep](#tcparamsleep)


####[3.3.5 - Test Response Output Control Parameters](#tcoutput)

[decodequotedprintable](#decodequotedprintable)

[errormessage](#tcparamerrmsg)

[formatjson](#tcparamformatjson)

[formatxml](#tcparamformatxml)

[gethrefs](#gethrefs)

[getsrcs](#getsrcs)

[getbackgroundimages](#getbackgroundimages)

[logastext](#tcparamlogastext)

[logresponseasfile](#tcparamlogresponseasfile)

[section](#tcparamsection)


####[3.3.6 - Parameters to skip test steps depending on target environment](#tcskip)

[liveonly](#tcparamliveonly)

[testonly](#tcparamtestonly)

[autocontrolleronly](#tcparamautocontrolleronly)


####[3.3.7 - Parameters to skip test steps if previous test steps failed](#tcsanity)

[checkpositive](#tcparamcheckpositive)

[checknegative](#tcparamchecknegative)

[checkresponsecode](#tcparamcheckresponsecode)

[sanitycheck](#tcparamsanitycheck)


####[3.3.8 - Parameters to control Selenium WebDriver Test Execution](#tcwebdriver)

[screenshot](#tcparamscreenshot)

[searchimage searchimage1 ... searchimage5](#tcparamsearchimage)

[verifytext](#tcparamverifytext)



###[3.4 - Full Examples](#tcfullexamp)

###[3.5 - Numbering Test Cases and Execution Order](#tcnumcases)

###[3.6 - Parent XML Tags and Attributes (repeating test case files)](#tcxmltags)

###[3.7 - Valid XML and Using Reserved XML Characters](#tcvalidxml)

###[3.8 - Variables and Constants](#tcvarconst)

##[4 - Pass/Fail Criteria](#passfailcrit)

###[4.1 - Verifications](#passfailverf)

###[4.2 - HTTP Response Code Verification](#passfailhttpresp)

###[4.3 - Test Case Pass/Fail Status](#passfailcases)

##[5 - Output/Results/Reporting](#output)

###[5.1 - Results File in HTML format (results.html)](#outputhtml)

###[5.2 - Results File in XML format (results.xml)](#outputxml)

###[5.3 - Results in STDOUT](#outputstdout)

###[5.4 - HTTP Log File (http.log)](#outputhttp)

##[6 - Session Handling and State Management](#sessstate)

###[6.1 - Summary](#sesssummary)

###[6.2 - Cookies](#sesscookie)

###[6.3 - Parsing Response Data & Embedded Session ID's (Cookieless)](#sessid)


<a name="archsoft"></a>
##1 - Software Architecture

<a name="archdiagram"></a>
###1.1 - Architecture Diagram

![Alt text](/images/webinject_arch.png?raw=true "Architecture Diagram")

<a name="archsummary"></a>
###1.2 - Summary

WebInject is a HTTP level test automation tool initiated from the command line. WebInject sends
HTTP GET or POST requests to the target web site (System Under Test), and runs assertions against the response.

<a name="cfg"></a>
##2 - Configuration

<a name="cfgfile"></a>
###2.1 - Configuration File (config.xml)

There is a configuration file named 'config.xml' that is used to store configuration settings for your project.  You can 
use this to specify which test case files to run (see below) and to set some constants and settings to be used by WebInject.

If you use WebInject in console mode, you can specify an alternate config file name by using the option -c or --config. See the 
"Command Line Options" section of this manual for more information.

All settings and constants must be enclosed in the proper tags, and simply need to be added to the config.xml file 
(order does not matter).

Available config settings are:

<br />


<a name="cfgproxy"></a>
####proxy
Specifies a proxy server to route all HTTP requests through.

example: `<proxy>http://127.0.0.1:8080</proxy>`

You can also do proxy authentication like this:

example: `<proxy>http://username:password@127.0.0.1:8080</proxy>`
    
<a name="cfguseragent"></a>

<br />


####useragent
Specifies a User-Agent string to be sent in outgoing HTTP headers.  If this setting is not used, the default 
User-Agent string sent is "WebInject".  A User-Agent string is how each request identifies itself to the web server.

example: `<useragent>Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0)</useragent>`
    
<br />


<a name="cfghttpauth"></a>
####httpauth

Specifies authorization headers to your request for HTTP Basic Authentication.  HTTP provides a simple challenge-response 
authentication mechanism which may be used by a server to challenge a client request and by a client to provide authentication 
information.  This configuration parameter takes a list of 5 colon delimited values that correspond to:
<em>servername:portnumber:realm-name:username:password</em>

example: `<httpauth>www.fakedomain.com:80:my_realm:foo:welcome</httpauth>`

You can use also use NTLM authentication in the following format. You'll need to use Authen::NTLM at least version 1.05 for this to work.

example: `<httpauth>server.companyintranet:80::ntdomain\username:password</httpauth>`

Note: You may include multiple <httpauth></httpauth> elements in your config files to support multiple sets of HTTP 
Authentication credentials.
    
<a name="cfgbaseurl"></a>

<br />


####baseurl
Creates the constant {BASEURL} which can be used in test cases (see 'Variables and Constants' section below).

example: `<baseurl>http://myserver</baseurl>`

<br />


####baseurl1

Creates the constant {BASEURL1} which can be used in test cases (see 'Variables and Constants' section below).  This works
in the same way as the 'baseurl' example above.
 
... and so on up to ...

<br />


####baseurl5
Creates the constant {BASEURL5} which can be used in test cases (see 'Variables and Constants' section below).  This works
in the same way as the 'baseurl' example above.
    
<br />


<a name="cfgcomment"></a>
####comment

Allows you to comment out parts of your config file.  Anything contained within comment tags will not be processed.
(I know it is braindead that we don't allow regular XML-style comments here.. sorry)

example: `<comment>this will be ignored</comment>`

<br />

    
<a name="cfgtimeout"></a>
####timeout
Sets a response delay timeout (in seconds) for every test case.  If the response in any test case takes longer than 
this threshold, the HTTP request times out and the case is marked as failed.  The default timeout if you do not specify one
is 180 seconds.


example: `<timeout>10</timeout>`

Note: This timeout setting may not always work when using SSL/HTTPS.
    
<br />


<a name="cfgglobalretry"></a>
####globalretry
This setting is used along with the retry parameter in a test case. It limits the number of retry attempts in a test run.
For example, consider 3 test cases each set to retry 40 times, along with a globalretry value of 50. If the test run is going
badly, then there will be no more than 50 retry attempts rather than 120.


example: `<globalretry>50</globalretry>`
    
<br />


<a name="cfgglobaljumpbacks"></a>
####globaljumpbacks

Limits the number of times the retryfromstep parameter is followed. Stops tests potentially running forever.

If not present, defaulted to 20.

<br />


<a name="cfgtestonly"></a>
####testonly
Used in conjunction with the testonly test case parameter. If this configuration item is present
and set to any value, the test cases with the testonly parameter set will be run.

example: `<testonly>Allow</testonly>`
To use this feature, specify this value in your test config files, and leave it out of your
config files for your live servers.

In the test step that you only want to run on test environments, specify the parameter `testonly="true"`

<a name="cfgautocontrolleronly"></a>

<br />


####autocontrolleronly
Similar to testonly. Allows you to designate certain servers as an automation controller.
This enables you to specify that certain test steps should only be run from the automation controller.

example: `<automationcontrolleronly>Allow</automationcontrolleronly>`

In the test step that you only want to run on automation controllers, specify the parameter `automationcontrolleronly="true"`

<br />


<a name="cfguserdefined"></a>
####userdefined
You can create your own abitrary config values that can be accessed as constants in the test steps.

```xml
<userdefined> 
    <adminuser>admin@example.com</adminuser> 
    <adminpass>topsecret</adminpass> 
</userdefined>
```

In this example, you would refer to the constants in your test steps as {ADMINUSER} and {ADMINPASS}.

<br />


<a name="cfgautoassertions"></a>
####autoassertions
It is possible to specify assertions that run automatically on every single test step.

A possible usage is to check that you have not obtained an error page.

```xml
<autoassertions> 
   <autoassertion1>^((?!error.stacktrace).)*$|||A java stacktrace has occurred</autoassertion1> 
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


<a name="smartassertions"></a>
#### smartassertions
It is possible to specify assertions that run conditionally on every single test step.

The condition is set as part of the smart assertion.

```xml
<smartassertions> 
   <smartassertion1>Set\-Cookie: |||Cache\-Control: private|Cache\-Control: no\-cache|||Must have a Cache-Control of private or no-cache when a cookie is set</smartassertion1> 
</smartassertions> 
```

In the example above, the condition is specified first, before the `|||`.

The condition in this case is that the `Set\-Cookie: ` regular expression finds at least one
match in the response output.

If the condition is met, then the regular expression after the `|||` is executed.

If one or match is found, then the smart assertion passes (silently). 

If a match is not found, the message after the final `|||` is logged and the test step is failed.

This feature is really useful for asserting that various standards are followed. In the event 
that exceptions are agreed, the ignoresmartassertions parameter can be used.

<br />


<a name="cfgfilenamescfg"></a>
###2.2 - Test Case Files (specifying in configuration file)

One of the configuration 
file settings in config.xml is used to name the test case files which you have created.  You may specify any amount of test case 
files to process by placing each file name inside the proper (<testcasefile>) xml tags.  If there is no configuration setting 
used to name your test case file(s), it will default to using a file named 'testcases.xml' in the current [webinject] directory.  The 
files are processed in the order they appear in your config file.

A configuration file listing 3 test case files to process (tests_1.xml, tests_2.xml, tests_3.xml) may look something like:

```xml
<testcasefile>tests_1.xml</testcasefile>
<testcasefile>tests_2.xml</testcasefile>
<testcasefile>tests_3.xml</testcasefile>
```

Note: You can also use relative path names to point to test case files located in other directories or subdirectories.

<br />


<a name="cfgcmdlineopts"></a>
###2.3 - Command Line Options and Specifying Alternate Test Case/Config Files

WebInject is called from the command line and has several command line options.

Usage:

`webinject.pl [-c|--config config_file] [-o|--output output_location] [-A|--autocontroller] [testcase_file [XPath]]`

&nbsp;&nbsp;&nbsp;or

`webinject.pl --version|-v`

<br />


<a name="cfgavailopts"></a>
####Available Command Line Options

**-c** or **--config**

This option is followed by a config file name.  This is used to specify an 
alternate configuration file besides the default (config.xml).  To specify a config file in a different 
directory, you must use the relative path to it.

Note: relative path from the webinject directory.
**-o** or **--output** : This option is followed by a directory name or a prefix to prepended to the output 
files.  This is used to specify the location for writing output files (http.log, results.html, and 
results.xml).  If a directory name is supplied (use either an absolute or relative path and make sure to 
add the trailing slash), all output files are written to this directory.  If the trailing slash is ommitted, 
it is assumed to a prefix and this will be prepended to the output files.  You may also use a combination 
of a directory and prefix.
                                        
To clarify, here are some examples:


To have all your output files written to the /foo directory: 
`perl webinject.pl -o /foo/`

To have all your output files written to the foo subdirectory under your WebInject home directory:
`perl webinject.pl -o ./foo/`

To create a prefix for your output files (this will create output files named foohttp.log, fooresults.html, 
and fooresults.xml in the WebInject home directory):
`perl webinject.pl -o foo`

To use a combination of a directory and a prefix (this will create output files named foohttp.log, 
fooresults.html, and fooresults.xml in the /bar directory): 
`perl webinject.pl -o /bar/foo`

Note: MS Windows style directory naming also works. 

Note: You must still have write access to the directory where WebInject resides, even when writing output 
elsewhere.
                                        
**-a** or **--autocontroller**

Specifies to run autocontrolleronly testcases.

**-v** or **--version**

Displays the version number and other information.

<br />


<a name="cfgpassingfile"></a>
####Passing a Test Case Filename

When you launch WebInject in console mode, you can optionally supply an argument for a testcase file to run.  It will look for this 
file in the directory that webinject.pl resides in.


`perl webinject.pl mytests.xml`


If no filename is passed from the command line, it will look in config.xml for `testcasefile` declarations.  If no files 
are specified, it will look for a default file named 'testcases.xml' in the current [WebInject] directory.  If none of these are 
found, the engine will stop and give you an error.


Note: If you pass a test case filename from the command line and also have testcasefile declarations in your
config file, the files specified in the config file will not be processed (but all other config options are still used).

<br />


<a name="cfgxpathxnode"></a>
####XPath/XNode

When you pass a test case filename to the WebInject Engine from the command line, you may also specify an extra argument that defines a 
single XPath/XNode.  This will only execute the test case residing in the XPath/XNode you supply.

For example, to run only testcase 2 from your file named mytests.xml, you would call it like this:

`perl webinject.pl mytests.xml testcases/case[2]`

<br />


<a name="cfgcmdlinexampls"></a>
####More Examples of Command Line Usage

Here are some examples to illustrate using webinject.pl from the command line:



1) Launching webinject.pl using the default config file and test case file:


`perl webinject.pl`


2) Launching webinject.pl specifying an alternate test case file and config file:


`perl webinject.pl mytests.xml -c myconfig.xml`


3) Launching webinject.pl from a different directory. As an example, you installed webinject in /usr/local/webinject.  This will  
use defaults config.xml and testcase.xml files located in the same directory as webinject.pl:


`perl /usr/local/webinject/webinject.pl`


4) Launching webinject.pl from a different directory and specifying an alternate test case file and config file. As an example, 
you installed webinject in /usr/local/webinject.  This will use myconfig.xml and mytests.xml files located in the same directory 
as webinject.pl:


`perl /usr/local/webinject/webinject.pl mytests.pl -c myconfig.xml`


4) Launching webinject.pl and specifying a relative path to an alternate testcase file and config file. As an example, you have 
your test case file and config file are located in a subdirectory named 'myfiles':


`perl webinject.pl ./myfiles/mytests.pl -c ./myfiles/myconfig.xml`

<br />


<a name="tcsetup"></a>
##3 - Test Case Setup

<a name="tcsummary"></a>
###3.1 - Summary

Test cases are written in XML files (using XML elements and attributes) and passed to the WebInject engine 
for execution against the application/service under test. This abstracts the internals of WebInject's 
implementation away from the non-technical tester, while using an open architecture [written in Perl] 
for those that require more customization or modifications.

There are several parameters (attributes) you can use in your cases, depending on what you are trying to 
accomplish.  The only required parameters are the 'id' and the 'url'.  If no verification parameters 
(verifypositive, verifynegative, verifyresponsecode, etc) are provided, the test case will be marked as 
"FAILED" if the HTTP request returns an HTTP Response Code that is not in the 100-399 range.  
See the "Pass/Fail Critera" section of this manual for more information.

<br />


<a name="tcminexamp"></a>
###3.2 - Minimal Example

A minimal test case xml file may look something like:

```xml
<testcases repeat="1">

<case
    id="1"
    url="http://myserver/test/test.html"
/>

</testcases>
```

<br />


<a name="tcavailparams"></a>
###3.3 - Available Parameters

<a name="tccore"></a>
###3.3.1 - Core Parameters - Learn these first, for most tests these will be enough

<a name="tcparamid"></a>
####id
Test case identifier used to identify the test case and set its execution order. If you number the test steps like 10, 20, 30...
then it gives you room to insert additional steps (e.g. 15, 25) without having to renumber all the ids.

```
    id="10"
```

<br />    


<a name="tcparamdesc1"></a>
####description1 description2

Text description for results report.
    
```
    description1="Get Search Form"
    description2="(soft logged in)"
```

Both parameters are optional, but it is highly recommended to always use description1.

<br />    


<a name="tcparammethod"></a>
####method
HTTP request method, can be "get" or "post".  This defaults to "get" if the parameter is omitted.

```
    method="get"
```

```
    method="post"
    postbody="txtUsername=admin&txtPassword=password1"
```

A special method of "cmd" is also supported, which will run a shell command through the backtick method. See the
full examples section for an example.

```
    method="cmd"
    command="dir C:\"
```

<br />

    
<a name="tcparamurl"></a>
####url

Full HTTP URL to request.  You can use an IP Address or Host Name.

```
    url="http://www.example.com/search.aspx"
```

<br />

    
<a name="tcparamposttype"></a>
####posttype
This parameter specifies the content type encoding used in submitting a form to the server ("Content-Type" field 
in the HTTP Header).  This is only used in an HTTP POST (method="post").  The possible values are:

```
    posttype="application/x-www-form-urlencoded"
```

```
    posttype="multipart/form-data"
```

```
    posttype="text/xml"
```

```
    posttype="application/soap+xml"
```

```
    posttype="application/json"
```

Defaults to "application/x-www-form-urlencoded" if this parameter is omitted.

<br />


<a name="tcparampostbody"></a>
####postbody
This is the data (body) of the request to be sent to the server.  This is only used in an HTTP POST (method="post").

If you are sending "application/x-www-form-urlencoded" data, this parameter contains the string of text data you wish to send.

```
    method="post"
    posttype="application/x-www-form-urlencoded"
    postbody="txtUsername=admin&txtPassword=password1"
```

If you are sending "multipart/form-data" (used for form-based file upload as specified in RFC 1867), this parameter contains
a string that represents the Perl code used to define the "Content" parameter of the Perl "POST" function. This string
will be evaluated by the Perl interpreter using "eval".  More details about the syntax can be found in the Perl documentation
of the HTTP::Request::Common module.

```
    method="post"
    posttype="multipart/form-data" 
	postbody=" ( 'companyName' => 'Example', 'companyId' => '55201', 'companyLogo' => ['testdata\logos\Example.jpg'] ) "
```

When sending JSON, you may need to change the overall quotes from double quote to single quote so you can use double
quotes within the postbody itself for the JSON.

```
    method="post"
    posttype="application/json"
    postbody='{"application": "search", "searchtype": "postcode", "criteria": "WC1X 8TG"}'
```


If you are sending "text/xml" or "application/soap+xml" (used for web services), this parameter contains a link to an external file 
that contains the text (xml payload) that will be sent in the body of your request.  This is done using the `file=>` syntax.
Example: `postbody="file=>soap_payload.xml"`

```
    method="post"
    posttype="text/xml"
    postbody="file=>testdata\GetJobs.xml"
    addheader='SOAPAction: "http://www.example.com/ns/1.0/GetNewJobs"'
```

<br />


<a name="tcparamverpos"></a>
####verifypositive
String in response for positive verification. Verification fails if this string does not exist in the HTTP response.  This is matched 
as a Perl regular expression, so you can do some complex verification patterns if you are familar with using regex matching.  

You can also specify that a custom message be output if the verification fails by placing ||| then your message on the right hand side
of the verifypositive. This is really useful if you need to verify a number of really cryptic strings in a test case. You are able
to specify a custom message for each verification that fails. See the examples.

Example - check for "Saved OK" in response:
`verifypositive='Saved OK'`

Example - check for various webtrends tags in response, and output a custom message if it isn't found:

```
    verifypositive='WT897234|||Webtrends Profile Saved tag not found'
    verifypositive1='WT897264|||Webtrends New User tag not found'
    verifypositive2='WT897292|||Webtrends Full Profile tag not found'
```

Note: Because your verification string is used as a regex, the following characters within it must be escaped with a
backslash:  `{}[]()^$.|*+?\`

You can have as many verifypositive parameters as you want, so long as they start with verifypositive. For example, you can have
verifypositive20, verifypositive5000, verifypositiveHTML or whatever.

It is also possible to disable an assertion without removing it. This is useful if you have a temporary problem. You do this by adding
another three `|||` and writing any message after the custom error message.

```
    verifypositive="Record 5520|||Record 5520 is within 15 miles so should show|||Production Bug"
```

<br />
   
    
<a name="tcparamverneg"></a>
####verifynegative
String in response for negative verification. Verification fails if this string exists in the HTTP response.  This is matched 
as a Perl regular expression, so you can do some complex verification patterns if you are familar with using regex matching.  

Note: Because your verification string is used as a regex, the following characters within it must be escaped with a
backslash:  `{}[]()^$.|*+?\`

As per verifypositive, you can have as many verifynegatives as you want, so long as they all start with verifynegative.

```
    verifynegative="The system cannot find the file specified"
    verifynegative1="OutOfMemoryException"
```

And also as per verifypositive, you can specify a custom message if that verification fails.

```
    verifynegative="additional-search-results-btn|||Additional Search Results button should not be shown"
```

As with verifypositive, it is possible to disable a negative assertion without removing it. You do this by adding
another three `|||` and writing any message after the custom error message.

```
    verifynegative="Record 5550|||Record 5550 is across county border - should not show|||Bug introduced with build 15221"
```

<br />


<a name="tcparamparse"></a>
####parseresponse
Parse a string from the HTTP response for use in subsequent requests.  This is mostly 
used for passing Session ID's, but can be applied to any case where you need to pass a 
dynamically generated value.  It takes the arguments in the format 
"leftboundary|rightboundary", and one of two optional third arguments.

Use "leftboundary|rightboundary|escape" when you want to force escaping of all 
non-alphanumeric characters. See the "Session Handling and State 
Management - Parsing Response Data &amp; Embedded Session ID's" 
section of this manual for details and examples on how to use this parameter.

Use "leftboundary|rightboundary|decode" when you want to decode html entities - for example
converting &amp;amp; back to &amp; and &amp;lt; back to < - which you may need to do in some circumstances.

If you specify the text "regex" as the right boundary, the left boundary will be treated as a custom regular expression.

Note: You will need to prepend a backslash before these reserved characters when parsing:
`{}[]()^$.|*+?\`


Note: Newlines (\n) are also valid boundaries and are useful when you need to use the end of the line as a boundary.

Example - match from the first instance of START until END is found:
```
    parseresponse='START|END|'
```

Example - match from the first instance of START until END is found, then escape the matched text:
```
    parseresponse='START|END|escape'
```

Example - custom regex - parsed characters are the ones matched inside the parentheses:
```
    parseresponse='a id="\w*" class="first" href="/careers-advice/(\d*)"|regex|escape'
```

Example - when what we know is on the RHS - this method extracts option values:
```
    parseresponse='option value="([0-9]+)".AutoTESavedSearch1|regex|escape'
```

Example - Will find user@example.com in a response containing <email>user@example.com</email>
```
    parseresponse='email.([^\<]+)|regex|'
```

Example - the {5,60} specifies that the number of characters matched must be between 5 and 60:
```
    parseresponse='name="(.{5,60}?)"|regex|'
```

Example - in this regex, the .* at the front tells it to return the last match, rather than the first:
```
    parseresponse='.*UserId="(.*?)"\<|regex|'
```

Example - match a date in 31/12/2010 format (will also match invalid dates like 42/79/2010):
```
    parseresponse='([\d][\d]/[\d][\d]/[\d]{4,4})|regex|'
```

Example - match the ctl number for a field:
```
    parseresponse='ctl(\d\d).ctl00.btnApplyOnline|regex|'
```

Example - match a Guid in format "91072487-558b-43be-a981-00b6516ef59c"
```
    parseresponse="[a-z0-9\-]{36,36}?|regex|"
```

**Referencing the results of a parseresponse in later test steps**

`parseresponse1` would be referred to as `{1}`,  `parseresponse5000` as `{5000}` and `parseresponseUSERID` as
`{USERID}`. `parseresponse` is referred to simply with `{}`.

Full Example - parse the redirect location from the response header
```xml
<case
    id="50"
    description1="Search for WebDriver Jobs"
    method="get"
    url="http://www.example.com/JobSearch/Results.aspx?Keywords=WebDriver"
    parseresponseREDIRECT="Location: |\n|decode"
/>

<case
    id="60"
    description1="(redirect) Get search results"
    method="get"
    url="http://www.example.com{REDIRECT}"
/>
```

You can have as many parseresponses as you want, so long as they all start with parseresponse. Examples are
parseresponse1, parseresponse5000 and parseresponseUSERID.

<br />


<a name="tcdriver"></a>
###3.3.2 - Additional Test Driver Parameters

<a name="tcparamcommand"></a>
####command command1 ... command20
Used with method="cmd". Allows you to run a OS level command using the backtick method in Perl.

```xml
    command="type test_data_file.txt"
    parseresponseUSERNAME='USERNAME5="|"|'
    parseresponsePASSWORD='PASSWORD5="|"|'
```

Also used with method="selenium" for the Selenium 2.0 / WebDriver test steps.

It is even possible to run a line of Perl code in the current context.
Note that in this example three types of quotes are used on the one line:

```
    command='$selresp = $sel->find_element(qq|input[type="submit"]|,qq|css|)->click();'
```

In this last example, qq| is indicating that | should be used as a quote in this line of Perl code.

<br />


<a name="commandonerror"></a>
####commandonerror

Will run the specified command only if the test step fails for some reason.

```
    commandonerror="emailsupportteam.bat"
```

<br />


<a name="tcparamaddcookie"></a>
####addcookie

This is used to add an additional cookie to an outgoing HTTP request without overwriting the existing cookies.
The cookie will be added for the current step only.

```
    addcookie="LASTVIEWEDJOB_COOKIE=4830075"
```

<br />


<a name="tcparamaddheader"></a>
####addheader

This is used to add an addition header to an outgoing HTTP request.

```
    addheader="SOAPAction: urn:example-org:demos#Method"
```

```
    addheader="Cookie: SoftLoggedInCookie=${SOFT_LOG_COOKIE}; MobileWebsite=1"
```

You may add multiple headers, separating each with a pipe character.

```
    addheader="Foo: bar|Boo: far"
```

Note that when you use addheader, any existing header cookies will be clobbered.

<br />


<a name="tcparamparms"></a>
####parms

Subtitutes dummy fields in an xml file with actual values. Used in conjunction with posting an xml file, as in a SOAP request.

```
    parms="__SALMIN__={SALMIN}&__SALMAX__={SALMAX}"
```

Allows you to create a xml template file then easily substitute in dynamic values at test run time.

**Full Example:**
```xml
<case
    id="40"
    description1="Add Unique Job"
    url="https://www.example.com/XMLJobLoad/jobloader.aspx"
    method="post"
    postbody="file=>testdata\AddJob.xml"
    posttype="text/xml"
    parms="__SALMIN__=20000&__SALMAX__=35000"
    verifypositive1="Job Loaded Successfully"
    logastext="true"
/>
```

testdata\AddJob.xml might look like:
```xml
<?xml version="1.0" encoding="ISO-8859-1" ?>
<FILE>
	<JOB	
		JOBID="333211"
		TITLE="Test Automation Engineer"
		DESCRIPTION="Great new test automation opportunity"
		LOCATION="London"
		SALARYTYPE="ANNUAL"
		SALARYMIN="__SALMIN__"
		SALARYMAX="__SALMAX__"
		SALARYDESC="Great Benefits" 
	/>
</FILE>
```

When you run the test, the __SALMIN__ and __SALMAX__ placeholders will be swapped with
20000 and 35000 respectively.

<br />


<a name="tcasserts"></a>
###3.3.3 - Additional Assertion Parameters

<a name="tcparamassertcount"></a>
####assertcount
Used to assert that the specified text only appears a given number of times within the reponse. Can optionally give a custom message
if the assertion fails.

```
    assertcount="Distance:|||1|||Should only be one job shown"
```

You can have as many assertcount parameters as you want.

```
    assertcount5000="Distance:|||1|||Should only be one job shown"
```

```
    assertcountDISTANCE="Distance:|||1|||Should only be one job shown"
```


`assertcount` can be disabled without removing it. You do this by adding
another three `|||` and writing any message after the custom error message.

```
    assertcount="uniquedata1092311|||2|||Expect 2 records only|||Production Bug"
```

<br />


<a name="tcparamvercode"></a>
####verifyresponsecode
HTTP response code for verification. Verification fails if the HTTP response code you specified does not match the HTTP response
code you receive.

```
    verifyresponsecode="500"
```

<br />


<a name="tcverifyresponsetime"></a>
####verifyresponsetime
Asserts that the response time is no greater than the specified time.

```
    verifyresponsetime="2.505" 
```

In this example, the assertion will fail if the response time is greater than 2.505 seconds.

<br />


<a name="tcignoreautoassertions"></a>
####ignoreautoassertions
```
    ignoreautoassertions="true"
```

Enables you to turn off the auto assertions for various test cases when needed.

See the config file section for information on auto assertions.

<br />


<a name="ignoresmartassertions"></a>
#### ignoresmartassertions
```
    ignoresmartassertions="true"
```

Enables you to turn off the smart assertions for various test cases when needed.

See the config file section for information on smart assertions.

<br />


<a name="tcparamignorehttpresponsecode"></a>
####ignorehttpresponsecode
```
    ignorehttpresponsecode="true"
```

Normally we automatically fail a test step if the http response code wasn't in the 100-399 range.
Specifying this parameter allows us to ignore this verification.

<br />


<a name="tcretry"></a>
###3.3.4 - Retry Failed Test Step Parameters

<a name="tcparamretry"></a>
####retry

This is used to retry a test case that has failed. You specify the maximum number of times
to retry the test case. Use this parameter if you need to wait for a database to update in
an asynchronous manner, but you don't know how long it will take.

```
    retry="5"
```

You normally would use this parameter in conjunction with the sleep parameter so that there is a pause
before the test case is tried again.
 
In this example, if any of the verifypositives fail, or the assertcount fails, then WebInject
will wait 5 seconds, then retry the test step - up to 10 times. (After each failure, WebInject will
wait 5 seconds.) If and when the test step passes, WebInject will not wait 5 seconds before proceeding.
```
    retry="10"
    sleep="5"
```

If one of the verifynegatives fail, the test case will not be retried further. The logic is that you are
prepared to wait for something you expect to see (verifypositive etc), but if you find something you 
don't want to see (like an error page), there is no point retrying further. This is called fail fast.

If you do want to do a retry on a verifynegative, encode it as a verifypositive instead. The following example
shows how to do this: 
```
    verifypositive20="^((?!ErrorPage.aspx).)*$|||Error detected"
```

Note that you can specify a global retry limit to prevent more than a specified number of retries
in a run. This is useful if you would like to specify the retry parameter in many test cases. If, when running,
things are going badly, the global limit will be enforced preventing your test run from taking
(seemingly) forever. See the Configuration File section to see how to set this up.

<br />

<a name="tcretryfromstep"></a>
####retryfromstep
Works in much the same way as the `retry` paramater, however execution will continue from the specified step
rather than the current step.

```xml
<case
    id="10"
    description1="Get Home page"
    url="http://{BASEURL}"
    method="get"
    verifypositive="Please log in"
/>

<case
    id="20"
    description1="Submit login details"
    url="http://{BASEURL}"
    method="post"
    postbody="username=admin&password=12345"
    verifypositive="Welcome admin"
    retryfromstep="10"
/>
```

In this example, if the message "Welcome admin" is not found, then execution will continue from step 10
without failing step 20. This will continue to happen until "Welcome admin" is found, or up to the
globaljumpbacks setting in the config file (defaulted to 20 if not present).

<br />


<a name="tcparamretryresponsecode"></a>
####retryresponsecode
If a retry is present, retry if we get this reponse code, even if it is an error code.

When we retry, we normally give up instantly if we receive an error code in order to "fail fast".
However sometimes we need to override this behaviour.

```
    retryresponsecode="500"
```

<br />


<a name="tcrestartbrowseronfail"></a>
####restartbrowseronfail
When present, will restart the WebInject session if any of the verifications fail.

If a Selenium WebDriver browser session is also present, that will be restarted too.

```
    restartbrowseronfail="true"
```

This has the effect of dumping all cookies and getting the session back to a known state.

This is particularly important if you are trying to log in and something went wrong. It could be
that you are logged in successfully, but something else went wrong so you need to retry the test case
from a not logged in state.

```xml
<case
    id="20"
    description1="Submit login details"
    url="http://{BASEURL}"
    method="post"
    postbody="username=admin&password=12345"
    verifypositive="Welcome admin"
    retryfromstep="10"
    restartbrowseronfail="true"
/>
```

<br />

<a name="tcrestartbrowser"></a>
####restartbrowser
Will restart the WebInject session after execution of the current step.

If a Selenium WebDriver browser session is also present, that will be restarted too.

```
    restartbrowser="true"
```

All cookies will be dumped.

<br />


<a name="tcparamsleep"></a>
####sleep

Number of seconds to sleep after the test case.  This used to add spacing between cases in order to 
throttle the rate it sends requests.

Sleep 5 seconds before proceeding:
```
    sleep="5"
```

Since there is a retry parameter present in this example, WebInject will only sleep 5 seconds
if the test step fails any of the verifypositives or the assertcount.
```
    sleep="5"
    retry="5"
```


<br />


<a name="tcoutput"></a>
###3.3.5 - Test Response Output Control Parameters

<a name="decodequotedprintable"></a>
####decodequotedprintable

Decodes a quoted-printable response and replaces the response with the decoded version. The decoded
version will be available to the parseresponse parameter.

```
    decodequotedprintable="true"
```

Note: This feature was added to deal with intermediate email files in quoted-printable format.

<br />


<a name="tcparamerrmsg"></a>
####errormessage
If a test case fails, this custom 'errormessage' will be appended to the 'TEST CASE FAILED' line 
(on STDOUT and the HTML Report). This may be useful to give a bit more information on what a failed 
test means, like "couldn't connect to the application" or "couldn't access the login page".

```
    retry="20"
    sleep="5"
    errormessage="Job still not in index after 20 tries, perhaps indexer is offline"
```

<br />


<a name="tcparamformatjson"></a>
####formatjson

Improves readability of json responses.

```
    formatjson="true"
```

Inserts carriage returns at various places using a simple regular expression.

<br />


<a name="tcparamformatxml"></a>
####formatxml

Improves readability of xml responses.

```
    formatxml="true"
```

Sometimes when you receive a response in xml format, the response comes back without a single carriage return. It can be difficult to read. 
Specifying this parameter puts a carriage return between every >< found in the response.

<br />


<a name="gethrefs"></a>
####gethrefs

Gets the hrefs referred to in the html response, and writes them to the output folder.

Multiple patterns are separated with a `|`. The pattern specifies the end of the filenames to match. 

```
	gethrefs=".css|.less"
```

<br />


<a name="getsrcs"></a>
####getsrcs

Gets the srcs referred to in the html response, and writes them to the output folder.

Multiple patterns are separated with a `|`. The pattern specifies the end of the filenames to match. 

```
	getsrcs=".jpg|.png|.js"
```

<br />


<a name="getbackgroundimages"></a>
#### getbackgroundimages

Gets the background images referred to in the html response, and writes them to the output folder.

Multiple patterns are separated with a `|`. The pattern specifies the end of the filenames to match. 

```
    getbackgroundimages=".jpg"
```

This will match css background images that look like this in the html source:

```
<div style="background-image: url(/site-assets/teacup.jpg);" class="product-image item active"></div>
```

<br />


<a name="tcparamlogastext"></a>
####logastext

Putting this paramater on a test case will put tags around the test case in http.log file.

```
    logastext="true"
```

This is useful if you parse the http.log into separate .html files and attempt to render it in the browser. This
parameter lets you mark particular test cases to treat as text output (e.g. SOAP or AJAX tests) so that you render it as plain text rather
than html.

<br />


<a name="tcparamlogresponseasfile"></a>
####logresponseasfile

Saves the test step response in a file.

Example:

```xml
<case
    id="2050"
    description1="Get Responsive.css"
    method="get"
    url="https://www.example.com/resources/css/Responsive.css"
    logastext="true"
    logresponseasfile="Captured.css"
/>
```

<br />


<a name="tcparamsection"></a>
####section

Indicates in the results.xml that a section break occurs before this test.

Use in your Test Automation Framework when displaying the results.xml with a stylesheet.

```
    section="Ensure it is not possible to apply for the same job twice"
```
<br />


<a name="tcskip"></a>
###3.3.6 - Parameters to skip test steps depending on target environment

<a name="tcparamtestonly"></a>
####testonly

If you run your test cases against both test and live environments, you can specify that selected
test cases are skipped when run against your live config file. See the configuration file section
for information on how to configure the config file.

```
    testonly="true"
```

In your config.xml, you would have the following line:

```xml
    <testonly>Allow</testonly> 
```

<br />

<a name="tcparamliveonly"></a>
####liveonly

Works exactly the same was as testonly.

```
    liveonly="true"
```

In your config.xml, you would have the following line:

```xml
    <liveonly>Allow</liveonly> 
```

<br />


<a name="tcparamautocontrolleronly"></a>
####autocontrolleronly

You can flag test cases as being "autocontrolleronly". Then when you invoke webinject, specify
a command line option to indicate you are invoking it from the automation controller. Webinject will
then run test cases flagged as being "autocontrolleronly", which will otherwise be skipped.

```
    autocontrolleronly="true"
```

It is probably quite rare that you would have a need for this feature. One example is that you may have a
website that accepts document uploads. Your webserver may check the uploaded documents for viruses. To test that
this works, you might have a test case that uploads a document containing an industry standard test virus.
However your organisation may have stringent virus checking that deletes any file suspected of containing a virus
immediately. You might be able to negotiate an exemption to virus checking for a particular file on your automation
controller. So with this feature you can skip the test cases in your regression pack on your workstations, but still run
the virus checking test cases on your automation controller. This is a real example of how this feature is used.

When you start WebInject, you will need to specify the -a parameter, otherwise test steps with the autocontrolleronly
parameter will be skipped:
```
webinject.pl -a
```

<br />


<a name="tcsanity"></a>
###3.3.7 - Parameters to skip test steps if previous test steps failed

<a name="tcparamcheckpositive"></a>
####checkpositive

```
    checkpositive="8"
```

In this example, this test step will not be run, unless the most recent verifypositive8 passed.
Allows us to skip test steps where we know they will fail since a previous dependent step failed.

<br />


<a name="tcparamchecknegative"></a>
####checknegative

```
    checknegative="3"
```

In this example, this test step will not be run, unless the most recent verifynegative3 passed.

<br />


<a name="tcparamcheckresponsecode"></a>
####checkresponsecode
```
    checkresponsecode="200"
```

In this example, this test step will not be run, unless the responsecode of the previous test
step was 200 (if that test step was run).

<br />


<a name="tcparamsanitycheck"></a>
####sanitycheck

Used to fail a test run early. If you specify the sanitycheck parameter on a test case, and the
test case fails, or any previous test has failed, then the test run is aborted.

This feature is very useful if your automation regression suite takes a long time to run. If a very basic test,
like getting the home page, fails, then there little point running the rest of the tests.

```
    sanitycheck="true"
```

<br />


<a name="tcwebdriver"></a>
###3.3.8 - Parameters to control Selenium WebDriver Test Execution

<br />

<a name="tcparamscreenshot"></a>
####screenshot
```
    screenshot="false"
```

Normally for the WebDriver test steps, we take a full page grab for evey single step. Unfortunately the
pagegrab is rather slow and takes about 1 second to do, slowing down test execution.

By specifying this parameter, a page grab will not be taken. Instead, a very fast screenshot of the visible
portion of the web page will be taken. This fast screenshot will only be taken for interactive sessions. If the test
is being run by a service account, there is no window handle with which to work with.

<br />


<a name="tcparamsearchimage"></a>
####searchimage searchimage1 ... searchimage5

Searches the WebDriver pagegrab or screenshot for a specified subimage. A small tolerance is allowed in case
the image cannot be found exactly. This is useful if the baseline image is captured in one browser version /
operating system, but tested on another.

```
    searchimage="RunningMan_Company_Logo.png"` 
```

The subimages are stored in a folder named baseline under the testcases folder. The specific imagie is in an addtional
subfolder that has the same name as the testcase you are running. 

For example, refering to the example above, RunningMan_Company_Logo.png can be found at
```
    mywebinjectestsfolder\baseline\mytestname\RunningMan_Company_Logo.png
```

<br />


<a name="tcparamverifytext"></a>
####verifytext
Fetches from WebDriver / Selenium the details you specify. Used in conjuction with a verifypostive or verifynegative.
Or perhaps you just want those details to appear in the http.log.

Separate additional items with commas. Example:

```
    verifytext="get_active_element,get_all_cookies,get_current_url,get_window_position,get_body_text,get_page_source"
```
 
<br />


<a name="tcfullexamp"></a>
###3.4 - Full Examples

Sample test case file using multiple parameters:

```xml
<testcases repeat="1">

<case
    id="10"
    description1="short description"
    description2="long description"
    method="post"
    url="http://myserver/test/login.jsp"
    postbody="username=corey&amp;password=welcome"
    verifypositive="verify this string exists"
    verifynegative="verify this string does not exist"
    sleep="3"
/>

<case
    id="20"
    description1="short description"
    description2="long description"
    method="get"
    url="http://myserver/test/send.jsp?value={TIMESTAMP}"
    verifypositive="verify this string exists"
/>

</testcases>
```

Here is a sample test case showing a "multipart/form-data" encoded form-based file upload:

```xml
<case 
    id="10" 
    description1="sample test case - POST" 
    description2="verify file upload" 
    method="post" 
    url="http://cgi-lib.berkeley.edu/ex/fup.cgi" 
    postbody="( upfile => ['config.xml'], note => 'MYCOMMENT' )" 
    posttype="multipart/form-data" 
    verifypositive="MYCOMMENT" 
/>
```


Here is a sample test case showing usage of the "cmd" method:


```xml
<case 
    id="10"
    description1="Prepare JobFile with unique ids that will be accessible from webinject"
    method="cmd"
    command="ssed -e s/__TIME__/{STARTTIME}/g testdata\JobFileTemplate.xml > {OUTPUT}JobFile.xml"
/>
```

<br />


<a name="tcnumcases"></a>
###3.5 - Numbering Test Cases and Execution Order

Test Cases are numbered using the `id=` parameter.  They will be sorted and executed in sequential order based on 
these numbers, not the physical position of the Test Case within your file.  You are allowed to leave gaps in the 
numbering and have them in any order in the file.

<br />


<a name="tcxmltags"></a>
###3.6 - Parent XML Tags and Attributes (repeating test case files)

Make sure your entire set of test cases is wrapped with the proper parent tags:


Your file should begin with:

`<testcases>`


and end with:

`</testcases>`


There is also a "repeat" attribute you can set within the parent tag to specify the number of times you would 
like a file of test cases to run.


For example, to have a test case file run 5 times, your file should open with:

`<testcases repeat="5">`

<br />


<a name="tcvalidxml"></a>
###3.7 - Valid XML and Using Reserved XML Characters

You may only use valid XML in your test cases.  Malformed XML or mixed content will not be accepted by the parser 
that is used to read the test cases.


However, you may find it necessary to use such characters within an XML Attribute to define your test case.  Most 
of these situations are handled programmatically behind the scenes for you as a user.  For example, the "&amp;" 
character would normally not be acceptable to an XML parser since it is a reserved character.  Since this character 
is used in URL query strings (which are necessary in many/most test cases), it is handled as a special case and you 
may use them within your test case XML.


There are two special cases to be aware of:

####less than (<) character:

Anywhere you use this character in your test cases (except of course, enclosing your actual XML tags), you must escape it 
with a backslash (failure to do so will make the test case parser croak).


For example, the following testcase parameter will not work like this:

```
    verifypositive="<OPTION SELECTED>APPLE"
```


Instead, it should be written like:

```
    verifypositive="\<OPTION SELECTED>APPLE"
```

Or you could just leave it out altogether for a cleaner look:

```
    verifypositive="OPTION SELECTED>APPLE"
```

In fact you can get away with just writing a dot instead of any special character.
In regular expressions, a single dot, i.e. `.` will match any single character.

```
    verifypositive="OPTION SELECTED.APPLE"
```

<br />


####quotes (single or double):

If you need to use quotes anywhere within a test case parameter, you need to 
make sure that the quotes are nested properly.  The quotes (single or double) 
used to encapsulate your attribute must be different from the quotes you use within 
your attribute (both single and double quotes are valid to encapsulate an XML attribute).


For example:

```
    verifypositive=" "this" "
```

will not work.

```
    verifypositive=' 'this' '
```

will not work.

```
    verifypositive=" 'this' "
```

is valid.

```
    verifypositive=' "this" '
```

is also valid.

<br />


<a name="tcvarconst"></a>
###3.8 - Variables and Constants

Certain constants and variables can be passed from your test cases to the WebInject engine.  They may be used in a test case 
as a keyword contained within curly braces, and are evaluated/substituted at runtime.

The first set of variables are the most dynamic. They can change each time a test case is retried as
a result of the invocation of the `retry` parameter.

Dynamic Variable | Description
:--------------- | :----------
**{RETRY}** | How many times the current test case has been retried. E.g. 0, 1, 2, 3 ...
**{ELAPSED_SECONDS}** | Elapsed seconds so far - always rounded up
**{ELAPSED_MINUTES}** | Elapsed minutes so far - always rounded up
**{NOW}** | Current date and time in format day/month/year_hour:minute:second

<br />


The next set of variables can hold different values between test cases, but will not change
between retries while a test case is being run.

Variable | Description
:------- | :----------
**{TIMESTAMP}** | Current timestamp (floating seconds since the epoch, accurate to microseconds)
**{TESTNUM}** | Id number of the current test step
**{LENGTH}** | Length of the response for the previous test step
**{TESTSTEPTIME:510}** | Latency for test step number 510
**{COUNTER}** | What loop number we are on - corresponding to the `repeat="5"` (say) parameter at the start of the test steps
**{JUMPBACKS}** | Number of times execution has jumped back due to invocation of `retryfromstep` parameter
**{}** | Result of the response parsing from a `parseresponse` test case parameter
**{1}** | Result of the response parsing from a `parseresponse1` test case parameter
**{5000}** | Result of the response parsing from a `parseresponse5000` test case parameter
**{ANYTHING}** | Result of the response parsing from a `parseresponseANYTHING` test case parameter

(See the "Parsing Response Data & Embedded Session ID's" section for details and examples on how to use these variables
created by means of a `parseresponse`.)

<br />


The values of the constants are set at the run start time. They will not change while the test case file is being run. 

Constant | Description
:------- | :----------
**{STARTTIME}** | WebInject start time, similar to {TIMESTAMP} - but remains constant during a run
**{AMPERSAND}** | Gives you a &
**{LESSTHAN}** | Gives you a <
**{SINGLEQUOTE}** | Gives you a '
**{DAY}** | The day of the month at run start with leading 0, e.g. 06 [denoting the 6th]
**{MONTH}** | The month number of the year at run start with leading 0, e.g. 05 [denoting May]
**{YEAR}** | The year at run start as 4 digits, e.g. 2016
**{YY}** | The year at run start as 2 digits, e.g. 16
**{HH}** | The run start hour in 24hr time with leading 0, e.g. 15 
**{MM}** | The run start minute with leading 0, e.g. 09
**{SS}** | The run start second with leading 0
**{WEEKOFMONTH}** | The run start week number of month with leading 0 e.g. 05 [fifth week of the month]
**{DATETIME}** | The run start date and time without formatting - yearmonthdayhourminutesecond
**{FORMATDATETIME}** | The run start date and time with formatting - day/month/year_hour:minute:second
**{CWD}** | Current working directory
**{OUTPUT}** | WebInject output directory name, or "no output" if output is suppressed
**{HOSTNAME}** | Name of the computer currently running WebInject
**{CONCURRENCY}** | Output folder name only - not the full path
**{OUTSUM}** | Output folder name turned into a 32 bit checksum. Helps with concurrency since two instances of webinject running in parallel should not be outputing to the same folder 
**{TESTFILENAME}** | Test file name
**{OPT_PROXYRULES}** | What proxyrules option was specified via the command line to webinject.pl
**{OPT_PROXY}** | What proxy option was specified via the command line to webinject.pl
**{BASEURL}** | Value of `baseurl` specified in your config file
**{BASEURL1}** | Value of `baseurl1` specified in your config file
**{BASEURL2}** | Value of `baseurl2` specified in your config file
**{BASEURL3}** | Value of `baseurl3` specified in your config file
**{BASEURL4}** | Value of `baseurl4` specified in your config file
**{BASEURL5}** | Value of `baseurl5` specified in your config file

**{BASEURL} Example:**

If you a have a test case that uses the parameter:
```
    url="http://myserver/test/login.jsp"
```

You could create this line in your config.xml file:
```
    <baseurl>http://myserver</baseurl>
```

You can then rewrite the test case parameter as:
```
    url="{BASEURL}/test/login.jsp"
```

This is helpful if you want to point your tests at different environments by changing a single setting.

<br />


####Setting Variables/Constants Within Test Case Files:

You may also set constants in your test case file that you can reference from your test cases.  This makes it 
convenient to change data in a single place that is easy to reference from multiple test cases. 


The following example of a test case file shows how you can use them:

```xml
<testcases repeat="1">

    <testvar varname="LOGIN_URL">http://myserver/login.php</testvar>

    <testvar varname="LOGIN1">bob</testvar>
    <testvar varname="PASSWD1">sponge</testvar>
    <testvar varname="SUCCESSFULL_TEST_TEXT">Welcome Bob</testvar>
     
    <case
        id="1"
        description1="login test case"
        description2="verify string login"
        method="post"
        url="${LOGIN_URL}"
        postbody="login=${LOGIN1}&amp;passwd=${PASSWD1}"
        verifypositive="${SUCCESSFULL_TEST_TEXT}"
    />

</testcases>
```

<br />

<a name="passfailcrit"></a>
##4 - Pass/Fail Criteria


<a name="passfailverf"></a>
###4.1 - Verifications


In each test case, you can set Verifications that will pass or fail depending on the existence of a specified text string 
(or regex) in the content of the HTTP response you receive.

`verifypositive` - This Verification fails if the string you specified does not exist in the HTTP response you receive.

`verifynegative` - This Verification fails if the string you specified exists in the HTTP response you receive.


`verifypositive5000`, `verifypositiveANYTHING`, `verifynegative1234`, `verifynegativeWHATEVERYOUWANT`,  
work the same way.

<br />


<a name="passfailhttpresp"></a>
###4.2 - HTTP Response Code Verification

In each test case, you can set a Verifications that will pass or fail depending on the HTTP response code.

`verifyresponsecode` - This Verification fails if the HTTP response code you specified does not match the HTTP response code 
you receive.

If you do not specify this test case parameter, the HTTP Response Code Verification is marked as "Failed" if the HTTP request 
returns an HTTP response code that is not in the success range (100-399).  It is marked as "Passed" if the HTTP 
Response Code is in the success range (100-399).

If you are testing an error page, you will need to use this parameter.

```
    verifyresponsecode="404"
```

```
    verifyresponsecode="500"
```

<br />


<a name="passfailcases"></a>
###4.3 - Test Case Pass/Fail Status

If any of the Verifications defined within a test case fail, or if the HTTP Response Code Verification fails,
the test case is marked as "FAILED".  If all of the Verifications defined within a test case pass, and the 
HTTP Response Code Verification passes, the test case is marked as "PASSED".  These items are updated in 
real-time during execution.

<br />


<a name="output"></a>
##5 - Output/Results/Reporting

<a name="outputhtml"></a>
###5.1 - Results File in HTML format (results.html)

An HTML file (results.html) is generated to display detailed results of the test execution.
It is written into the WebInject output folder and is overwritten each time the tool runs.

The file contains data passed from the test case file (test case identifiers/descriptions, etc) as 
well as information generated from the test engine (test case pass/fail status, execution times, etc).

<br />


<a name="outputxml"></a>
###5.2 - Results File in XML format (results.xml)

An XML file (results.xml) is generated to display results of the test execution.
It is written into the directory that WebInject runs from and is overwritten each time the tool runs.

The file contains data passed from the test case file (test case identifiers/descriptions, etc) as 
well as information generated from the test engine (test case pass/fail status, execution times, etc).

If you put an xsl stylesheet against this file, you can get a customised display of the test run results.

<br />


<a name="outputstdout"></a>
###5.3 - Results in STDOUT

Results are also sent [in plain text format] to the STDOUT channel as the tests execute.

<br />

<a name="outputhttp"></a>
###5.4 - HTTP Log File (http.log)

A log file (http.log) is generated to capture HTTP requests that are sent to the web server of the system 
under test and HTTP responses that are received from the system under test.  Whether or not HTTP logging is 
turned on depends on a setting in the configuration file and if you have logging parameters turned on in each 
test case.  See the "Configuration - Configuration File (config.xml)" and "Test Case Setup - Available Parameters"
sections of this manual for more information on logging to the http.log file.

Note: "Content-Length" and "Host" HTTP headers are automatically added to outgoing HTTP POST requests, but are not shown in http.log.  

<br />


<a name="sessstate"></a>
##6 - Session Handling and State Management


<a name="sesssummary"></a>
###6.1 - Summary

HTTP is a stateless protocol, meaning each request is discrete and unrelated to those that precede or follow.  Because of the 
stateless nature of the protocol itself, web applications or services use various other methods to maintain state.  This allows 
client connections to be tracked and connection-specific data to be maintained.  If your server requires the client to maintain 
state during a session, then your test tool must be able to handle this as well.

<br />


<a name="sesscookie"></a>
###6.2 - Cookies

One way to maintain session state is with HTTP Cookies.  WebInject automatically handles Cookies for you (like a browser would). 
When a "Set-Cookie" is sent back in the HTTP header from the web server, the Cookie is automatically stored and sent back with 
subsequent requests to the domain it was set from.

<br />


<a name="sessid"></a>
###6.3 - Parsing Response Data &amp; Embedded Session ID's (Cookieless)

Embedded Session ID's ("Cookieless" session management) is another approach to maintaining state.  Session ID's are written 
to the content of the HTTP response that is sent to the client.  When the client makes a subsequent HTTP request, the Session 
ID string must be sent back to the server so it can identify the request and match it with a unique session variable it is 
storing internally.  The client sends the string embedded in the URL or embedded in the post body data of each HTTP request.

In order to do this, WebInject provides a method of parsing data from an HTTP response to be resent in subsequent requests.  This
is done using the `parseresponse` parameter and the `{}` variable in your test cases.

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


####Example of maintaining the ViewState with ASP.NET:

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
following parameter to your test case:


```
    parseresponse='__VIEWSTATE" value="|"|escape'
```


This will grab whatever is between the left boundary (__VIEWSTATE" value=") and the right boundary (") and assign to the system variable 
named {}.  Since the 'escape' argument was used, it will also escape all of the non-alphanumeric characters with 
their url hex values (.NET requires this).  (Notice I switched to using single quotes for the parameter value so it wouldn't get confused 
with the double quotes I was using in my boundaries.)


Whenever you use the {} variable in a subsequent test case, it will be substituted with the last value you parsed:


```
    postbody="value=123&__VIEWSTATE={}"
```


Will be sent to the server as:


`value=123&__VIEWSTATE=dDwtNTA4NzczMzUxMjs6Ps1HmLfiYGewI%2b2JaAxhcpiCtj52`

<br />


####Example of parsing the Session ID from an HTTP response header and sending it as part of the URL:

You may receive a Session ID in a HTTP response header that needs to be parsed 
and resent to the server as part of a URL rather than in a cookie.


To parse the Session ID from a header that contains:


`Set-Cookie: JSESSIONID=16CD67F723A6D2218CE73AEAEA899FD9; Path=/`


You would add the following parameter to your test case:


```
    parseresponse="JSESSIONID=|;"
```


This will grab whatever is between the left boundary (JSESSIONID=) and the right boundary (;) and 
assign to the system variable named {}.



Now whenever you use the {} variable in a subsequent test case, it will be substituted with the last value you parsed:


```
    url="http://myserver/search.jsp?value=123&JSESSIONID={}"
```


Will be sent to the server as: 

`http://myserver/search.jsp?value=123&JSESSIONID=16CD67F723A6D2218CE73AEAEA899FD9`

