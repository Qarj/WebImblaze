#!/usr/bin/perl

# $Id$
# $Revision$
# $Date$

package WebInjectSelenium;

use strict;
use warnings;
use vars qw/ $VERSION /;

$VERSION = '0.1.0';

use File::Copy qw(copy), qw(move);
use Socket qw( PF_INET SOCK_STREAM INADDR_ANY sockaddr_in );

our ($selresp, $driver); ## support for Selenium WebDriver test cases

## Selenium 2.0 Server support + Running ChromeDriver directly
#------------------------------------------------------------------
sub selenium {  ## send Selenium command and read response
    require Selenium::Remote::Driver;
    require Selenium::Chrome;
    require Data::Dumper;

    my $_start_timer = time;

    my $_combined_response = q{};
    $main::request = HTTP::Request->new('GET','WebDriver');

    ## commands must be run in this order
    for (qw/command command1 command2 command3 command4 command5 command6 command7 command8 command9 command10  command11 command12 command13 command14 command15 command16 command17 command18 command19 command20/) {
        if ($main::case{$_}) {#perform command
            my $_command = $main::case{$_};
            undef $selresp;
            my $_selenium_exception;
            my $_eval_response = eval { eval "$_command"; if ($@) { $_selenium_exception = $@; } }; ## no critic(ProhibitStringyEval)
            
             #$main::results_stdout .= "EVALRESP:$_eval_response\n";
            if (defined $selresp) { ## phantomjs does not return a defined response sometimes
                if (($selresp =~ m/(^|=)HASH\b/) || ($selresp =~ m/(^|=)ARRAY\b/)) { ## check to see if we have a HASH or ARRAY object returned
                    my $_dumper_response = Data::Dumper::Dumper($selresp);
                    $main::results_stdout .= "SELRESP: DUMPED:\n$_dumper_response";
                    $selresp = "selresp:DUMPED:$_dumper_response";
                } else {
                    $main::results_stdout .= "SELRESP:$selresp\n";
                    $selresp = "selresp:$selresp";
                }
            } else {
                if (defined $_selenium_exception && $_selenium_exception ne '') {
                    $main::results_stdout .= "SELRESP:<undefined>, Selenium Exception: $_selenium_exception\n";
                    $selresp = "selresp:<undefined>, Selenium Exception: $_selenium_exception\n";
                } else {
                    $main::results_stdout .= "SELRESP:<undefined>\n";
                    $selresp = "selresp:<undefined>\n";
                }
            }
            $_combined_response =~ s{$}{<$_>$_command</$_>\n$selresp\n\n\n}; ## include it in the response
        }
    }
    $selresp = $_combined_response;

    if ($selresp =~ /^ERROR/) { ## Selenium returned an error
       $selresp =~ s{^}{HTTP/1.1 500 Selenium returned an error\n\n}; ## pretend this is an HTTP response - 100 means continue
    }
    else {
       $selresp =~ s{^}{HTTP/1.1 100 OK\n\n}; ## pretend this is an HTTP response - 100 means continue
    }

    my $_end_timer = time; ## we only want to measure the time it took for the commands, not to do the screenshots and verification
    $main::latency = (int(1000 * ($_end_timer - $_start_timer)) / 1000);  ## elapsed time rounded to thousandths

    _get_verifytext(); ## will be injected into $selresp
    $main::response = HTTP::Response->parse($selresp); ## pretend the response is an http response - inject it into the object

    _screenshot();

    return;
} ## end sub

sub _get_verifytext {
    my $_start_timer = time; ## measure latency for the verification
    sleep 0.020; ## Sleep for 20 milliseconds

    ## multiple verifytexts are separated by commas
    if ($main::case{verifytext}) {
        my @_parse_verify = split /,/, $main::case{verifytext} ;
        foreach (@_parse_verify) {
            my $_verify_text = $_;
            $main::results_stdout .= "$_verify_text\n";
            my @_verify_response;

            if ($_verify_text eq 'get_body_text') {
                print "GET_BODY_TEXT:$_verify_text\n";
                eval { @_verify_response =  $driver->find_element('body','tag_name')->get_text(); };
            } else {
                eval { @_verify_response = $driver->$_verify_text(); }; ## sometimes Selenium will return an array
            }

            $selresp =~ s{$}{\n\n\n\n}; ## put in a few carriage returns after any Selenium server message first
            my $_idx = 0;
            foreach my $_vresp (@_verify_response) {
                $_vresp =~ s/[^[:ascii:]]+//g; ## get rid of non-ASCII characters in the string element
                $_idx++; ## we number the verifytexts from 1 onwards to tell them apart in the tags
                $selresp =~ s{$}{<$_verify_text$_idx>$_vresp</$_verify_text$_idx>\n}; ## include it in the response
                if (($_vresp =~ m/(^|=)HASH\b/) || ($_vresp =~ m/(^|=)ARRAY\b/)) { ## check to see if we have a HASH or ARRAY object returned
                    my $_dumper_response = Data::Dumper::Dumper($_vresp);
                    my $_dumped = 'dumped';
                    $selresp =~ s{$}{<$_verify_text$_dumped$_idx>$_dumper_response</$_verify_text$_dumped$_idx>\n}; ## include it in the response
                    ## ^ means match start of string, $ end of string
                }
            }
        }
    }

    my $_end_timer = time; ## we only want to measure the time it took for the commands, not to do the screenshots and verification
    $main::verification_latency = (int(1000 * ($_end_timer - $_start_timer)) / 1000);  ## elapsed time rounded to thousandths

    return;
}

sub _screenshot {
    my $_start_timer = time; ## measure latency for the screenshot

    my $_abs_screenshot_full = File::Spec->rel2abs( "$main::opt_publish_full$main::testnum_display$main::jumpbacks_print$main::retries_print.png" );

    ## do the screenshot, needs to be in eval in case modal popup is showing (screenshot not possible)
    my $png_base64;
    eval { $png_base64 = $driver->screenshot(); };

    ## if there was an error in taking the screenshot, $@ will have content
    if ($@) {
        $main::results_stdout .= "Selenium full page grab failed.\n";
        $main::results_stdout .= "ERROR:$@";
    } else {
        require MIME::Base64;
        open my $_FH, '>', main::slash_me($_abs_screenshot_full) or die "\nCould not open $_abs_screenshot_full for writing\n";
        binmode $_FH; ## set binary mode
        print {$_FH} MIME::Base64::decode_base64($png_base64);
        close $_FH or die "\nCould not close page capture file handle\n";
    }

    my $_end_timer = time; ## we only want to measure the time it took for the commands, not to do the screenshots and verification
    $main::screenshot_latency = (int(1000 * ($_end_timer - $_start_timer)) / 1000);  ## elapsed time rounded to thousandths

    return;
}

