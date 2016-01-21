# WebInject 1.53
WebInject is a free Perl based tool for automated testing of web applications and web services.


## Quick Start Guide - run your first test in 5 minutes!

WebInject is very easy to setup and run. An example is test included.

### Windows

1. Download WebInject from GitHub as a ZIP and extract it somewhere. 
    * There is no need install it, or build or compile anything.

2. Install Strawberry Perl.
    * Navigate to http://strawberryperl.com/
    * Download and install the recommened version of Strawberry Perl. Choose the 64 bit version if you have 64 bit Windows (probably you do).

That's it! You are now ready to run WebInject for the first time.

### Run the example WebInject test

1. Open the Command Prompt up as an Administrator
    * Press the Windows Key
    * Type `cmd`
    * Right click on `cmd.exe` then select `Run as Administrator`

2. Change to the folder where you extracted the webinject.pl file too. For example, if webinject.pl is in a folder called WebInject, then
    * `CD C:\WebInject\webinject.pl` then press 'Enter'

3. Now just type 'webinject.pl' and hit 'Enter'

If everything worked ok, then you'll see something like the following:

```
Starting WebInject Engine...

-------------------------------------------------------
Test:  examples\simple.xml - 10
Get Totaljobs Home Page
Verify Positive: "Job Ads"
Passed Positive Verification
Passed HTTP Response Code Verification (not in error range)
TEST CASE PASSED
Response Time = 0.805 sec
-------------------------------------------------------
Test:  examples\simple.xml - 20
Get Totaljobs Search Results
Verify Positive: "Automation"
Passed Positive Verification
Passed HTTP Response Code Verification (not in error range)
TEST CASE PASSED
Response Time = 3.662 sec
-------------------------------------------------------

Start Time: Sun Nov 22 19:09:36 2015
Total Run Time: 4.52 seconds

Test Cases Run: 2
Test Cases Passed: 2
Test Cases Failed: 0
Verifications Passed: 6
Verifications Failed: 0
```

So what happened? 

Since you didn't specify any options when you started WebInject, WebInject read the config.xml file and discovered that there was a default testcasefile called `examples\simple.xml`.

So WebInject just ran the tests in that file.

Three files were created in the folder called `output`:
* results.html is a html version of the results you saw in the command prompt - with colour.
* results.xml is an xml version of the results.
* http.log contains the response headers and the html that WebInject received.
    * It is easy to find the html for step 20 - just search for ` - 20`

### Creating your own tests

If you examine `examples\simple.xml` in a text editor you'll see that it is pretty obvious how it works. 

You can just change the url to the website you want to test.

Then just change the verifypositive to look for something in the html on that website.

Save your changes then just run `webinject.pl` again. The three files in output will be overwitten with the results of the latest test.

## The Manual

The manual contains extensive details on how to use WebInject.

[WebInject Manual - MANUAL.md](MANUAL.md)


## Examples

There are many working examples in the examples folder.

## WebInject Self Test

WebInject uses WebInject to test itself. The self tests are organised by feature name. 
If you study the self tests for a feature you are interested, you will learn more about
how that feature works.

You can run all the self tests with the following command:

```
webinject.pl selftest\all.xml
```

Or you can run just one self test like this:

```
webinject.pl selftest\verifypositive.xml
```

