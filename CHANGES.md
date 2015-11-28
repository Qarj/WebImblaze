WebInject

Copyright 2004, 2005, 2006 Corey Goldberg (corey@goldb.org)
For information and documentation, visit the website at http://www.webinject.org

---------------------------------
Release History:


Version 1.41 - Jan 4, 2006
    - Added ability to add multiple HTTP Headers within an 'addheader' testcase parameter
    - Added 'addheader' testcase parameter to GET requests (previously only supported POST)
    - Fixed GUI layout for high dpi displays
    - Bugfixes for 'verifyresponsecode' and 'errormessage' parameters


Version 1.40 - Dec 6, 2005
    - Support for Web Services (SOAP/XML)
    - Added XML parser for parsing and verification of XML responses (web services)
    - Support for 'text/xml' and 'application/soap+xml' Content-Type (web services)
    - Added new 'addheader' testcase parameter so you can specify an additional HTTP Header field for requests
    - Support for setting variables/constants within test case files
    - Added ability to call generic external Perl plugins for easier integration and post-processing
    - More detail added to XML output
    - Code refactoring

    
Version 1.35 - April 4, 2005
    - New command line option (-o) to specify location for writing output files (http.log, results.html, and results.xml)
    - Nagios plugin performance data support
    - Allows multiple 'httpauth' elements in config files to support multiple sets of HTTP Authentication credentials
    - New 'verifyresponsecode' test case parameter for HTTP Response Code verification
    - Additional 'baseurl' elements supported in the config file
    - Additional verification parameters supported in test cases
    - Added -V command line option (same as -v) to print version info (necessary for it to run with Moodss)
    - Code refactoring

Version 1.34 - Feb 10, 2005
    - MRTG External Monitoring Script (Plugin) compatibility
    - Bugfix for using comment tags in config files
    - Suppress logging when running in plugin mode
    - Changed default standalone plot mode to OFF

Version 1.33 - Jan 26, 2005
    - Nagios Plugin compatibility
    - Support for multipart/form-data encoded POSTs (file uploads)
    - Updated results.html output so it is valid XHTML
  
Version 1.32 - Jan 14, 2005
    - Bugfix for erroneous dummy test case printing in GUI status
    - Bugfix for warning that appeared when running GUI with Perl in -w mode
    
Version 1.31 - Jan 11, 2005
    - Bugfix for errors and broken status bar in GUI
    
Version 1.30 - Jan 07, 2005
    - HTTP Basic Authentication support
    - No longer forced to have test cases in strict incremental numbered order
    - Source code compiles with the "use strict" pragma
    - Ability to run engine from a different directory using alternate test case and config files
    - Comments allowed in config file using <commment></comment> tags
    - Other config.xml options are still used when you pass a test case filename as a command line argument
    - New config option to change response delay timeout <timeout></timeout>
    - New test case parameter to add a custom error message
    - Added separators to http.log for readability
    - Enhanced command line options/switches
    - Nagios Plugin compatibility (beta)
    - More verbose error handling when running from command line
    - Ability to handle reserved XML character "<" within test cases by escaping it with a backslash "<"
    - Changed output when using XPath notation from command line
    - Bugfix for proxy support
    - Bugfix for sending a parsed value in a POST body
    - Bugfix for erroneous errors when running from command line
    - Bugfix for warnings that appeared when running with Perl in -w mode
    - Code refactoring

Version 1.20 - Sept 27, 2004
    - Real-time response time monitoring (stats display and integration with gnuplot for plot/graph)
    - Added tabbed layout to GUI with 'Status' and 'Monitor' windows
    - Added 'Stop' button to GUI to halt execution
    - New testcase parameter 'sleep', to throttle execution
    - Added timer summary to HTML report
    - Removed HTML tags from STDOUT display and cleaned up formatting
    - GUI enhancements
    - Code refactoring

Version 1.12 - July 28, 2004
    - New test case file parameter 'repeat', to run a test case file multiple times
    - Added GUI options for Minimal Output and Response Timer Output
    - New config.xml parameter to define a custom User-Agent string to be sent in HTTP headers
    - Added XPath Node selection to optional command line parameters
    - Bugfix for GUI Restart button

Version 1.10 - June 23, 2004
    - Added XML formatted output (results.xml is created each run)
    - New config.xml parameter for HTTP logging
    - More detailed pass/fail status to HTML report
    - Redefined criteria for test case pass/pail
    - Results summary and additional formatting to STDOUT (for standalone mode)
    - Minor code refactoring

Version 0.95 - May 17, 2004
    - Added Restart button to GUI
    - Added 5 additional parsing parameters/variables to use in test cases
    - Fixes to GUI positioning

Version 0.94 - April 29, 2004
    - Bugfix for malformed HTTP Post
    - Added colors to status window text

Version 0.93 - March 22, 2004
    - Dynamic response parsing support cookieless session handling
    - Added version number to GUI window title bar

Version 0.92 - March 05, 2004
    - Minor bug fixes
    - Added status light to GUI
    - New config.xml parameter for HTTP proxy support
    - New config.xml parameter for Baseurl constant

Version 0.91 - Feb 23, 2004
    - Decoupled GUI (webinjectgui) from Test Engine (webinject) so engine can run standalone
    - Testcase name can be passed on command line as well as via config.xml
    - Code cleanup
    - Output sent to STDOUT as well as reports (for standalone mode)

Version 0.90 - Feb 19, 2004
    - Initial public beta release
    - Contains SSL/TLS support
    - Perl/Tk GUI
    - Automatic cookie handling
    
---------------------------------
