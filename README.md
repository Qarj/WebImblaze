# WebInject 2.10.0
WebInject is a free Perl based tool for automated testing of web applications and web services.

You can see WebInject example output here: http://qarj.github.io/WebInject-Example/

Quick Start Guide - run your first test in 5 minutes!
-----------------------------------------------------

WebInject is very easy to setup and run. An example is test included.

WebInject now supports a new test file format! Details at the bottom of this page.

### Windows

1. Install Strawberry Perl.
    * Navigate to http://strawberryperl.com/
    * Download and install the recommened version of Strawberry Perl. Choose the 64 bit version if you have 64 bit Windows (probably you do).

2. It doesn't matter where you put WebInject, for simplicity, put it in `C:\git`
    ```
    mkdir C:\git
    ```

3. If you have git installed, then just clone the repository
    ```
    cd C:\git
    git clone https://github.com/Qarj/WebInject.git
    ```
    
    If you don't have git, you can get it from https://git-scm.com.

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
    sudo cpan LWP::Protocol::https
    ```

3. Check that you can see the WebInject help info
    ```
    perl webinject.pl --help
    ```

Tested with Fedora 26, Ubuntu 16.04 and 18.04, Linux Mint 18.3, OS X El Capitan and macOS 10.13.

### Docker

https://github.com/Qarj/webinject-docker

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

```
cd C:\git\WebInject
perl webinject.pl tests/hello.xml
```

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

New Test File Format
--------------------
WebInject now supports a simplified test file format.

Once it is proven in production, the intention is to deprecate the xml style file format then
eventually remove it.

The WebInject xml style format is misleading since it isn't true xml - for simplicity we allow
illegal characters to improve readability.

The goal of the new format is to simplify test specification and remove clutter. Common errors
are validated for and a comprehensive error message is given explaining the problem, line
number of the problem and an example of something that works.

The example given higher up this page looks like this in the new format.

hello.txt:
```
step: Get Totaljobs Home Page
varTOTALJOBS_URL: https://www.totaljobs.com
url: {TOTALJOBS_URL}
verifypositive1: Search for and be recommended
verifypositive2: See all hiring companies

step: Search for hello jobs
description2: Expect to see at least 2 pages of hello jobs
url: {TOTALJOBS_URL}/jobs/hello
verifypositive1: \d+./span.\s*.h1.Hello jobs|||Expected to see a count of hello jobs
verifypositive2: page=2|||Should be at least two pages of results for keyword hello
verifynegative1: Page not found
```

Quick start information for new format:
* parameters must start in column 1 of each line
* `step: ` must be on the first line of each step block
* `step: ` replaces description1 (it is converted to description1 on file load)
* `id: ` is reserved - it is assigned automatically in increments of 10
* `method: ` is also inferred - unless you need to use `delete` or `put` in which case you need to specify it
* all parameters for a step block must be grouped together without a blank line - blank lines seperates steps 
* for Selenium steps, use `selenium: ` instead of `command: ` (see examples/selenium.txt)
* for command shell steps, use `shell: ` instead of `command: ` (see examples/lean.txt)
* single and multi line comments are supported (see examples/lean.txt)
* it is possible to assemble a test file from smaller fragment files (see examples/include.txt)

Mixing tabs and spaces for formatting causes alignment to be out whack depending on what text editor
you view the file in. For this reason tabs are not supported for formatting. If you want to align a step, do
it with spaces like this:
```
step:               Search for hello jobs
description2:       Expect to see at least 2 pages of hello jobs
url:                {TOTALJOBS_URL}/jobs/hello
verifypositive1:    \d+./span.\s*.h1.Hello jobs|||Expected to see a count of hello jobs
verifypositive2:    page=2|||Should be at least two pages of results for keyword hello
verifynegative1:    Page not found
```
