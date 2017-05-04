# WebInject 2.6.0
WebInject is a free Perl based tool for automated testing of web applications and web services.

You can see WebInject example output here: http://qarj.github.io/WebInject-Example/

Quick Start Guide - run your first test in 5 minutes!
-----------------------------------------------------

WebInject is very easy to setup and run. An example is test included.

### Windows

1. Download WebInject from GitHub as a ZIP and extract it somewhere. For simplicity, extract it to C:\git\WebInject so that the file `C:\git\Webinject\webinject.pl` exists.
    * There is no need install it, or build or compile anything.

2. Install Strawberry Perl.
    * Navigate to http://strawberryperl.com/
    * Download and install the recommened version of Strawberry Perl. Choose the 64 bit version if you have 64 bit Windows (probably you do).

That's it! You are now ready to run WebInject for the first time.

### Linux / Mac

1. Clone WebInject with git
    ```
    mkdir ~/git
    cd ~/git
    git clone https://github.com/Qarj/WebInject.git
    ```

2. Enter the following commands
    ```
    cd WebInject
    chmod +x webinject.pl
    sudo cpan File::Slurp
    sudo cpan XML::Simple
    sudo cpan Math::Random::ISAAC
    ```

3. Check that you can see the WebInject help info
    ```
    perl webinject.pl --help
    ```

Tested with Fedora 23, 24, Ubuntu 16.04, Linux Mint 18 xfce, OS X El Capitan and macOS 10.12.

### Create your first WebInject test

Note that these instructions are written with Windows in mind. 

In the `tests` folder, create a file called `hello.xml`.

Edit the file with your favourite text editor and copy paste the following then save the file.

```xml
<testcases repeat="1">

<case
    varTOTALJOBS_URL="https://www.totaljobs.com"
    id="10"
    description1="Get Totaljobs Home Page"
    method="get"
    url="{TOTALJOBS_URL}"
    verifypositive1="Search for and be recommended"
    verifypositive2="See all hiring companies"
/>

<case
    id="20"
    description1="Search for hello jobs"
    description2="Expect to see at least 2 pages of hello jobs"
    method="get"
    url="{TOTALJOBS_URL}/jobs/hello"
    verifypositive1="\d+./span.\s*.h1.Hello jobs|||Expected to see a count of hello jobs"
    verifypositive2="page=2|||Should be at least two pages of results for keyword hello"
    verifynegative1="Page not found"
/>

</testcases>
```

### Run your first WebInject test

1. Open the Command Prompt up as an Administrator
    * Press the Windows Key
    * Type `cmd`
    * Right click on `cmd.exe` then select `Run as Administrator`

2. Change to the folder where you extracted the webinject.pl file too. For example, if webinject.pl is in a folder called `C:\git\WebInject`, then
    * `CD C:\git\WebInject` then press 'Enter'

3. Now type `webinject.pl tests/hello.xml` and hit 'Enter'

If everything worked ok, then you'll see something like the following:

```
Starting WebInject Engine...

-------------------------------------------------------
Test:  tests\hello.xml - 10
Get Totaljobs Home Page
Verify Positive: "Search for and be recommended"
Verify Positive: "See all hiring companies"
Passed Positive Verification
Passed Positive Verification
Passed HTTP Response Code Verification
TEST CASE PASSED
Response Time = 1.31 sec
-------------------------------------------------------
Test:  tests\hello.xml - 20
Search for hello jobs
Expect to see at least 2 pages of hello jobs
Verify Negative: "Page not found"
Verify Positive: "\d+./span.\s*.h1.Hello jobs"
Verify Positive: "page=2"
Passed Positive Verification
Passed Positive Verification
Passed Negative Verification
Passed HTTP Response Code Verification
TEST CASE PASSED
Response Time = 0.335 sec
-------------------------------------------------------
Start Time: Sat 04 Mar 2017, 15:54:56
Total Run Time: 2.944 seconds

Total Response Time: 1.645 seconds

Test Cases Run: 2
Test Cases Passed: 2
Test Cases Failed: 0
Verifications Passed: 9
Verifications Failed: 0

Results at: output\results.html
```

So what happened?

First WebInject read in the default config file called `config.xml` located in the root folder of the project.

Then it loaded `tests/hello.xml` and ran the two test steps in the file in numerical order.

Five files were created in the default output folder called `output`:
* results.html is a html version of the results you saw in the command prompt - with colour.
* results.xml is an xml version of the results.
* http.txt contains the response headers and the html that WebInject received.
* 10.html contains the http response for step 10
* 20.html contains the http response for step 20

If you double click on results.html to view in a browser, you will see hyperlinks to the indiviual results for steps 10 and 20.
Click on the link for step 10 and you will see the web page that WebInject received rendered in the browser. You are able to
expand the `Request Headers` and `Response Headers`. You can also click on `next` to see the next test step results.
Ignore the `Summary`, `Batch Summary` and `Run Results` links (the WebInject-Framework project is needed to make them functional.)

### Creating your own tests

There are some examples on the WebInject blog with detailed discussion: http://webinject.blogspot.co.uk/

Examine and run the examples in the `examples` folder.

Also, if you examine the files in the `selftest\substeps` folder you will get a lot of additional examples for additional parameters.

Finally there is always the manual :)


The Manual
----------

The manual contains extensive details on how to use WebInject.

[WebInject Manual - MANUAL.md](MANUAL.md)


Examples
--------

There are many working examples in the examples folder.

For additional examples, study the self tests in the `selftest\substeps` folder.


WebInject Self Test
-------------------

WebInject uses WebInject to test itself. The self tests are organised by feature name.
If you study the self tests for a feature you are interested, you will learn more about
how that feature works.

You can run all the self tests with the following command:

```
perl webinject.pl selftest/all_core.xml
```

Or you can run just one self test like this:

```
perl webinject.pl selftest/verifypositive.xml
```

WebInject Plugins
-----------------

## WebInject-Framework
Have multiple test environments? Hundreds of tests that are run many times a day?

Then the WebInject-Framework project is for you! Provides config management and a way to neatly organise test execution and results.

Find the project here: https://github.com/Qarj/WebInject-Framework

## WebInject-Selenium
WebInject can also drive the Chrome browser using WebDriver Selenium.

Find the project here: https://github.com/Qarj/WebInject-Selenium

## search-image
A Chrome screenshot can be searched to see if it contains a specific (or approximate) sub-image.

Find the project here: https://github.com/Qarj/search-image