sub helper_clear_and_send_keys { ## usage: helper_clear_and_send_keys(Search Target, Locator, Keys);
                                 ##        helper_clear_and_send_keys('candidateProfileDetails_txtPostCode','id','WC1X 8TG');

    my ($_search_target, $_locator, $_keys) = @_;

    my $_element = $driver->find_element("$_search_target", "$_locator")->clear();
    my $_response = $driver->find_element("$_search_target", "$_locator")->send_keys("$_keys");

    return $_response;
}

sub helper_switch_to_window { ## usage: helper_switch_to_window(window number);
                              ##        helper_switch_to_window(0);
                              ##        helper_switch_to_window(1);
    my ($_window_number) = @_;

    require Data::Dumper;

    my $_handles = $driver->get_window_handles;
    my $_response =  $driver->switch_to_window($_handles->[$_window_number]);

    return 'Handles:' . Data::Dumper::Dumper($_handles) . $_response;
}

sub helper_keys_to_element { ## usage: helper_keys_to_element(anchor|||instance,keys);
                             ##        helper_keys_to_element('E.g. Regional Manager','Test Automation Architect');

    my ($_anchor_parms,$_keys) = @_;

    my @_anchor = _unpack_anchor($_anchor_parms);

    return _helper_keys_to_element($_anchor[0],$_anchor[1],'*',0,$_keys);
}

sub helper_keys_to_element_after { ## usage: helper_keys_to_element_after(anchor|||instance,keys,tag|||instance);
                                   ##        helper_keys_to_element_after('Where','London');               # will default to 'INPUT'
                                   ##        helper_keys_to_element_after('Job Type','Contract','SELECT');
                                   ##        helper_keys_to_element_after('What|||1','Test Automation','INPUT|||2');

    my ($_anchor_parms,$_keys,$_tag_parms) = @_;

    my @_anchor = _unpack_anchor($_anchor_parms);
    my @_tag = _unpack_tag($_tag_parms);

    return _helper_keys_to_element($_anchor[0],$_anchor[1],$_tag[0],$_tag[1],$_keys);
}

sub _unpack_anchor {

    my ($_anchor_parms) = @_;

    my @_anchor = split /[|][|][|]/, $_anchor_parms ; ## index 0 is anchor, index 1 is instance number
    $_anchor[1] //= 1;

    return @_anchor;
}

sub _unpack_tag {

    my ($_tag_parms) = @_;
    $_tag_parms //= 'INPUT';

    my @_tag = split /[|][|][|]/, $_tag_parms ; ## index 0 is tag, index 1 is instance number
    $_tag[1] //= 1;

    return @_tag;
}

sub helper_keys_to_element_before { ## usage: helper_keys_to_element_before(anchor|||instance,keys,tag|||instance);
                                    ##        helper_keys_to_element_before('Where','London');               # will default tag to 'INPUT'
                                    ##        helper_keys_to_element_before('Job Type','Contract','SELECT');
                                    ##        helper_keys_to_element_before('Job Type|||2','Contract','SELECT|||2');

    my ($_anchor_parms,$_keys,$_tag_parms) = @_;

    my @_anchor = _unpack_anchor($_anchor_parms);
    my @_tag = _unpack_tag($_tag_parms);

    $_tag[1] = - abs $_tag[1];

    return _helper_keys_to_element($_anchor[0],$_anchor[1],$_tag[0],$_tag[1],$_keys);
}

sub _helper_keys_to_element {

    my ($_anchor,$_anchor_instance,$_tag,$_tag_instance,$_keys) = @_;

    my $_response = _helper_click_element($_anchor,$_anchor_instance,$_tag,$_tag_instance);

    if (%$_response{message} =~ m/Could not find/) { return %$_response{message}; }

    if ($_tag eq 'SELECT') {
        my $_element = $driver->get_active_element();
        eval { # Try exact match first so we do not select None instead of No
            my $_child = $driver->find_child_element($_element, "./option[. = '$_keys']")->click();
        };
        if ($@) { # If exact match didn't work, try a contains match since there might be some special characters the Test Automator is trying to avoid using
            eval {
                my $_child = $driver->find_child_element($_element, "./option[contains(text(),'$_keys')]")->click();
            };
        }
    } else {
        eval {
            my $_keys_response = $driver->get_active_element()->clear();
            $_keys_response = $driver->send_keys_to_active_element($_keys);
        };
    }

    if ($@) { return %$_response{message} . " then got an exception clearing or sending keys\n\nSignature of focused element:\n" . %$_response{element_signature} . "\n\n" .$@; }

    return %$_response{message} . ' then sent keys OK';
}

