                    Automatic Article Checker
    v1.6  Copyright (C) June 2, 1999  by Heinrich Schramm
                  mailto:heinrich@schramm.com

converted to perl by Wilfried Klaebe <wk@orion.toppoint.de>
  (not really converted, more or less rewritten in perl)

modified & enhanced (more or less rewritten ;-))
  by Thomas Hochstein <THochstein@gmx.de> since March/April 2000
(c) artchk.pl (mod.) January 06, 2001 by Thomas Hochstein

Version: 1.2.01 BETA

_________ ATTENTION please! - This is a BETA version! _________

---------------------------------------------------------------------------
This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option)
any later version.
This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details.
---------------------------------------------------------------------------

(1) REQUIREMENTS

* Perl 5.x
* the "News::NNTPClient"-module from CPAN.
* the "MIME::QuotedPrint"-module from CPAN.
* the "MIME::Base64"-module from CPAN.
* the "Net::DNS"-module from CPAN.
* a (local) NNTP-server

(2) INSTALLATION

* Install
    - artchk.pl     # main program

  and

    - sample.ini    # .ini-file: server, port, user/password, groups, counter
    - sample.rc     # .rc-file: customize headers / body of followups
    - domains       # valid TLDs for MID-FQDNs

  to the same directory.

  The last three files must reside in the same directory as the first, or
  you have to specify the path to them when invoking artchk.pl

  You may specify different .ini-/.rc-files when invoking artchk.pl

* Modify "sample.ini" to fit your needs and rename it to "artchk.pl.ini"
  (default) or anything you like.

  The .ini-file has to contain
  - parameters
  - the special word "checkgroups:" including the colon
  - a list of groups to check

  The parameters are written one on a line, "parametername = parameter".
  Allowed parameters are:
  - reader        : the newsserver (and port) you read the postings from,
                    "server.name,port"
                    This entry is necessary; you can drop the port.
                    Default for port is 119.
  - reader_user   : your username for authorization
                    Default: (none) ---> no authorization
  - reader_pass   : your password for authorization
  - poster        : the newsserver (and port) you post to,
                    "server.name,port"
                    Default: [none] ---> post to the server you read from
                    You can drop the port. Default for port is 119.
  - reader_user   : your username for authorization
                    Default: [none] ---> no authorization
  - reader_pass   : your password for authorization
  - trigger_check : a regular expression for the string that initiates
                    a check when found in "Subject:".
                    Default: check
                    You should change "[header]" in the .rc-file accordingly!
  - trigger_ignore: a regular expression for the string that stops a check
                    in auto-mode (see below) when found in "Subject:" or
                    first line of body.
                    Default: (ignore)|(no[ ]*repl(y|(ies)))
                    You should change "[header-auto]" in the .rc-file accordingly!
  - rcfile        : the name of your .rc-file
                    Default: [name of .ini-file]
  - killfile      : the name of your .kill-file
                    Default: [name of .ini-file]

  You can place comment lines in between; they may NOT contain a "=".

  The list of groups is in the following format:
  - the name of a group to check
  - a single space and a "y" or "n" to enable/disable auto-mode. Set it
    to "n" - artchk will only post followups to postings with
             trigger_check in the subject (but if trigger_check is
             found, it _will_ post a followup, even if trigger_ignore is
             also found)
    to "y" - auto-mode; artchk will also post followups if it found
             something to correct as long as trigger_ignore is _not_
             found in the subject or the first line of the body and no
	     killfile-expresion matches

  You may NOT place anything else after the magic word "checkgroups:".

  - Example:
       reader        = server.pro.vider,119
       reader_user   = user
       reader_pass   = pass
       ---> We do not have another posting server.
       checkgroups:
       de.test y
       de.alt.test n

