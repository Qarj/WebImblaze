# WebInject 1.99
WebInject is a free Perl based tool for automated testing of web applications and web services.

You can see WebInject example output here: http://qarj.github.io/WebInject-Example/

Quick Start Guide - run your first test in 5 minutes!
-----------------------------------------------------

WebInject is very easy to setup and run. An example is test included.

### Windows

1. Download WebInject from GitHub as a ZIP and extract it somewhere.
    * There is no need install it, or build or compile anything.

2. Install Strawberry Perl.
    * Navigate to http://strawberryperl.com/
    * Download and install the recommened version of Strawberry Perl. Choose the 64 bit version if you have 64 bit Windows (probably you do).

That's it! You are now ready to run WebInject for the first time.

### Linux

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

4. Optional - run the self test
    ```
    perl webinject.pl selftest/all.xml
    ```

Tested with Fedora 23, 24 and Ubuntu 16.04

### Run the example WebInject test

Note that these instructions are written with Windows in mind. 

1. Open the Command Prompt up as an Administrator
    * Press the Windows Key
    * Type `cmd`
    * Right click on `cmd.exe` then select `Run as Administrator`

2. Change to the folder where you extracted the webinject.pl file too. For example, if webinject.pl is in a folder called WebInject, then
    * `CD C:\WebInject` then press 'Enter'

3. Now just type `webinject.pl` and hit 'Enter'

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

Total Response Time: 4.467 seconds

Results at: output\results.html
```

So what happened?

Since you didn't specify any options when you started WebInject, WebInject read the config.xml file and discovered that there was a default testcasefile called `examples\simple.xml`.

So WebInject just ran the tests in that file.

Three files were created in the folder called `output`:
* results.html is a html version of the results you saw in the command prompt - with colour.
* results.xml is an xml version of the results.
* http.txt contains the response headers and the html that WebInject received.
    * It is easy to find the html for step 20 - just search for ` - 20`

### Creating your own tests

If you examine `examples\simple.xml` in a text editor you'll see that it is pretty obvious how it works.

You can just change the url to the website you want to test.

Then just change the verifypositive to look for something in the html on that website.

Save your changes then just run `webinject.pl` again. The three files in output will be overwitten with the results of the latest test.

The Manual
----------

The manual contains extensive details on how to use WebInject.

[WebInject Manual - MANUAL.md](MANUAL.md)


Examples
--------

There are many working examples in the examples folder.

For additional examples, study the self tests in the selftest\substeps folder.

Selenium WebDriver using ChromeDriver
-------------------------------------

WebInject can also drive Chrome using using ChromeDriver. A bit of extra setup is needed.

### Windows

1. Open a command prompt as an administrator and issue the following command:
    ```
    cpan Selenium::Remote::Driver
    ```

2. Obtain ChromeDriver.exe from https://sites.google.com/a/chromium.org/chromedriver/ and save
it somewhere. For simplicity, ensure that there are no spaces in the path.

    For this example, we'll put it here: `C:\selenium\chromedriver.exe`

3. Optional - download selenium-server-standalone-2.53.1.jar from http://selenium-release.storage.googleapis.com/2.53/selenium-server-standalone-2.53.1.jar
and place it in `C:\selenium`

#### Run the Selenium WebDriver example
1. Open a command prompt as an administrator and issue the following command:

    ```
    perl webinject.pl examples\selenium.xml --driver chromedriver --binary C:\selenium\chromedriver.exe
    ```

You should see Chrome open along with a process chromedriver.exe in the taskbar.

After the tests run, you will see in the `output` folder that screenshots for each step
are automatically taken.

2. Optional - Run the same example through Selenium Server (in my experience this is more robust)

    First you need to start the server in a separate process, in this example we'll start it on port 9988
    ```    
    wmic process call create 'cmd /c java -Dwebdriver.chrome.driver="C:\selenium\chromedriver.exe" -jar C:\selenium\selenium-server-standalone-2.53.1.jar -port 9988 -trustAllSSLCertificates'
    ```

    Then you call WebInject telling it what port to find Selenium Server on
    ```
    perl webinject.pl examples\selenium.xml --port 9988 --driver chrome
    ```

### Linux

1. First obtain ChromeDriver and put it in a folder called ~/selenium by running these commands
    ```
    mkdir ~/selenium
    wget -N http://chromedriver.storage.googleapis.com/2.22/chromedriver_linux64.zip -P ~/selenium
    sudo apt install unzip
    unzip ~/selenium/chromedriver_linux64.zip -d ~/selenium
    chmod +x ~/selenium/chromedriver
    ```

2. Now obtain the Selenium Standalone Server and put it in ~/selenium with this command
    ```
    wget -N http://selenium-release.storage.googleapis.com/2.53/selenium-server-standalone-2.53.1.jar -P ~/selenium
    ```

3. A few extra commands are needed to ensure the dependencies are covered
    ```
    sudo apt install gnome-terminal
    sudo apt install default-jre
    sudo cpan Selenium::Remote::Driver
    ```

4. Now you should install Chrome, on Ubuntu / Debian / Linux Mint you can do it with these commands
    ```
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
    sudo sh -c 'echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
    sudo apt-get update
    sudo apt-get install google-chrome-stable
    ```

5. Important - Run Chrome at least once and choose whether you want it to be the default browser or not. You can then close it or leave it open. If you don't do this, then it will hang when you try to run a test with ChromeDriver.

6. You can check that it all works by running the Selenium self test. You should see Chrome open twice and run a quick test. The first time will be using Selenium Server Standalone. The second time will be using ChromeDriver directly without Selenium Server Standalone.
    ```
    perl webinject.pl selftest/selenium.xml
    ```    

#### Run the Selenium WebDriver example

1. You can run the example through ChromeDriver directly as follows:

    ```
    perl webinject.pl -d chromedriver --binary ~/selenium/chromedriver examples/selenium.xml
    ```

2. In my experience, the Selenium Standalone Server is more reliable. You can run the same example test through Selenium Server.
   
    First start the Selenium Standalone Server in a background terminal
    ```
    (gnome-terminal -e "java -Dwebdriver.chrome.driver=$HOME/selenium/chromedriver -jar $HOME/selenium/selenium-server-standalone-2.53.1.jar -port 9988 -trustAllSSLCertificates" &)
    ```

    Now run the example, selecting to use the Selenium Standalone Server running on port 9988
    ```
    perl webinject.pl --port 9988 --driver chrome examples/selenium.xml
    ```

    Once you are finished running all the Selenium tests, you can shut down the Selenium Standalone Server as follows
    ```
    curl http://localhost:9988/selenium-server/driver/?cmd=shutDownSeleniumServer
    ```


WebInject Self Test
-------------------

WebInject uses WebInject to test itself. The self tests are organised by feature name.
If you study the self tests for a feature you are interested, you will learn more about
how that feature works.

You can run all the self tests with the following command:

```
perl webinject.pl selftest/all.xml
```

Or you can run just one self test like this:

```
perl webinject.pl selftest/verifypositive.xml
```

Plugins
-------

### search-image.py

To use the searchimage parameter (see manual), you need to install the dependencies for the search-image.py plugin. (The plugin itself is already installed in the plugins folder.)

See https://github.com/Qarj/search-image for full installation instructions.

To test that it works, run the following. If all test steps pass, then everything is setup ok.

```
webinject.pl -d chromedriver --binary C:\ChromeDriver\chromedriver.exe examples\searchimage.xml
```

You can also check the result by looking at `output\100.png' and also `output\200.png`. You'll see that
search-image.py has marked the locations of the result screenshot where it found the images.