sub helper_get_element {

    my ($_anchor_parms) = @_;

    my @_anchor = _unpack_anchor($_anchor_parms);

    my %_element_details = % { _helper_get_element($_anchor[0],$_anchor[1],'*',0) };

    if (not $_element_details{element}) {return $_element_details{message};}

    $_element_details{element_value} //= '_NULL_';
    $_element_details{text} //= '_NULL_';
    my $_basic_info = 'Located' . $_element_details{message} . "\n "
                                . $_element_details{element_signature}
                                . "\n Element Text [" . $_element_details{text} . "]"
                                . "\n Element Value [" . $_element_details{element_value} . "]";

    my $_script = _helper_javascript_functions() . q`

        function isElementInViewport (el) {
        
            var rect = el.getBoundingClientRect();
        
            return (
                rect.top >= 0 &&
                rect.left >= 0 &&
                rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) && /*or $(window).height() */
                rect.right <= (window.innerWidth || document.documentElement.clientWidth) /*or $(window).width() */
            );
        }

        function allText (el) {
            var _text = '';
            for (var j = 0; j < el.childNodes.length; ++j) {
               if (el.childNodes[j].nodeType === 3) { // 3 means TEXT_NODE
                   _text += el.childNodes[j].textContent; // We only want the text immediately within the element, not any child elements
               }
            }
            return _text;
        }

        function elementSelection (el) {
            if (el.tagName === 'SELECT') {
                var _selectedValue = el.options[el.selectedIndex].value;
                var _selectedText = el.options[el.selectedIndex].text;
                return "[" + _selectedValue + "] " + _selectedText;
            }
            return '_NA_';
        }

        function isElementChecked (el) {
            if (el.checked) { return 'true'; }
            return 'false';
        }

        var _element = arguments[0];

        return {
            selection : elementSelection(_element),
            isChecked : isElementChecked(_element),
            scrollTop : _element.scrollTop, 
            offsetHeight : _element.offsetHeight,
            offsetWidth : _element.offsetWidth,
            inViewport : isElementInViewport(_element),
            allText : allText(_element)
        }

    `;
    my %_element_extra = % { $driver->execute_script($_script,$_element_details{element}) };

    my $_extra_info = "\n Element Selection [".$_element_extra{selection}."] isChecked[".$_element_extra{isChecked}."]\n".
                      " scrollTop[".$_element_extra{scrollTop}.
                      "] offsetWidth[".$_element_extra{offsetWidth}.
                      "] offsetHeight[".$_element_extra{offsetHeight}.
                      "] inViewport[".$_element_extra{inViewport}.
                      "]\n".
                      " allText[".$_element_extra{allText}."]\n";

    return $_basic_info . $_extra_info;
}

sub _helper_get_element { ## internal use only

    my ($_anchor,$_anchor_instance,$_tag,$_tag_instance) = @_;
    $_anchor_instance //= 1; ## 1 means first instance of anchor
    $_tag //= '*'; ## * means click the tag found by the anchor, whatever it is
    $_tag_instance //= 0; ## -1 means search for the specified tag BEFORE, 1 means search for specified tag after, 0 is an error unless $_tag is '*' 

    my $_script = _helper_javascript_functions() . q`

        var anchor_ = arguments[0];
        var anchor_instance_ = parseInt(arguments[1], 10);
        var tag_ = arguments[2].split("|");
        var tag_instance_ = parseInt(arguments[3], 10);
        var _all_ = window.document.getElementsByTagName("*");
        var _debug_ = '';

        var info_ = search_for_element(anchor_,anchor_instance_);

        if (info_.elementIndex == -1) {
            return {
                message : "Could not find anchor text [" + anchor_ + "] " + anchor_ + "|" + anchor_instance_ + _debug_,
                element : "",
                element_signature : ""
            }
        }

        var target_element_index_ = -1;
        var action_keyword_;
        if (tag_[0] === '*') {
            target_element_index_ = info_.elementIndex;
            action_keyword_ = 'WITH';
        } else if (tag_instance_ > 0) {

            var found_tag_instance_ = 0;
            for (var i=info_.elementIndex+1, max=_all_.length; i < max; i++) {
                target_element_index_ = is_element_at_index_a_match(tag_,i);
                if (target_element_index_ > -1) {
                    found_tag_instance_++;
                    if (found_tag_instance_ === tag_instance_) {
                        break;
                    }
                }
            }
            action_keyword_ = 'AFTER';

        } else {

            var found_tag_instance_ = 0;
            for (var i=info_.elementIndex-1, min=-1; i > min; i--) {
                target_element_index_ = is_element_at_index_a_match(tag_,i);
                if (target_element_index_ > -1) {
                    found_tag_instance_--;
                    if (found_tag_instance_ === tag_instance_) {
                        break;
                    }
                }
            }
            action_keyword_ = 'BEFORE';

        }

        if (target_element_index_ > -1) {
            // the element was found
        } else {
            return { 
                message : "Could not find " + tag_.toString() + " element before the anchor text" + _debug_,
                element : "",
                element_signature : ""
            }
        }

        return {
            message : element_action_info("",target_element_index_,action_keyword_,anchor_,info_.textIndex),
            element : _all_[target_element_index_],
            element_signature : element_signature(target_element_index_),
            element_value : _all_[target_element_index_].value,
            text : _all_[target_element_index_].text
        }
    `;
    my $_response = $driver->execute_script($_script,$_anchor,$_anchor_instance,$_tag,$_tag_instance);

    #print 'Located[debug]' . %{$_response}{message} . "\n  "
    #                            . %{$_response}{element_signature}
    #                            . "\n Element Text [" . %{$_response}{text} . "]"
    #                            . "\n Element Value [" . %{$_response}{element_value} . "]\n";

    return $_response;
}

sub _helper_focus_element { ## internal use only

    my ($_anchor,$_anchor_instance,$_tag,$_tag_instance) = @_;
    $_anchor_instance //= 1; ## 1 means first instance of anchor
    $_tag //= '*'; ## * means click the tag found by the anchor, whatever it is
    $_tag_instance //= 0; ## -1 means search for the specified tag BEFORE, 1 means search for specified tag after, 0 is an error unless $_tag is '*' 

    my $_element_details_ref = _helper_get_element($_anchor,$_anchor_instance,$_tag,$_tag_instance);
    my %_element_details = %$_element_details_ref;

    if (not $_element_details{element}) {return \%_element_details;}

    my $_script = _helper_javascript_functions() . q`

        var element_ = arguments[0];
        element_.focus();
        return;

    `;
    my $_response = $driver->execute_script($_script,$_element_details{element});

    $_element_details{message} = "Focused" . $_element_details{message};

    return \%_element_details;
}

sub _helper_click_element { ## internal use only

    my ($_anchor,$_anchor_instance,$_tag,$_tag_instance) = @_;
    $_anchor_instance //= 1; ## 1 means first instance of anchor
    $_tag //= '*'; ## * means click the tag found by the anchor, whatever it is
    $_tag_instance //= 0; ## -1 means search for the specified tag BEFORE, 1 means search for specified tag after, 0 is an error unless $_tag is '*' 

    my $_element_details_ref = _helper_get_element($_anchor,$_anchor_instance,$_tag,$_tag_instance);
    my %_element_details = %$_element_details_ref;

    if (not $_element_details{element}) {return \%_element_details;}

    my $_script = _helper_javascript_functions() . q`

        var element_ = arguments[0];
        element_.focus();
        element_.click();
        return;

    `;
    my $_response = $driver->execute_script($_script,$_element_details{element});

    $_element_details{message} = "Focused and clicked" . $_element_details{message};

    return \%_element_details;
}

