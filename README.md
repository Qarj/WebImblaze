# WebImblaze 1.5.0

![Mega-Linter](https://github.com/Qarj/WebImblaze/workflows/Mega%20Lint%20Code%20Base/badge.svg)](https://github.com/megalinter/megalinter)
![Unit tests](https://github.com/Qarj/WebImblaze/workflows/Unit%20tests/badge.svg)
![Self test](https://github.com/Qarj/WebImblaze/workflows/Self%20test/badge.svg)

_Syntax Highlighting with Visual Studio Code is now supported - search for `WebImblaze` in Extensions._

_In Nagios plugin mode, WebImblaze will exit with code UNKNOWN if the test step has an `abort` parameter and it is invoked._

**_This project is now very different to the original WebInject so it has been renamed to WebImblaze._**

WebImblaze is a free Perl based tool for automated testing of web applications and web services.

You can see WebImblaze example output here: [Example output](https://qarj.github.io/WebImblaze-Example/)

## Quick Start Guide - run your first test in 5 minutes

WebImblaze is very easy to setup and run. An example is test included.

### Debian / Ubuntu / Mac

Clone WebImblaze with git

```sh
mkdir $HOME/git
cd $HOME/git
git clone https://github.com/Qarj/WebImblaze.git
```

Fix permissions

```sh
cd $HOME/git/WebImblaze
chmod +x wi.pl
```

Install additional Perl packages, choose `[local::lib]` when configuring cpan.

```sh
cpan XML::Simple
source $HOME/.bashrc
cpan LWP::Protocol::https
```

Check that you can see the WebImblaze help info

```sh
perl wi.pl --help
```

#### CentOS 8

Install `XML::Simple` with this method

```sh
sudo dnf install perl-XML-Simple
```

#### CentOS 7

CentOS requires a lot of additional setup before installing the packages above - some of the below may be redundant

```sh
sudo yum install cpan
sudo cpan
install CPAN
reload CPAN

sudo cpan IO::Socket
sudo yum install perl-libwww-perl
sudo yum install perl-DBI
sudo yum install perl-DBD-MySQL
sudo yum install perl-GD
sudo yum install perl-XML-Simple
sudo cpan JSON::PP
sudo cpan HTTP::Cookies
sudo yum install perl-Crypt-SSLeay
sudo yum install perl-LWP-Protocol-https
sudo yum groupinstall "Development Tools"
sudo yum install openssl-devel
```

You can see if SSL is installed correctly with the command `perl -MNet::SSL -e1` - if it returns no output then all
is OK and there is no need to install `LWP::Protocol::https` using cpan.

### Windows

1. Install Strawberry Perl.

    - Navigate to [Strawberry Perl](http://strawberryperl.com/)
    - Download and install the recommended 64 bit version of Strawberry Perl
    - Optional: Move Strawberry Perl to start of Windows path if installation contains other Perl installs

2. It doesn't matter where you put WebImblaze, for simplicity, put it in `C:\git`

    ```batch
    mkdir C:\git
    ```

3. If you have git installed, then just clone the repository

    ```batch
    cd C:\git
    git clone https://github.com/Qarj/WebImblaze.git
    ```

    If you don't have git, you can get it from [git](https://git-scm.com).

### Create simple WebImblaze test

Note that these instructions are written with Linux in mind.

Ensure you have installed the `WebImblaze` vscode extension for syntax highlighting.

In the `tests` folder, create a file called `hello.test`.

```sh
cd $HOME/git/WebImblaze
code tests/hello.test
```

Copy paste the following then save the file.

```yml
step:               Get Totaljobs Home Page
varTOTALJOBS_URL:   https://www.totaljobs.com
url:                {TOTALJOBS_URL}
verifypositive1:    Search for and be recommended
verifypositive2:    See all hiring companies

step:               Search for hello jobs
desc:               Expect to see at least 2 pages of hello jobs
url:                {TOTALJOBS_URL}/jobs/hello
addheader:          Referer: www.totaljobs.com
verifypositive1:    Hello jobs|||Expected to see a count of hello jobs
verifypositive2:    page=2|||Should be at least two pages of results for keyword hello
verifynegative1:    Page not found
```

### Run simple WebImblaze test

```sh
perl wi.pl tests/hello.test
```

If everything worked OK, then you'll see something like the following:

```txt
Starting WebImblaze Engine...

-------------------------------------------------------
Test:  tests/hello.test - 10
Get Totaljobs Home Page
Verify Positive: "Search for and be recommended"
Verify Positive: "See all hiring companies"
Passed Positive Verification
Passed Positive Verification
Passed HTTP Response Code Verification
TEST STEP PASSED
Response Time = 0.122 sec
-------------------------------------------------------
Test:  tests/hello.test - 20
Search for hello jobs
Expect to see at least 2 pages of hello jobs
Verify Negative: "Page not found"
Verify Positive: "Hello jobs"
Verify Positive: "page=2"
Passed Positive Verification
Passed Positive Verification
Passed Negative Verification
Passed HTTP Response Code Verification
TEST STEP PASSED
Response Time = 0.122 sec
-------------------------------------------------------
Start Time: Sun 27 Feb 2022, 19:38:05
Total Run Time: 0.302 seconds

Total Response Time: 0.244 seconds

Test Steps Run: 2
Test Steps Passed: 2
Test Steps Failed: 0
Verifications Passed: 9
Verifications Failed: 0

Results at: output/Results.html
```

So what happened?

First WebImblaze read in the default config file called `config.xml` located in the root folder of the project.

Then it loaded `tests/hello.test` and ran the two test steps in order, numbering them `10` and `20`.

Five files were created in the default output folder called `output`:

-   `results.html` is a HTML version of the results - with colour
-   `results.xml` is a XML version of the results
-   `http.txt` contains all the response headers and the actual page HTML
-   `10.html` contains the HTTP response for step 10
-   `20.html` contains the HTTP response for step 20

Double click on `results.html` to view in a browser, there are links to the individual results for steps 10 and 20.
Click on the link for step 10 and to see the web page that WebImblaze received rendered in the browser. You can
expand the `Request Headers` and `Response Headers`. You can also click on `next` to see the next test step results.
Ignore the `Summary`, `Batch Summary` and `Run Results` links (the WebImblaze-Framework project is needed to make them functional.)

### Creating your own tests

There are some examples on the WebImblaze blog with detailed discussion: [Examples](http://webimblaze.blogspot.co.uk/)

Examine and run the examples in the `examples` folder.

Also, if you examine the files in the `selftest/substeps` folder you will get a lot of additional examples for additional parameters.

Finally there is always the manual :)

## The Manual

The manual contains extensive details on how to use WebImblaze.

[WebImblaze Manual - MANUAL.md](MANUAL.md)

## Examples

There are many working examples in the examples folder.

For additional examples, study the self tests in the `selftest\substeps` folder.

## WebImblaze Self Test

WebImblaze uses WebImblaze to test itself. The self tests are organised by feature name.
If you study the self tests for a feature you are interested, you will learn more about
how that feature works.

You can run all the self tests with the following command:

```sh
perl wi.pl selftest/all_core.test
```

Or you can run just one self test like this:

```sh
perl wi.pl selftest/verifypositive.test
```

## WebImblaze Plugins

### WebImblaze-Framework

Have multiple test environments? Hundreds of tests that are run many times a day?

Then the WebImblaze-Framework project is for you! Provides config management and a way to neatly organise test execution and results.

Find the project here: [WebImblaze Framework](https://github.com/Qarj/WebImblaze-Framework)

### WebImblaze-Selenium

WebImblaze can also drive the Chrome browser using WebDriver Selenium.

Find the project here: [WebImblaze-Selenium](https://github.com/Qarj/WebImblaze-Selenium)

### search-image

A Chrome screenshot can be searched to see if it contains a specific (or approximate) sub-image.

Find the project here: [search-image](https://github.com/Qarj/search-image)

### Nagios

Use WebImblaze as a plugin to Nagios to monitor critical business workflows.

[WebImblaze as Nagios plugin](https://webimblaze.blogspot.com/2018/11/webimblaze-as-nagios-plugin-for.html)

## Test File Format

WebImblaze uses a simplified test file format over WebInject.

The WebInject xml style format is misleading since it isn't true xml - for simplicity
illegal characters are allowed to improve readability.

The goal of the format is to simplify test specification and remove clutter. Common errors
are validated for and a comprehensive error message is given explaining the problem, line
number of the problem and an example of something that works.

Use VSCode and install the WebImblaze Syntax Highlighting extension for best results.

Quick start information:

-   parameters must start in column 1 of each line
-   `step:` must be on the first line of each step block
-   `step:` replaces description1
-   `desc:` replaces description2
-   `id:` is reserved - it is assigned automatically in increments of 10
-   `method:` is also inferred - unless you need to use `delete` or `put` in which case you need to specify it
-   all parameters for a step block must be grouped together without a blank line - blank lines separates steps
-   quotes are usually not needed, but if you do you can make up your own quotes (see examples/quotes.test)
-   for Selenium steps, use `selenium:` instead of `command:` (see examples/misc/selenium.test)
-   for command shell steps, use `shell:` instead of `command:` (see examples/demo.test)
-   it is possible to assemble a test file from smaller fragment files (see examples/advanced/include.test)

Mixing tabs and spaces for formatting causes alignment to be out whack depending on what text editor
you view the file in. For this reason tabs are not supported for formatting.

Full information is in the manual.

[Perl script for converting .xml test case files to .test files](https://github.com/Qarj/WebImblaze-Framework/blob/master/MANUAL.md#convert-webinject-xml-test-case-files-to-new-test-format)
Note - you'll need to manually move over comments, plus the repeat parameter. It only works with two or more test steps, and two or more include steps (if present).

[Notepad++ syntax highlighting for WebImblaze .test files](https://github.com/Qarj/WebImblaze-Framework/blob/master/MANUAL.md#syntax-highlighting-webimblaze-test-case-files)

## Docker

[Docker](https://hub.docker.com/r/qarj/webimblaze/)