* Modify "sample.rc" to fit your needs and rename it to "artchk.pl.rc"
  (default) or anything you like.

    - [head]-Section:
      Edit at least the "From:" header configuration.
      Edit or delete the "Sender:" header.
      Edit or delete the "Path:" header.
      Edit or delete the "Reply-To:" header.
      Add any other headers you like,
      e.g. "X-Checkbot-Owner: My Name <my.name@do.main.invalid>"
      Do _NOT_ insert a "Newsgroups:" header!
      Do _NOT_ insert "Subject:", "Message-ID:", "References:" or "X-Artchk-Version:"!

    - Edit the [header]-/[header-auto]- and/or [footer] text section if
      you like. You should do that if you have changed the trigger_check/
      trigger_ignore-settings!

    - Later on, you can edit the other sections as you like. Please be
      sure to have a look at the source code in this case to understand
      how these sections are used.

    - Later on, you may add sections with special tips for certain
      newsclients. Those sections will be printed out immediately after
      the standard-reply. They have the form of [standard-nr] with nr being
      one of

         oe (Outlook Express, all versions)
         moz (Mozilla, all versions)
         agent (Forté Agent _and_ Free Agent, all versions)
         xnews (XNews, all versions)
         gnus (Gnus, all versions)
         macsoup (MacSoup, all versions)
         slrn (slrn, all versions)
         mpg (Microplanet's Gravity, all versions)
	 pine
	 xp (crosspoint)
	 pminews

    - You may also delete sections - except for the following:
      [head] [header] [header-auto] [footer] [intro] [allok] [nr]
      The corresponding checks will then be skipped.

* Attention! The sample files have CR/LF as linebreaks (DOS). On UNIX
  machines, you'll have to convert the files to use just LF as EOL, for
  example using "tr -d '\r' < sample.rc > sample.rc-unix".

(3) HOW TO RUN artchk.pl

* Just start it up. ;-)

  - "perl artchk.pl" should do fine, but artchk.pl will also accept parameters:
    perl artchk.pl -p<path> -n<name> -v[vvv] -l<logfile> -c<mid> --log

  - -v[vvv]
    Default: 0
    Verbosity level from "0" to "4". See below.
    e.g. "perl artchk.pl -vvv".

  - -p
    Default: (empty)
    Path to your .ini-/.rc-/domains/.disabled/.kill/.log-file.
    e.g. "perl artchk.pl -pc:\programme\artchk\".

  - -n
    Default: artchk.pl[.ini]
    Name for your .ini-file. This name also applies for the .disabled-file.
    See below.
    e.g. "perl artchk.pl -nserver1".
    
  - -l
    Default: (the name set via -n)[.log]
    Name for the logfile (if activated). See "--log" below.
    e.g. "perl artchk.pl -lartchk.log".

  - -c
    Default: (there is none)
    Force check of a posting with "-c<message-id>".
    e.g. "perl artchk.pl -c<176r23r2erwfwe@do.main>"

  - --log
    Activate logfile.

  - artchk.pl will recognize the parameters regardless of their order.

* artchk.pl will _not_ start if a file artchk.pl.disabled (or a file with
  any other, depending on the "-n"-parameter) exists in the path given
  with "-p".

* Normally, it will read the .rc- and .ini-file and do a little bit (!)
  of syntax-checking with them.

* Then it'll connect to your server and check the first group. It'll get
  every new article from there, check it and -possibly- generate a
  followup and post it to that group. Then it'll do all other groups.
  It will delete and rewrite (!) the .ini-file to keep the article
  counter up to date.

* It will check every posting unless it
  - is not in a group containing "test"
  - is a control message
  - already is a checkbot answers (detected by MID)
  - contains trigger_ignore in Keywords:
  - doesn't contain trigger_check in Subject:
    AND auto-mode is off

  If auto-mode is on, it will also check postings without
  trigger_check in Subject:, unless they

  - contain trigger_ignore in Subject: or first line of body
  - matcht the killfile (see below)

* It will include an excerpt from the logfile if $trigger_check is
  followed by "verbose".

* The display output of artchk.pl can be more or less verbose.
  
  A debug level

  of:           means:
  0   - introduction/end + error messages
  1   - 0 + configuration and summaries
  2   - 1 + progress indicator
  3   - 2 + NNTP status replies from server
  4   - 3 + (debug-)output from check-routines

  Default is 0.

* You can add a killfile to exclude certain postings from auto-mode.
  This file must have the name defined in your .ini-file and reside
  in the path given with "-p".
  It must have the following format:
  headerfield = regular expression # comment
  where headerfield is the name of any header field
        regular expression is any regular expression
	comment (anything from # to EOL) is a comment that is ignored

  If the regular expression matches the content of the header field,
  the posting is ignored in auto-mode. It is _not_ ignored if a check
  is requested via trigger-check in the Subject:.

---------------------------------------------------------------------------

Please remember:

(1) This is a BETA version. Report all bugs and suggestions to
    <artchk@akallabeth.de>.

(2) If you start running this bot in a non-local newsgroup, please send a
    short notice to <artchk@akallabeth.de>. That will make it possible to
    report bugs, problems and updates to you.

(3) Please use this program with care and sense of responsibility!
    Thank you.

---------------------------------------------------------------------------