sub helper_move_to { ## usage: helper_move_to(anchor|||instance,x offset, y offset]);
                     ## usage: helper_move_to('Yes');
                     ## usage: helper_move_to('Yes|||2',320,200);

    my ($_anchor_parms,$_x_offset,$_y_offset) = @_;

    $_x_offset //= 0;
    $_y_offset //= 0;

    my @_anchor = _unpack_anchor($_anchor_parms);

    my %_element_details = % { _helper_get_element($_anchor[0],$_anchor[1],'*',0) };

    if (not $_element_details{element}) {return $_element_details{message};}

    my $_response = $driver->mouse_move_to_location(element => $_element_details{element}, xoffset => $_x_offset, yoffset => $_y_offset);

    return 'Found' . $_element_details{message} . ' then moved mouse';
}

sub helper_scroll_to { ## usage: helper_scroll_to(anchor|||instance);
                       ## usage: helper_scroll_to('Yes');
                       ## usage: helper_scroll_to('Yes|||2');

    my ($_anchor_parms) = @_;

    my @_anchor = _unpack_anchor($_anchor_parms);

    my %_element_details = % { _helper_get_element($_anchor[0],$_anchor[1],'*',0) };

    if (not $_element_details{element}) {return $_element_details{message};}

    my $_script = _helper_javascript_functions() . q`

        var element_ = arguments[0];
        element_.scrollIntoView();
        return;

    `;
    my $_response = $driver->execute_script($_script,$_element_details{element});

    return 'Found' . $_element_details{message} . ' then scrolled into view';
}

sub helper_click { ## usage: helper_click(anchor|||instance]);
                   ## usage: helper_click('Yes');
                   ## usage: helper_click('Yes|||2');

    my ($_anchor_parms) = @_;

    my @_anchor = _unpack_anchor($_anchor_parms);

    return %{_helper_click_element($_anchor[0],$_anchor[1],'*',0)}{message};
}

sub helper_click_before { ## usage: helper_click_before(anchor|||instance);

    my ($_anchor_parms,$_tag_parms) = @_;
    $_tag_parms //= 'INPUT|BUTTON|SELECT|A';

    my @_anchor = _unpack_anchor($_anchor_parms);
    my @_tag = _unpack_tag($_tag_parms);

    $_tag[1] = - abs $_tag[1];

    return %{_helper_click_element($_anchor[0],$_anchor[1],$_tag[0],$_tag[1])}{message};
}

sub helper_click_after { ## usage: helper_click_after(anchor|||instance[,element|||instance]);

    my ($_anchor_parms,$_tag_parms) = @_;
    $_tag_parms //= 'INPUT|BUTTON|SELECT|A';

    my @_anchor = _unpack_anchor($_anchor_parms);
    my @_tag = _unpack_tag($_tag_parms);

    return %{_helper_click_element($_anchor[0],$_anchor[1],$_tag[0],$_tag[1])}{message};
}

sub _helper_javascript_functions {

    return q`
        function get_element_number_by_text(_anchor,_depth,_instance)
        {
            var _textIndex = -1;
            var _elementIndex = -1;
            var _found_instance = 0;
            for (var i=0, max=_all_.length; i < max; i++) {
                if (_all_[i].getAttribute('type') === 'hidden') { 
                    continue; // Ignore hidden elements
                }
                var _text = '';
                for (var j = 0; j < _all_[i].childNodes.length; ++j) {
                   if (_all_[i].childNodes[j].nodeType === 3) { // 3 means TEXT_NODE
                       _text += _all_[i].childNodes[j].textContent; // We only want the text immediately within the element, not any child elements
                   }
                }

                //_debug_ = _debug_ + ' ' + _all_[i].tagName;
                //if (_all_[i].id) {
                //    _debug_ = _debug_ + " id[" + _all_[i].id + "]";
                //}

                if (_depth === 0) {
                    if (_text.trim() === _anchor.trim()) {
                        _found_instance = _found_instance + 1;
                    }
                } else {
                    _textIndex = _text.indexOf(_anchor);
                    if (_textIndex != -1 && _textIndex < _depth) {  // Need to target near start of string so Type can be targeted instead of Account Record Type
                        _found_instance = _found_instance + 1;
                    }
                }
 
                if (_instance === _found_instance) {
                    _elementIndex = i;
                    break;
                } else {
                    continue;
                }
            }

            return {
                elementIndex : _elementIndex,
                textIndex : _textIndex
            }
        }

        function get_element_number_by_priority_attribute(_anchor,_depth,_instance)
        {
            var _textIndex = -1;
            var _elementIndex = -1;
            var _found_instance = 0;
            for (var i=0, max=_all_.length; i < max; i++) {
                if (_all_[i].getAttribute('type') === 'hidden') { 
                    continue; // Ignore hidden elements
                }

                for (var j = 0; j < _all_[i].attributes.length; j++) {
                    var attrib = _all_[i].attributes[j];
                    if (attrib.specified && (attrib.name === 'value' || attrib.name === 'placeholder' || attrib.name === 'title') ) {
                        if (_depth === 0) {
                            if (attrib.value === _anchor) {
                                _found_instance = _found_instance +1;
                            }
                        } else {
                            _textIndex = attrib.value.indexOf(_anchor);
                            if (_textIndex != -1 && _textIndex < _depth) {
                                _found_instance = _found_instance + 1;
                            }
                        }
                        if (_instance === _found_instance) {
                            _elementIndex = i;
                            break;
                        } else {
                            continue;
                        }
                    }
                }

                if (_elementIndex > -1) {
                    break;
                }

            }

            return {
                elementIndex : _elementIndex,
                textIndex : _textIndex
            }
        }

        function get_element_number_by_attribute(_anchor,_depth,_instance)
        {
            var _textIndex = -1;
            var _elementIndex = -1;
            var _found_instance = 0;
            for (var i=0, max=_all_.length; i < max; i++) {
                if (_all_[i].getAttribute('type') === 'hidden') { 
                    continue; // Ignore hidden elements
                }

                for (var j = 0; j < _all_[i].attributes.length; j++) {
                    var attrib = _all_[i].attributes[j];
                    if (attrib.specified) {
                        if (_depth === 0) {
                            if (attrib.value === _anchor) {
                                _found_instance = _found_instance +1;
                            }
                        } else {
                            _textIndex = attrib.value.indexOf(_anchor);
                            if (_textIndex != -1 && _textIndex < _depth) {
                                _found_instance = _found_instance + 1;
                            }
                        }
                        if (_instance === _found_instance) {
                            _elementIndex = i;
                            break;
                        } else {
                            continue;
                        }
                    }
                }

                if (_elementIndex > -1) {
                    break;
                }

            }

            return {
                elementIndex : _elementIndex,
                textIndex : _textIndex
            }
        }

        function search_for_element(_anchor,_instance) {
            var _depth = [0,1,3,15,50];
    
            var _info;
            // An element match at text index 0 is preferable to text index 30, so we start off strict, then gradually relax our criteria
            for (var i=0; i < _depth.length; i++) {
                _info = get_element_number_by_text(_anchor,_depth[i],_instance);
                if (_info.elementIndex > -1) {
                    return {
                        elementIndex : _info.elementIndex,
                        textIndex : _info.textIndex
                    }
                }
                _info = get_element_number_by_priority_attribute(_anchor,_depth[i],_instance);
                if (_info.elementIndex > -1) {
                    return {
                        elementIndex : _info.elementIndex,
                        textIndex : _info.textIndex
                    }
                }
            }
            for (var i=0; i < _depth.length; i++) {
                _info = get_element_number_by_attribute(_anchor,_depth[i],_instance);
                if (_info.elementIndex > -1) {
                    return {
                        elementIndex : _info.elementIndex,
                        textIndex : _info.textIndex
                    }
                }
            }
            return {
                elementIndex : -1,
                textIndex : -1
            }
        }


        function is_element_at_index_a_match(_tags,_i) {
            for (var j=0; j < _tags.length; j++) {
                if (_all_[_i].tagName == _tags[j] && !(_all_[_i].getAttribute('type') === 'hidden')) {
                    return _i;
                }
            }
            return -1;
        }

        function element_action_info(_action,_targetElementIndex,_anchor_info,_anchor,_textIndex) {
            var _id = '';
            if (_all_[_targetElementIndex].id) {
                _id=" id[" + _all_[_targetElementIndex].id + "]";
            }
            var _match_type = "(exact match)";
            if (_textIndex > -1) {
                _match_type = "(text index " + _textIndex + ")";
            }
            return _action + " tag " + _all_[_targetElementIndex].tagName + " " + _anchor_info + "[" +_anchor + "] OK " +_match_type + _id + _debug_;
        }

        function element_signature(_targetElementIndex) {
            var _signature = '';
            for (var j = 0; j < _all_[_targetElementIndex].attributes.length; j++) {
                var _attrib = _all_[_targetElementIndex].attributes[j];
                if (_attrib.specified) {
                    _signature = _signature + _attrib.name + '="' + _attrib.value + '" ';
                }
            }
            return _signature;
        }
    `; 
}

sub helper_check_element_within_pixels {     ## usage: helper_check_element_within_pixels(searchTarget,id,xBase,yBase,pixelThreshold);
                                             ##        helper_check_element_within_pixels('txtEmail','id',193,325,30);

    my ($_search_target, $_locator, $_x_base, $_y_base, $_pixel_threshold) = @_;

    ## get_element_location will return a reference to a hash associative array
    ## http://www.troubleshooters.com/codecorn/littperl/perlscal.htm
    ## the array will look something like this
    # { 'y' => 325, 'hCode' => 25296896, 'x' => 193, 'class' => 'org.openqa.selenium.Point' };
    my ($_location) = $driver->find_element("$_search_target", "$_locator")->get_element_location();

    ## if the element doesn't exist, we get an empty output, so presumably this subroutine just dies and the program carries on

    ## we use the -> operator to get to the underlying values in the hash array
    my $_x = $_location->{x};
    my $_y = $_location->{y};

    my $_x_diff = abs $_x_base - $_x;
    my $_y_diff = abs $_y_base - $_y;

    my $_message = "Pixel threshold check passed - $_search_target is $_x_diff,$_y_diff (x,y) pixels removed from baseline of $_x_base,$_y_base; actual was $_x,$_y";

    if ($_x_diff > $_pixel_threshold || $_y_diff > $_pixel_threshold) {
        $_message = "Pixel threshold check failed - $_search_target is $_x_diff,$_y_diff (x,y) pixels removed from baseline of $_x_base,$_y_base; actual was $_x,$_y";
    }

    return $_message;
}

sub helper_wait_for_text_present { ## usage: helper_wait_for_text_present('Search Text',Timeout);
                                   ##        helper_wait_for_text_present('Job title',10);
                                   ##
                                   ## waits for text to appear in page source

    my ($_search_text, $_timeout) = @_;

    $main::results_stdout .= "SEARCHTEXT:$_search_text\n";

    my $_search_expression = '@_response = $driver->get_page_source();'; ## no critic(RequireInterpolationOfMetachars)
    my $_found_expression = 'if ($__response =~ m{$_search_text}si) { return q|true|; }  else { return; }'; ## no critic(RequireInterpolationOfMetachars)

    return _wait_for_item_present($_search_expression, $_found_expression, $_timeout, 'text in page source', $_search_text);

}

sub helper_wait_for_text_visible { ## usage: helper_wait_for_text_visible('Search Text', timeout, 'target', 'locator');
                                   ##        helper_wait_for_text_visible('Job title', 10, 'body', 'tag_name');
                                   ##
                                   ## Waits for text to appear visible in the body text. This function can sometimes be very slow on some pages.

    my ($_search_text, $_timeout, $_target, $_locator) = @_;
    $_timeout //= 5;
    $_target //= 'body';
    $_locator //= 'tag_name';

    $main::results_stdout .= "VISIBLE SEARCH TEXT:$_search_text\n";

    my $_search_expression = '@_response = $driver->find_element($_target,$_locator)->get_text();'; ## no critic(RequireInterpolationOfMetachars)
    my $_found_expression = 'if ($__response =~ m{$_search_text}si) { return q|true|; }  else { return; }'; ## no critic(RequireInterpolationOfMetachars)

    return _wait_for_item_present($_search_expression, $_found_expression, $_timeout, 'text visible', $_search_text, $_target, $_locator);

}

sub helper_wait_visible { ## usage: helper_wait_visible(anchor|||instance,timeout);

    my ($_anchor_parms,$_timeout) = @_;
    $_timeout //= 5;

    my @_anchor = split /[|][|][|]/, $_anchor_parms ; ## index 0 is anchor, index 1 is instance number
    $_anchor[1] //= 1;

    $main::results_stdout .= "WAIT VISIBLE IN VIEWPORT: [$_anchor_parms] TIMEOUT[$_timeout]\n";

    my $_search_expression = '@_response = helper_get_element($_target);'; ## no critic(RequireInterpolationOfMetachars)
    my $_found_expression = 'if ($__response =~ m/inViewport\[1]/) { return q|true|; }  else { return; }'; ## no critic(RequireInterpolationOfMetachars)

    return _wait_for_item_present($_search_expression, $_found_expression, $_timeout, 'element visible', 'NA', $_anchor_parms);

}

sub _wait_for_item_present {

    my ($_search_expression, $_found_expression, $_timeout, $_message_fragment, $_search_text, $_target, $_locator) = @_;

    $main::results_stdout .= "TIMEOUT:$_timeout\n";

    my $_timestart = time;
    my @_response;
    my $_found_it;

    while ( (($_timestart + $_timeout) > time) && (not $_found_it) ) {
        eval { eval "$_search_expression"; }; ## no critic(ProhibitStringyEval)
        foreach my $__response (@_response) {
            #if ($_message_fragment eq 'element visible') { print "__response:$__response\n";}
            if (eval { eval "$_found_expression";} ) { ## no critic(ProhibitStringyEval)
                $_found_it = 'true';
            }
        }
        if (not $_found_it) {
            sleep 0.5; # Sleep for 0.5 seconds
        }
    }
    my $_try_time = ( int( (time - $_timestart) *10 ) / 10);

    my $_message;
    if ($_found_it) {
        $_message = 'Found sought '.$_message_fragment." after $_try_time seconds";
    }
    else {
        $_message = 'Did not find sought '.$_message_fragment.", timed out after $_try_time seconds";
    }

    return $_message;
}

sub helper_wait_not_visible { ## usage: helper_wait_not_visible(anchor|||instance,timeout);

    my ($_anchor_parms,$_timeout) = @_;
    $_timeout //= 5;

    my @_anchor = split /[|][|][|]/, $_anchor_parms ; ## index 0 is anchor, index 1 is instance number
    $_anchor[1] //= 1;

    $main::results_stdout .= "WAIT NOT VISIBLE IN VIEWPORT: [$_anchor_parms] TIMEOUT[$_timeout]\n";

    my $_search_expression = '@_response = helper_get_element($_anchor_parms);'; ## no critic(RequireInterpolationOfMetachars)
    my $_found_expression = 'if ($__response =~ m/inViewport\[1]/) { return q|true|; }  else { return; }'; ## no critic(RequireInterpolationOfMetachars)

    return _wait_for_item_not_present($_search_expression, $_found_expression, $_timeout, 'element visible', 'NA', $_anchor_parms);

}

sub _wait_for_item_not_present {

    my ($_search_expression, $_found_expression, $_timeout, $_message_fragment, $_search_text, $_anchor_parms) = @_;

    $main::results_stdout .= "TIMEOUT:$_timeout\n";

    my $_timestart = time;
    my @_response;
    my $_found_it = 'true';

    while ( (($_timestart + $_timeout) > time) && ($_found_it) ) {
        eval { eval "$_search_expression"; }; ## no critic(ProhibitStringyEval)
        foreach my $__response (@_response) {
            #if ($_message_fragment eq 'element visible') { print "__response:$__response\n";}
            if (not eval { eval "$_found_expression";} ) { ## no critic(ProhibitStringyEval)
                undef $_found_it;
            }
        }
        if ($_found_it) {
            sleep 0.5; # Sleep for 0.5 seconds
        }
    }
    my $_try_time = ( int( (time - $_timestart) *10 ) / 10);

    my $_message;
    if (not $_found_it) {
        $_message = 'SUCCESS: Sought '.$_message_fragment." not found after $_try_time seconds";
    }
    else {
        $_message = 'TIMEOUT: Still found '.$_message_fragment.", timed out after $_try_time seconds";
    }

    return $_message;
}

#------------------------------------------------------------------
sub searchimage {  ## search for images in the actual result

    my $_unmarked = 'true';

    for (qw/searchimage searchimage1 searchimage2 searchimage3 searchimage4 searchimage5/) {
        if ($main::case{$_}) {
            if (-e "$main::case{$_}") { ## imageinimage.py bigimage smallimage markimage
                if ($_unmarked eq 'true') {
                   copy "$main::opt_publish_full$main::testnum_display$main::jumpbacks_print$main::retries_print.png", "$main::opt_publish_full$main::testnum_display$main::jumpbacks_print$main::retries_print-marked.png";
                   $_unmarked = 'false';
                }

                my $_search_image_script = slash_me('plugins/search-image.py');
                my $_image_in_image_result = (`$_search_image_script $main::opt_publish_full$main::testnum_display$main::jumpbacks_print$main::retries_print.png "$main::case{$_}" $main::opt_publish_full$main::testnum_display$main::jumpbacks_print$main::retries_print-marked.png`);

                $_image_in_image_result =~ m/primary confidence (\d+)/s;
                my $_primary_confidence;
                if ($1) {$_primary_confidence = $1;}

                $_image_in_image_result =~ m/alternate confidence (\d+)/s;
                my $_alternate_confidence;
                if ($1) {$_alternate_confidence = $1;}

                $_image_in_image_result =~ m/min_loc (.*?)X/s;
                my $_location;
                if ($1) {$_location = $1;}

                $main::results_xml .= qq|            <$_>\n|;
                $main::results_xml .= qq|                <assert>$main::case{$_}</assert>\n|;

                if ($_image_in_image_result =~ m/was found/s) { ## was the image found?
                    $main::results_html .= qq|<span class="found">Found image: $main::case{$_}</span><br />\n|;
                    $main::results_xml .= qq|                <success>true</success>\n|;
                    $main::results_stdout .= "Found: $main::case{$_}\n   $_primary_confidence primary confidence\n   $_alternate_confidence alternate confidence\n   $_location location\n";
                    $main::passed_count++;
                    $main::retry_passed_count++;
                }
                else { #the image was not found within the bigger image
                    $main::results_html .= qq|<span class="notfound">Image not found: $main::case{$_}</span><br />\n|;
                    $main::results_xml .= qq|                <success>false</success>\n|;
                    $main::results_stdout .= "Not found: $main::case{$_}\n   $_primary_confidence primary confidence\n   $_alternate_confidence alternate confidence\n   $_location location\n";
                    $main::failed_count++;
                    $main::retry_failed_count++;
                    $main::is_failure++;
                }
                $main::results_xml .= qq|            </$_>\n|;
            } else {#We were not able to find the image to search for
                $main::results_html .= qq|<span class="notfound">SearchImage error - was the file path correct? $main::case{$_}</span><br />\n|;
                $main::results_xml .= qq|                <success>false</success>\n|;
                $main::results_stdout .= "SearchImage error - was the file path correct? $main::case{$_}\n";
                $main::failed_count++;
                $main::retry_failed_count++;
                $main::is_failure++;
            }
        } ## end first if
    } ## end for

    if ($_unmarked eq 'false') {
       #keep an unmarked image, make the marked the actual result
       move "$main::opt_publish_full$main::testnum_display$main::jumpbacks_print$main::retries_print.png", "$main::opt_publish_full$main::testnum_display$main::jumpbacks_print$main::retries_print-unmarked.png";
       move "$main::opt_publish_full$main::testnum_display$main::jumpbacks_print$main::retries_print-marked.png", "$main::opt_publish_full$main::testnum_display$main::jumpbacks_print$main::retries_print.png";
    }

    return;
} ## end sub

#------------------------------------------------------------------
sub start_selenium_browser {     ## start Browser using Selenium Server or ChromeDriver
    require Selenium::Remote::Driver;
    require Selenium::Chrome;
    if (not $main::opt_chromedriver_binary) {
        die "\n\nYou must specify --chromedriver-binary for Selenium tests\n\n";
    }

    if (not -e $main::opt_chromedriver_binary) {
        die "\n\nCannot find ChromeDriver at $main::opt_chromedriver_binary\n\n";
    }

    if (defined $driver) { #shut down any existing selenium browser session
        $main::results_stdout .= "    [\$driver is defined so shutting down Selenium first]\n";
        shutdown_selenium();
        shutdown_selenium_server($main::selenium_port);
        sleep 2.1; ## Sleep for 2.1 seconds, give system a chance to settle before starting new browser
        $main::results_stdout .= "    [Done shutting down Selenium]\n";
    }

    $main::opt_driver //= 'chromedriver'; ## if variable is undefined, set to default value
    $main::opt_driver = lc $main::opt_driver;

    if ($main::opt_driver eq 'chrome') {
        $main::selenium_port = _start_selenium_server();
        $main::results_stdout .= "    [Connecting to Selenium Remote Control server on port $main::selenium_port]\n";
    }

    my $_max = 3;
    my $_try = 0;

    ## --load-extension Loads an extension from the specified directory
    ## --whitelisted-extension-id
    ## http://rdekleijn.nl/functional-test-automation-over-a-proxy/
    ## http://bmp.lightbody.net/
    ATTEMPT:
    {
        eval
        {

            ## ChromeDriver without Selenium Server or JRE
            if ($main::opt_driver eq 'chromedriver') {
                my $_port = find_available_port(9585); ## find a free port to bind to, starting from this number
                if ($main::opt_proxy) {
                    $main::results_stdout .= "    [Starting ChromeDriver without Selenium Server through proxy on port $main::opt_proxy]\n";
                    $driver = Selenium::Chrome->new (binary => $main::opt_chromedriver_binary,
                                                 binary_port => $_port,
                                                 _binary_args => " --port=$_port --url-base=/wd/hub --verbose --log-path=$main::output".'chromedriver.log',
                                                 'browser_name' => 'chrome',
                                                 'proxy' => {'proxyType' => 'manual', 'httpProxy' => $main::opt_proxy, 'sslProxy' => $main::opt_proxy }
                                                 );

                } else {
                    $main::results_stdout .= "    [Starting ChromeDriver without Selenium Server]\n";
                    $driver = Selenium::Chrome->new (binary => $main::opt_chromedriver_binary,
                                                 binary_port => $_port,
                                                 _binary_args => " --port=$_port --url-base=/wd/hub --verbose --log-path=$main::output".'chromedriver.log',
                                                 'browser_name' => 'chrome'
                                                 );
                }
            }

            ## Chrome
            if ($main::opt_driver eq 'chrome') {
                my $_chrome_proxy = q{};
                if ($main::opt_proxy) {
                    $main::results_stdout .= qq|    [Starting Chrome with Selenium Server Standalone on port $main::selenium_port through proxy on port $main::opt_proxy]\n|;
                    $driver = Selenium::Remote::Driver->new('remote_server_addr' => 'localhost',
                                                        'port' => $main::selenium_port,
                                                        'browser_name' => 'chrome',
                                                        'proxy' => {'proxyType' => 'manual', 'httpProxy' => $main::opt_proxy, 'sslProxy' => $main::opt_proxy },
                                                        'extra_capabilities' => {'chromeOptions' => {'args' => ['window-size=1260,968']}}
                                                        );
                } else {
                    $main::results_stdout .= "    [Starting Chrome using Selenium Server Standalone on $main::selenium_port]\n";
                    $driver = Selenium::Remote::Driver->new('remote_server_addr' => 'localhost',
                                                        'port' => $main::selenium_port,
                                                        'browser_name' => 'chrome',
                                                        'extra_capabilities' => {'chromeOptions' => {'args' => ['window-size=1260,968']}}
                                                        );
                }
             }
                                                   # For reference on how to specify options for Chrome
                                                   #
                                                   #'proxy' => {'proxyType' => 'manual', 'httpProxy' => $main::opt_proxy, 'sslProxy' => $main::opt_proxy },
                                                   #'extra_capabilities' => {'chrome.switches' => ['--proxy-server="http://127.0.0.1:$main::opt_proxy" --incognito --window-size=1260,460'],},
                                                   #'extra_capabilities' => {'chrome.switches' => ['--incognito --window-size=1260,960']}
                                                   #'extra_capabilities' => {'chromeOptions' => {'args' => ['incognito','window-size=1260,960']}}
                                                   #'extra_capabilities' => {'chromeOptions' => {'args' => ['window-size=1260,968']}}

                                                   #'extra_capabilities'
                                                   #   => {'chromeOptions' => {'args'  =>         ['window-size=1260,960','incognito'],
                                                   #                           'prefs' => {'session' => {'restore_on_startup' =>4, 'urls_to_restore_on_startup' => ['http://www.google.com','http://www.example.com']},
                                                   #                                       'first_run_tabs' => ['http://www.mywebsite.com','http://www.google.de']
                                                   #                                      }
                                                   #                          }
                                                   #      }

        }; ## end eval

        if ( $@ and $_try++ < $_max )
        {
            print "\n[Selenium Start Error - possible Chrome and ChromeDriver version compatibility issue]\n$@\nFailed try $_try to connect to Selenium Server, retrying...\n\n";
            sleep 4; ## sleep for 4 seconds, Selenium Server may still be starting up
            redo ATTEMPT;
        }
    } ## end ATTEMPT

    if ($@) {
        print "\nError: $@ Failed to connect on port $main::opt_port after $_max tries\n\n";
        $main::results_xml .= qq|        <testcase id="999999">\n|;
        $main::results_xml .= qq|            <description1>WebInject ended execution early !!!</description1>\n|;
        $main::results_xml .= qq|            <verifynegative>\n|;
        $main::results_xml .= qq|                <assert>WebInject Aborted - could not connect to Selenium Server</assert>\n|;
        $main::results_xml .= qq|                <success>false</success>\n|;
        $main::results_xml .= qq|            </verifynegative>\n|;
        $main::results_xml .= qq|            <success>false</success>\n|;
        $main::results_xml .= qq|            <result-message>WEBINJECT ABORTED</result-message>\n|;
        $main::results_xml .= qq|            <responsetime>0.001</responsetime>\n|;
        $main::results_xml .= qq|        </testcase>\n|;
        $main::case_failed_count++;
        write_final_xml();
        die "\n\nWebInject Aborted - could not connect to Selenium Server\n";
    }

    eval { $driver->set_timeout('page load', 30_000); };

    return;
}

#------------------------------------------------------------------

sub port_available {
    my ($_port) = @_;

    my $_family = PF_INET;
    my $_type   = SOCK_STREAM;
    my $_proto  = getprotobyname 'tcp' or die "getprotobyname: $!\n";
    my $_host   = INADDR_ANY;  # Use inet_aton for a specific interface

    socket my $_sock, $_family, $_type, $_proto or die "socket: $!\n";
    my $_name = sockaddr_in($_port, $_host)     or die "sockaddr_in: $!\n";

    if (bind $_sock, $_name) {
        return 'available';
    }

    return 'in use';
}

sub find_available_port {
    my ($_start_port) = @_;

    my $_max_attempts = 20;
    foreach my $_i (0..$_max_attempts) {
        if (port_available($_start_port + $_i) eq 'available') {
            return $_start_port + $_i;
        }
    }

    return 'none';
}

#------------------------------------------------------------------
sub shutdown_selenium_server {
    my ($_selenium_port) = @_;

    if (not defined $_selenium_port) {
        return;
    }

    require LWP::Simple;

    my $_url = "http://localhost:$_selenium_port/selenium-server/driver/?cmd=shutDownSeleniumServer";
    my $_content = LWP::Simple::get $_url;
    #print {*STDOUT} "Shutdown Server:$_content\n";

    return;
}

#------------------------------------------------------------------
sub _start_selenium_server {

    if (not -e $main::opt_selenium_binary) {
        die "\nCannot find Selenium Server at $main::opt_selenium_binary\n";
    }

    # copy chromedriver - source location hardcoded for now
    copy $main::opt_chromedriver_binary, $main::output_folder;

    # find free port
    my $_selenium_port = find_available_port(int(rand 999)+11_000);
    #print "_selenium_port:$_selenium_port\n";

    my $_abs_selenium_log_full = File::Spec->rel2abs( $main::output_folder.'/selenium_log.txt' );

    if ($main::is_windows) {
        my $_abs_chromedriver_full = File::Spec->rel2abs( "$main::output_folder/chromedriver.eXe" );
        my $_pid = _start_windows_process(qq{cmd /c java -Dwebdriver.chrome.driver="$_abs_chromedriver_full" -Dwebdriver.chrome.logfile="$_abs_selenium_log_full" -jar $main::opt_selenium_binary -port $_selenium_port -trustAllSSLCertificates});
    } else {
        my $_abs_chromedriver_full = File::Spec->rel2abs( "$main::output_folder/chromedriver" );
        chmod 0775, $_abs_chromedriver_full; # Linux loses the write permission with file copy
        _start_linux_process(qq{java -Dwebdriver.chrome.driver="$_abs_chromedriver_full" -Dwebdriver.chrome.logfile="$_abs_selenium_log_full" -jar $main::opt_selenium_binary -port $_selenium_port -trustAllSSLCertificates});
    }

    return $_selenium_port;
}

#------------------------------------------------------------------
sub _start_windows_process {
    my ($_command) = @_;

    my $_wmic = "wmic process call create '$_command'"; #
    my $_result = `$_wmic`;
    #print "_wmic:$_wmic\n";
    #print "$_result\n";

    my $_pid;
    if ( $_result =~ m/ProcessId = (\d+)/ ) {
        $_pid = $1;
    }

    return $_pid;
}

#------------------------------------------------------------------
sub _start_linux_process {
    my ($_command) = @_;

    my $_gnome_terminal = qq{(gnome-terminal -e "$_command" &)}; #
    my $_result = `$_gnome_terminal`;
    #print "_gnome_terminal:_gnome_terminal\n";
    #print "$_result\n";

    return;
}


sub shutdown_selenium {
    if ($main::opt_driver) {
        #$main::results_stdout .= " Shutting down Selenium Browser Session\n";

        #my $close_handles = $driver->get_window_handles;
        #for my $_close_handle (reverse 0..@{$_close_handles}) {
        #   $main::results_stdout .= "Shutting down window $_close_handle\n";
        #   $driver->switch_to_window($_close_handles->[$_close_handle]);
        #   $driver->close();
        #}

        eval { $driver->quit(); }; ## shut down selenium browser session
        if ($main::opt_driver eq 'chromedriver') {
            eval { $driver->shutdown_binary(); }; ## shut down chromedriver binary
        }
        undef $driver;
    }

    return;
}

1;