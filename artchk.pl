#!/usr/bin/perl
#
#                     Automatic Article Checker
#     v1.6  Copyright (C) June 2, 1999  by Heinrich Schramm
#                   mailto:heinrich@schramm.com
#
# converted to perl by Wilfried Klaebe <wk@orion.toppoint.de>
#   (not really converted, more or less rewritten in perl)
#
# modified & enhanced
#   by Thomas Hochstein <THochstein@gmx.de> since March/April 2000
# (c) artchk.pl (mod.) January 06, 2001 by Thomas Hochstein
#
# _________ ATTENTION please! - This is still a BETA version! _________
#
# ------------------------------------------------------------------------------
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.
# ------------------------------------------------------------------------------
#
# You will need the following modules from CPAN:
#    - News::NNTPClient
#    - MIME::QuotedPrint
#    - MIME::Base64
#   (- Net::DNS)
#
# ------------------------------------------------------------------------------
#
# You will have to create an artchk.pl.ini / artchk.pl.rc file.
# Please see readme.txt for details.
#
# Please use this program with care and sense of responsibility!
# Thank you.
#
##################################################################

###-### mark for temp. changes
#-# 1.2.01g changes new in that version
#-# {RKELLER} Contributed by Reiner Keller <keller@dlrg.de>

use News::NNTPClient;
use MIME::QuotedPrint;
use MIME::Base64;
use Net::DNS;
use File::Basename;                    #-# {RKELLER}

##### Constants
$version = 'V 1.2.01k BETA';           # Stand: 2001-10-13
$online = 0;                           # permanent connection to the net
$serverresponse = "# NNTP:";           # intro for debugmsg (NNTP status response)
$debugdiagmarker = "* ->";             # intro for debugmsg (diag{...} set)
@roles = qw/abuse noc security
            root sysop admin newsmaster
            postmaster hostmaster usenet news webmaster www uucp ftp/;
$hex_nibb     = '[0-9a-fA-F]';
$gt_hex_nibb  = '[0-9A-F]';
$lt_hex_nibb  = '[0-9a-f]';
$alpha_num    = '[0-9a-zA-Z]';
$lt_alpha_num = '[0-9a-z]';
$gt_alpha_num = '[0-9A-Z]';
# definitions from s-o-1036
$r_unquoted_char_a = '[#$%&\'|*+{}~\-/0123456789=?A-Z^_`a-z]';                     # correct definition (for mailaddress)
$r_unquoted_word_a = "$r_unquoted_char_a+";                                        # correct definition (for mailaddress)
$r_unquoted_char   = '[#$%&\'|*+{}~\-/0123456789=?A-Z^_`a-z\x80-\xFF]';            # definition including \x80-\xFF (8bit)
$r_unquoted_word   = "$r_unquoted_char+";                                          # definition including \x80-\xFF (8bit)
$r_quoted_char     = '[!@,;:.\[\]#$%&\'|*+{}~\-/0123456789=?A-Z^_`a-z\x80-\xFF]';  # definition including \x80-\xFF (8bit)
$r_quoted_word     = "\"($r_quoted_char|\\s)+\"";                                  # definition including \x80-\xFF (8bit)
$r_paren_char      = '["!@,;:.\[\]#$%&\'|*+{}~\-/0123456789=?A-Z^_`a-z\x80-\xFF]'; # definition including \x80-\xFF (8bit)
$r_paren_phrase    = "($r_paren_char|\\s)+";                                       # definition including \x80-\xFF (8bit)
$r_plain_word      = "$r_unquoted_word|$r_unquoted_word";                          # definition including \x80-\xFF (8bit)
$r_plain_phrase    = "$r_plain_word(\\s+$r_plain_word)*";                          # definition including \x80-\xFF (8bit)
$r_address         = "$r_unquoted_word_a(\\.$r_unquoted_word_a)*\@$r_unquoted_word_a(\\.$r_unquoted_word_a)*";

##### Main program
# get commandline parameters
while (@ARGV) {
 $f = shift;
 if ($f =~ /^-d(.*)/) {
  $debuglevel = $1;
 } elsif ($f =~ /-(v+)/) {
  $debuglevel = length($1);
 } elsif ($f =~ /-p(.*)/) {
  $pathtoini = $1;
 } elsif ($f =~ /-n(.*)/) {
  $ininame = $1;
  if ($ininame=~/\.ini$/) {
   $ininame=~s/(.*?)\.ini$/$1/;
  };
 } elsif ($f =~ /-c(.*)/) {
  $checkpost = $1;
 } elsif ($f =~ /^-l(.*)/) {
  $logfile = $1;
  if ($logfile =~/\.log$/) {
   $logfile=~s/(.*?)\.log$/$1/;
  };
 } elsif ($f =~ /--log/) {
  $logging = 1;
 } elsif ($f =~ /--feedmode/) {  #-# 1.2.01k
  $feedmode = 1;                 #-# 1.2.01k
 } elsif ($f =~ /--pedantic/) {  #-# 1.2.01k
  $pedantic = 1;                 #-# 1.2.01k
 }
};

# set parameters to default, if necessary / exit, if disabled
if (!defined($debuglevel)) {$debuglevel = 0};
if (!defined($ininame)) {$ininame = basename ($0)};  #-# {RKELLER}
exit (10) if (-e "$0.disabled");                     # exit if "artchk.pl.disabled" exists
exit (10) if (-e "$ininame.disabled");               # exit if ".disabled" exists
if (!defined($pathtoini)) {
 $pathtoini = dirname ($0).'/'                       #-# {RKELLER}
} elsif ($pathtoini !~ /.*(\/|\\)$/) {
 $pathtoini .= '/';
} 
if (!defined($checkpost) or ($checkpost!~/<\S+\@\S+>/)) {$checkpost = 'no'};
if (!defined($logfile)) {$logfile = "$ininame"};

# open logfile
if ($logging) {
 open LOG, ">>$pathtoini$logfile.log" || die "Could not open $pathtoini$logfile.log for appending: $!";
 if ($feedmode) {                     #-# 1.2.01k
  select((select(LOG), $| = 1)[0]);   # set autoflush
 };
};

# print introduction
op(10,"\n-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-\n\n");
op(10,"This is artchk.pl (mod.) $version started on ".scalar(gmtime)." GMT.\n");
op(0,"Send suggestions & comments to <artchk\@akallabeth.de>.\n\n");

# read .rc-file / .ini-file / domains / killfile
&readini;
&readrcfile;
&readdomains;
if (-e "$killname.kill") {
 open KILL, "<$pathtoini$killname.kill" || die "Could not open $pathtoini$killname.kill for reading: $!";
 while (<KILL>) {
  chomp;
  s/#.+//;      # drop comments
  s/^\s+//;     # drop whitespace before
  s/\s+$//;     # drop whitespace after
  next unless length;
  my ($key,$value) = split(/\s*=\s*/,$_,2);    # header = regexp
  push @{ $kill[scalar(@kill)] },lc($key),lc($value);
 };
 close KILL;
};

# print configuration
op(1,"\nDebug-Level      : $debuglevel\n");
op(1,  "Path to files    : $pathtoini\n");
op(1,  "Filenames        : $ininame.ini / $rcname.rc / $logfile.log\n");
op(1,  "Trigger 'check'  : $trigger_check\n");
op(1,  "Trigger 'ignore' : $trigger_ignore\n");
op(1,  "Newsserver (read): $server $port\n");
op(1,  "Newsserver (post): $postingserver $postingport\n");
if ($checkpost eq 'no') {
 op(1, 'Groups to check  :');
 foreach $testgroup (@testgroups) {op(1, " $testgroup")};
} else {
 op(11, "Posting to check: $checkpost\n");
};
op(1, "\n\n");
op(1, "---------- Starting connection procedure ----------\n");

if ($feedmode) {           #-# 1.2.01k ---->
 until(eof(STDIN)){
  $file=<STDIN>;
  $file=~s/(\S*).*/$1/;
  &feed_article($file);   # will set $wholeheader, @header and $wholebody (global!)
  &check_article;
 }
} else {                  #-# 1.2.01k <-----
 # open server (for reading)
 $readserver = &connectserver($server,$port,$s_user,$s_pass);

 # open server (for posting), if specified
 if ($postingserver ne '') { $postserver = &connectserver($postingserver,$postingport,$posts_user,$posts_pass) };

 # main loop - check all postings in all groups
 op(1,"---------- Starting checks ----------");

 if ($checkpost eq 'no') {
  foreach $testgroup (@testgroups) {
   op(1,"\n---------- New group ----------");
   op(1,"\nOpening group $testgroup ...");
   # get low-/high-marks of $testgroup
   if (!(($low, $high) = ($readserver->group($testgroup)))) {
    op(13,"\n$serverresponse Error: " . $readserver->code . ' ' . $readserver->message . "Skipping group.\n");
    op(0,"Error opening group $testgroup on $server.\n");
   } else {
    op(1," done.\n");
    op(3,"$serverresponse".$readserver->code.' '.$readserver->message);
    op(11,"\n$testgroup: $low ---> $high; first to be checked: $watermark{$testgroup}\n");
    if ($watermark{$testgroup} > ($high + 2)) {
     op(1,"! High watermark of group $testgroup is to low - resetting counter ...");
     $watermark{$testgroup} = $high;
    }
    if ($watermark{$testgroup} > $low) {$low = $watermark{$testgroup}};
    if ($watermark{$testgroup} > $high) {
     op(1,"Nothing new to check in $testgroup ... terminating.\n");
    } else {
     op(1,'Starting checks, ');
     if($auto{$testgroup}) {
      op(1,"generating followups for any problem detected (auto-mode).\n");
     }else{
      op(1, "only generating followups if requested.\n");
     }
    }

    # load posting
    for ($doit = $low; $doit <= $high; $doit += 1) {
     $togo=$high-$doit;
     op(2,"Now getting: __> $doit <__  ---  $togo to go ...\n");
     &get_article($doit);   # will set $wholeheader, @header and $wholebody (global!)
     &check_article($testgroup,$auto{$testgroup});
    };

    # remmber last tested posting
    $watermark{$testgroup} = $high + 1;

    # rewrite .ini-file
    op(1,"Rewriting .ini-file ... ");
    &writeini;
    op(1,"done.\n");
   };
  }
 } else {
  op(1,"\nNow getting: $checkpost\n");
  &get_article($checkpost);   # will set $wholeheader and $wholebody (global!)
  &check_article('none',2);
 }

 op(1,"\n\n---------- Termination sequence ... ----------");
 op(1,"\nartchk.pl (mod.) $version signing off.\n");
 # close server and files
 $readserver->quit;
 if ($postingserver ne '') { $postserver->quit };
};

if ($logging) {
 op(15,"$0 $version terminated successfully on ".scalar(gmtime)." GMT.\n");
 close LOG;
};
op(0,"Program terminated on ".scalar(gmtime)." GMT.\n\n");
op(0,"Thank you for using.\n");
exit(0);

################################################################
# Main subroutines: get article / feed article / check article

sub get_article {
# load article via NNTP
 my($doit)=@_;
 my(@article,$lang);

 # parse posting: first get headers ...
 if (!(@article = $readserver->head($doit))) {
  op(13,"\n$serverresponse Error: " . $readserver->code . ' ' . $readserver->message);
  op(0,"Error reading header from $server.\n");
 } else {
  op(3,"$serverresponse".$readserver->code.' '.$readserver->message);
 };
 # split @article and add all lines to $wholeheader
 @header = @article; # @header is global!
 $wholeheader = '';  # $wholeheader is global!
 $lang = @article;
 for ($i = 0; $i <= $lang; $i+= 1) {
  $wholeheader .= shift(@article);
 };
 # ... then get body
 if (!(@article = $readserver->body($doit))) {
  op(13,"\n$serverresponse Error: " . $readserver->code . ' ' . $readserver->message);
  op(0,"Error reading body from $server.\n");
 } else {
  op(3,"$serverresponse".$readserver->code.' '.$readserver->message);
 };
 $wholebody = ''; # $wholebody is global!
 $lang = @article;
 for ($i = 0; $i <= $lang; $i+= 1) {
  $wholebody .= shift(@article);
 };
};


sub feed_article {                   #-# 1.2.01k
# load article from disk
 my $file = shift;
 open(ARTICLE,"<$file") or op(15,"I/O ERROR while opening $file: $!\n");
 $/='';
 $wholeheader = <ARTICLE>;           # $wholeheader is global!
 @header = split(/\n/,$wholeheader); # @header is global!
 undef $/;
 $wholebody = <ARTICLE>;             # $wholebody is global!
 close(ARTICLE);
 $/="\n";
};


sub check_article {
# check article and generate followup
 my($testgroup,$auto)=@_;
 # $testgroup is 'none' for forced check, '' for feeding-mode
 # $auto is '2' for forced check, '' for feeding-mode
 # will use global $wholeheader, @header and $wholebody (from &get_article / &feed_article)
 # will use global %config and %domain (from &readrcfile / &readdomains)
 my(@body);                            # parts of the posting
 my($newsreader,$nr);                  # specials
 my($docheck,$sigokay);                # trigger
 my(@article,@duplicate,$frdompart,$frlocpart,$rplocpart,$rpdompart,$wrongsig);
                                       # output
 my($m,$f,$i,$flag,$sigstart,$query,$res,@mx,$key,$value,$testgroup_q,$postgroups);
                                       # auxiliaries
 my($tag,$monat,$jahr,$zeit,$wtag);    # date
 # will use global %header,%header_decoded,$debugmsg,%diag,$diaglevel
 undef %header;
 undef %header_decoded;
 undef $debugmsg;
 undef %diag;
 undef $diaglevel;

 local *ev = sub {
 # evaluate variables
  my ($i) = shift;
  ($f = $config{$i}) =~ s/(\$[a-z{}'_-]+)/$1/gee;
  $f;
 };

 # split $wholeheader into single headers
 while ($_=shift @header) {
  chomp;
  if ($_ =~ /^\s+/) {
   $_ =~ s/^\s*(.+)\s*$/$1/;
   $header{lc($key)} .= "\n\t$_";
  } elsif ($_ ne "\n") {
   ($key,$value) = split /:/,$_,2;
   if (exists $header{lc($key)}) {
    push @duplicate,$key;
    $diag{'duplicate'} = 1;
   } else {
    ($header{lc($key)} = $value) =~ s/^\s*(.+)\s*$/$1/;
   };
  };
 };;
 
 # return if not a test group
 # or if posting is bot-reply or cmsg or keywords contain $trigger_ignore ...
 if ($auto != 2) {
  return if $header{'newsgroups'}!~/test/i;
  return if $header{'message-id'} =~ /checkbot\.fqdn\.de>[ ]*$/i;
  return if $header{'message-id'} =~ /checkbot-checked/i;
  return if (defined($header{'control'}));
  return if (defined($header{'keywords'}) and $header{'keywords'}=~/$trigger_ignore/io);
 };
 
 if ($feedmode) {                                   #-# 1.2.01k
  $auto = 3;                                        # set $auto to unusual value
  foreach $testgroup (@testgroups) {
   $testgroup_q  = quotemeta($testgroup);           # quote meta characters ('.'!)
   if ($header{'newsgroups'} =~ /$testgroup_q/) {   # if one of the test groups is found in Newsgroups: ...
    if ($postgroups != '') {
     $postgroups .= ',';
    };
    $postgroups .= $testgroup;                      # ... add it to $postgroups and ...
    if ($auto{$testgroup} <= $auto) {
     $auto = $auto{$testgroup};                     # ... reset $auto to the lowest value of all testgroups
    };
   };
  };
  return if $auto == 3;                             # return if $auto was not reset
  $testgroup = $postgroups;                         # set $testgroup for posting a followup
 };

 $debugmsg .= "  --- Posting Check Results  ---\n";
 # ... or if killfile is triggered (if check is not forced) ...
 if ($auto != 2) {
  $debugmsg .= "  Checking posting; it's in a test group and neither bot-reply nor cmsg.\n";
  # check if killfile is triggered and set $flag
  foreach (@kill) {
   ($key,$value) = @{$_};
   if (defined($header{$key}) and $header{$key}=~/$value/i) {
    $flag = 1 ;
    $debugmsg .= "  Killfile rule '$key=$value' triggered.\n";
   };
  }
 };

 # ... or if neither $trigger_check in Subject: nor auto-mode activated
 $debugmsg .= "  Subject: " . $header{'subject'} . "\n";
 if ($header{'subject'} ne &hdecode($header{'subject'})) {
  $debugmsg .= "  Subject (decoded): " . &hdecode($header{'subject'}) . "\n";
 };
 if (&hdecode($header{'subject'}) =~ /$trigger_check/io or ($auto==2)) {
  $docheck = 1;
  if ($auto==2) {
   $debugmsg .= "  TRIGGER: Check forced via '-c'.\n";
   $testgroup = $header{'newsgroups'};
  } else {
   $debugmsg .= "  TRIGGER: Found \"$trigger_check\" in the \"Subject:\"-line, continuing check.\n";
  };
 }
 else {
  $debugmsg .= "  TRIGGER: \"$trigger_check\" not found in \"Subject:\"-line";
  if (!$auto or (&hdecode($header{'subject'}) =~ /$trigger_ignore/io) or $flag) {
   $debugmsg .= ", terminating check.\n";
   $debugmsg .= "  --- End of Check Results  ---\n\n";
   op(15,"$header{'message-id'}:\n$debugmsg\n");
   return;
  } else {
   $debugmsg .= "; auto-mode activated - no ignore, continuing check.\n";
  };
 };

 # put decoded (q/p and base64) headers in %header_decoded
 foreach $key (keys %header) {
  $header_decoded{$key} = &hdecode($header{$key});
 };

 # generate debugmsg for duplicate headers
 foreach (@duplicate) {
  $debugmsg .= "  $debugdiagmarker Duplicate header line: $_\n"
 }

 # try to detect the newsreader
 if (defined($header{'user-agent'})) {
  $newsreader=$header_decoded{'user-agent'}
 } elsif(defined($header{'x-newsreader'})) {
  $newsreader=$header_decoded{'x-newsreader'}
 } elsif (defined($header{'x-mailer'})) {
  $newsreader=$header_decoded{'x-mailer'}
 }
 if ((defined($newsreader)) and ($newsreader ne '')) {
  KNOWN: {
   $nr= 'oe', last KNOWN if $newsreader=~/Outlook Express/i;
   $nr= 'moz', last KNOWN if ($newsreader=~/Mozilla/i and $newsreader!~/StarOffice/i);
   $nr= 'agent', last KNOWN if ($newsreader=~/Forte.*Agent/i or $header{'message-id'}=~/^[a-zA-Z0-9=+]{28,34}\@/ or $header{'message-id'}=~/^$lt_alpha_num{8}\.\d{7,9}\@/ or $header{'message-id'}=~/^$lt_alpha_num{7}\.\d{2,3}\.\d\@/);
   $nr= 'xnews', last KNOWN if ($newsreader=~/Xnews/ or $header{'message-id'}=~/^$lt_alpha_num{6}\.$lt_alpha_num{2}\.\d\@/);  #-# 1.2.01l
   $nr= 'gnus', last KNOWN if ($newsreader=~/Gnus/i or $header{'message-id'}=~/^$lt_alpha_num{10,11}\.fsf\@/o);
   $nr= 'slrn', last KNOWN if ($newsreader=~/slrn/i or $header{'message-id'}=~/^slrn$lt_alpha_num{6}\.$lt_alpha_num{2,3}\.\w+\@/);
   $nr= 'macsoup', last KNOWN if ($newsreader=~/MacSOUP/i or $header{'message-id'}=~/^$lt_alpha_num{7}\.$lt_alpha_num{13,14}[A-Z]\%[a-zA-Z\.]+\@/);
   $nr= 'mpg', last KNOWN if ($newsreader=~/Gravity/i or $header{'message-id'}=~/^MPG\.$lt_hex_nibb{22}\@/o);
   $nr= 'pine', last KNOWN if ($newsreader=~/Gravity/i or $header{'message-id'}=~/^Pine\.$gt_alpha_num{3}\.\d\.\d{2}\.\d{14}\.\d{4,5}-\d{6}\@/o);
   $nr= 'xp', last KNOWN if ($newsreader=~/Gravity/i or $header{'message-id'}=~/^[a-zA-Z0-9\$\-]{11}\@/o);
   $nr= 'pminews', last KNOWN if ($newsreader=~/Gravity/i or $header{'message-id'}=~/^[a-z]{16,21}\.$alpha_num{7}\.pminews\@/o);
  }
 }
 if (!defined($nr)) {
  $nr = '-';
  $debugmsg .= "  Could not identify newsreader.\n"
 } else {
  $debugmsg .= "  Newsreader identified: $newsreader [$nr].\n"
 };

 # * ---> check for 8bit in headers
 if($wholeheader=~/[\x80-\xFF]/) {
  $diag{'8bitheader'}=1;
  $diaglevel=2;
  $debugmsg .= "  $debugdiagmarker 8bit-chars in header.\n";
 };

 # * ---> check from-header
 ($frlocpart,$frdompart) = checkfromrp('From');

 # * ---> check reply-to
 if (defined($header{'reply-to'})) {
  ($rplocpart,$rpdompart) = checkfromrp('Reply-To');
 };

 # * ---> check from == replyto
 if(defined($header{'reply-to'}) && ((getmailaddress($header_decoded{'from'}))[0] eq (getmailaddress($header_decoded{'reply-to'}))[0])) {
  $diag{'replytofrom'}=1 ;
  $diaglevel ||= 1;
  $debugmsg .= "  $debugdiagmarker \"From:\" = \"Reply-To:\".\n";
 };

 # * ---> check message-id
 ($dompart = $header{'message-id'}) =~ s/.*\@(.*)>$/$1/; # fqdn isolieren
 $dompart = lc($dompart);
 ($tld = $dompart) =~ s/.*\.([^.]+)$/$1/;                # TLD isolieren
 # no FQDN, but less than one word or numbers
 if($dompart!~/(\D\w*\.)+(\D\w*$)/) {
  $diag{'nomid'}=1;
  $diaglevel=2;
  $debugmsg .= "  $debugdiagmarker MID wrong: FQDN is just one word or just numbers.\n";
 };
 # invalid chars in domain
 if($dompart =~ /[^a-z0-9\-.]/) {
  $diag{'nomid'}=1;
  $diaglevel=2;
  $debugmsg .= "  $debugdiagmarker MID wrong: FQDN contains invalid characters.\n";
 };
 # check for valid TLD
 if(!defined($domain{$tld})) {
  $diag{'nomid'}=1;
  $diaglevel=2;
  $debugmsg .= "  $debugdiagmarker MID wrong: no valid TLD.\n";
 };
 # check for <unique%mailaddress@do.main> (USEFOR, used e.g. by MacSOUP)
 ($f,undef,undef,$i,undef) = &getmailaddress($header_decoded{'from'});
 $f = quotemeta($f);
 if ($header{'message-id'} =~ /%$f>$/) {
  $debugmsg .= "  MID is <unique%address\@do.main>, see draft-ietf-usefor-msg-id-alt-00,\n";
  $debugmsg .= "  chapter 2.1.2 - not yet a good idea (but we do not mind ;-)).\n";
 } elsif (($dompart eq $i) and ($nr eq 'moz') and ($header{'message-id'} =~ /^<$gt_hex_nibb{8}\.$gt_hex_nibb{4,8}\@/)) {
  # Mozilla generates the MID from the FQDN of the mailaddress
  $diag{'nomid'}=1;
  $diaglevel ||= 1;
  $debugmsg .= "  $debugdiagmarker MID wrong: Mozilla takes FQDN of mailaddress.\n";
 } elsif($dompart=~/^gmx\.(de|net|at|ch|li)$/) {
  # special: GMX does not offer usenet service
  $diag{'nomid'}=1;
  $diaglevel=2;
  $debugmsg .= "  $debugdiagmarker MID wrong: GMX does not offer usenet service.\n";
 };
 if (defined($diag{'nomid'})) {
  $debugmsg .= "  MID was \"$header{'message-id'}\".\n";
 };

 # * ---> check date
 ($wtag,$tag,$monat,$jahr,$zeit) = (split / +/, $header{'date'});
 if (!($wtag=~/\w{3},/)) {
  $zeit = $jahr;
  $jahr = $monat;
  $monat = $tag;
  $tag = $wtag;
 };
 if ($jahr < 1970) {
  $diag{'date'}=1;
  $diaglevel=2;
  $debugmsg .= "  $debugdiagmarker \"Date:\" is incorrect: year < 1970.\n";
  $debugmsg .= "  \"Date:\" was: \"$header{'date'}\".\n";
 };

 # * ---> check for html
 if(defined($header{'content-type'})&&$header{'content-type'}=~/html/i) {
  $diag{'html'}=1;
  $diaglevel=1;
  $debugmsg .= "  $debugdiagmarker HTML detected (no multipart/alternative!).\n";
 };

 # * ---> check for multiparts
 if(defined($header{'content-type'}) and ($header{'content-type'}=~/multipart/)) {
  $diag{'multipart'}=1;
  $diaglevel ||= 1;
  $debugmsg .= "  $debugdiagmarker MIME-multipart identified.\n";
  $debugmsg .= "  Cannot check body of that posting - do not understand multipart yet.\n";
 };

 # apply checks to body only if there _is_ a body
 if (defined($wholebody)) {
  if(defined($header{'content-transfer-encoding'})) {
  
   # * ---> check for q/p (body)
   if ($header{'content-transfer-encoding'}=~/quoted/i){
    # $diag{'qp'}=1;    #-# 1.2.01k 
    # $diaglevel ||= 1; #-# 1.2.01k
    # $debugmsg .= "  $debugdiagmarker Content-transfer-encoding: quoted/printable.\n"; #-# 1.2.01k
    $debugmsg .= "  Content-transfer-encoding: quoted/printable.\n";
    $debugmsg .= "  Will decode that body now.\n";
    # convert quoted-printables to 8bit
    # $wholebody=~s/[ \t]\n/\n/sg;  # RFC 1521 5.1 Rule #3
    $wholebody=~s/=\n//sg;        # RFC 1521 5.1 Rule #5
    $wholebody=~s/=([0-9a-fA-F]{2})/pack("H2",$1)/sge;
   };
   
   # * ---> check for base64 (body)
   if($header{'content-transfer-encoding'}=~/base64/i){
    $diag{'base64'}=1;
    $diaglevel=1;
    $debugmsg .= "  $debugdiagmarker Content-transfer-encoding: Base64.\n";
    $debugmsg .= "  Will decode that body now.\n";
    $wholebody = decode_base64($wholebody); # do Base64-decoding
   };
  }

  # split $wholebody into single lines
  @body=split("\n",$wholebody);

  # terminate and return if $trigger_ignore is found in first line
  # (and $trigger_check not in Subject:) --> $docheck
  if (!$docheck and ($body[0] =~ /$trigger_ignore/io)) {
   $debugmsg .= "  TRIGGER: \"$trigger_ignore\" found in \"Subject:\"-line or first line of posting; terminating check.\n";
   $debugmsg .= "  --- End of Check Results  ---\n\n";
   op(15,"$header{'message-id'}:\n$debugmsg\n");
   return;
  }

  # * ---> check for charset / transfer-encoding
  if(!defined($diag{'multipart'})) {
   if($wholebody=~/[\x80-\xff]/){
#    (@problem) = $wholebody=~/([\x80-\xff])/g;
    $debugmsg .= "  Found 8bit-characters in body.\n";
#    $debugmsg .= "  @problem\n";
    if(defined($header{'content-type'})){
     if($header{'content-type'}!~/charset=/i){
      $diag{'nocharset'}=1;
      $diaglevel=2;
      $debugmsg .= "  $debugdiagmarker Header \"Content-Type:\" does not define charset.\n";
     };
     if($header{'content-type'}=~/us-ascii/) {
      $diag{'nocharset'}=1;
      $diaglevel=2;
      $debugmsg .= "  $debugdiagmarker Charset is \"US-ASCII\".\n";
     };
    }else{
     $diag{'nocharset'}=1;
     $diaglevel=2;
     $debugmsg .= "  $debugdiagmarker No charset defined.\n";
    }
    if(!defined($header{'content-transfer-encoding'})) {
     $diag{'nocontenttransferenc'}=1;
     $diaglevel=2;
     $debugmsg .= "  $debugdiagmarker No content-transfer-encoding defined.\n";
    };
   }
  }

  # * ---> check for vcards
  if($wholebody=~/(^begin:vcard\s*$)(.|[\n])+(^end:vcard\s*$)/im) {
   $diag{'vcard'}=1;
   $diaglevel ||= 1;
   $debugmsg .= "  $debugdiagmarker V-Card identified.\n";
  };

  $sigstart = $#body;
  # sig-delimiter and (too) long sigs
  for($i=$#body;$i>-1;$i--){        #-# 1.2.01i: fixed sigdelimiter first line
   if (defined($diag{'base64'})) {
    $body[$i] =~ s/\r$//;   # remove carriage returns (CR-CR-LF to CR-LF)
   };
   if($body[$i]=~/^(- )?--[^-]?\s*$/){
    $sigstart = $i;
    $debugmsg .= "  Possible sig-delimiter found in line " . ($i+1) . " of posting.\n";
    if ($body[$i] !~/^(- )?-- $/ and $sigokay == 0) {
     $diag{'sigdelimiter'} = 1;
     $wrongsig = $body[$i];
     $debugmsg .= "  $debugdiagmarker Sig-delimiter in line " . ($i+1) . " is wrong.\n";
     $debugmsg .= "  Sig-delimiter was \"$wrongsig\".\n";
    } else {
     $sigokay ||= $i+1;
     $debugmsg .= "  Sig-delimiter is correct or not checked.";
     if ($diag{'sigdelimiter'} == 1) {
      delete $diag{'sigdelimiter'};
      $debugmsg .= " - Reset error-message.\n";
     } else {
      $debugmsg .= "\n";     };
    };
    if($sigokay > 0) {
     $f = $sigokay-1;
    } else {
     $f = $i;
    };     
    if ($f+4<$#body) {
     $diag{'longsig'}=1;
     $diaglevel ||= 1;
     $debugmsg .= "  $debugdiagmarker Sig is too long [starting line ".($f+2)." - ending line ".($#body+1)."].\n";
    };
   }
  }
  if ($diag{'sigdelimiter'} == 1) {$diaglevel ||= 1;};

  # lines to long
  LINECHECK:
  for ($i=$sigstart; $i>=0; $i--) {
   last LINECHECK if(!defined($body[$i]));
   if(($body[$i]=~/^.{75,}$/) and ($body[$i]!~/^[ ]*[>|:]/)) {
    $diag{'longlines'}=1;
    $diaglevel ||= 1;
    $debugmsg .= "  $debugdiagmarker Line " . ($i+1) . " too long and not quoted.\n";
    $debugmsg .= "  Offending line: " . $body[$i] . "\n";
   };
  }

  if ($sigstart < $#body) {
   SIGCHECK:
   for ($i=$sigstart; $i<=$#body; $i++) {
    last SIGCHECK if(!defined($body[$i]));
    if($body[$i]=~/^.{81,}$/) {
     $diag{'longlinesig'}=1;
     $diaglevel ||= 1;
     $debugmsg .= "  $debugdiagmarker Line " . ($i-$sigstart) . " of signature too long.\n";
     $debugmsg .= "  Offending line: " . $body[$i] . "\n";
    }
   }
  }
 } else {
  $debugmsg .= "  Message does not contain body.\n"
 };

 # if config for any problem is empty (.rc-file!), reset diag
 foreach $i (keys %diag) {
  if(!defined($config{$i}) and defined($diag{$i})) {
   delete $diag{$i};
   $debugmsg .= "  ! Configuration: Text for [$i] missing - problem was found, but won't be reported.\n";
  }
 }

 # increase diaglevel if pedantic is on
 if ($pedantic) { $diaglevel += 1; };

 $debugmsg .= "  --- End of Check Results  ---\n\n";

 # if subject == 'check' or auto == 1 and $diaglevel > 1:
 # post followup
 if ($docheck or ($auto && ($diaglevel > 1))) {
  op(2,"Got one! ---> $header{'message-id'}\n");
  op(2,"Generating followup, writing to $testgroup ...");
  # generate followup
  @article = $config{'head'};
  push @article, "Newsgroups: $testgroup\n";
  ($m=$header{'message-id'})=~s/\@(.*)>$/%$1/;
  push @article, 'Message-ID: '.$m.'@checkbot.fqdn.de>'."\n";
  if(defined($header{'references'})) {
   push @article, "References: $header{'references'} $header{'message-id'}\n"
  } else {
   push @article, "References: $header{'message-id'}\n"
  } 
  ($wtag,$monat,$tag,$zeit,$jahr) = (split / +/, (scalar gmtime));
  push @article, "Date: $wtag, $tag $monat $jahr $zeit GMT\n";
  $f = "Subject: ";
  $f .= "Re: " unless ($header_decoded{'subject'}=~/^[ \t]*re:/i);
  $f .= &encode_header($header_decoded{'subject'});
  push @article, "$f\n";
  push @article, "X-Artchk-Version: artchk.pl (mod.) $version\n";
  if($header_decoded{'subject'}=~/(^|\s)replybymail(\s|$)/) {
   push @article, "X-Sorry: 'replybymail' not supported in this version.\n";
  }
  if ($auto==2) {
   push @article, "X-Comment: Check enforced by operator using '$0 -c'.\n";
  }
  push @article, "MIME-Version: 1.0\n";
  push @article, "Content-Type: text/plain; charset=ISO-8859-1\n";
  push @article, "Content-Transfer-Encoding: 8bit\n"; 
  push @article, "\n";
  if ($auto==2) {
   push @article, $config{'header-forced'}
  } elsif ($docheck) {
   push @article, $config{'header'}
  } elsif ($auto) {
   push @article, $config{'header-auto'}
  } else {
   push @article, "\nCHECKBOT INTERNAL ERROR!\n"
  }
  push @article, "\n";
  push @article, "$header_decoded{'from'} schrieb:\n\n";
  if(scalar @body==0){push @article, "[nichts]\n\n"}
  else{for(0..4){push @article, '>'.$body[$_]."\n" if defined $body[$_]}}
  push @article, "[...]\n" if (defined($body[5]));
  push @article, "\n";
  
  if(scalar keys %diag !=0){
   push @article, $config{'intro'},"\n";
   if (defined($diag{'duplicate'}) && $diag{'duplicate'}==1) {
    push @article, $config{'duplicate'},"\n";
    while ($_=shift @duplicate) {
     push @article, "|     $_\n";
    };
    push @article, "\n";                            #-# 1.2.01k
   };
   foreach $i (qw/from from-domain from-roles noname reply-to reply-to-domain reply-to-roles replytofrom date 
                  nomid 8bitheader nocharset nocontenttransferenc sigdelimiter longsig
		  multipart base64 html vcard longlines longlinesig /){       #-# 1.2.01k: removed qp
    if (defined($diag{$i}) && $diag{$i}==1) {
     push @article, ev($i), "\n";       # Variablen expandieren
    };
    if (defined($config{"$i-$nr"}) && $diag{$i}==1) {
     push @article, ev("$i-$nr"), "\n"; # Variablen expandieren
    };
   };
   if (defined($config{'umlauts'})) {
    push @article, $config{'umlauts'},"\n" if((defined($diag{'nocharset'})) && ($diag{'nocharset'}==1) or
                                              (defined($diag{'8bitheader'})) && ($diag{'8bitheader'}==1));
   };
   if (defined($config{'violation'}) && $diaglevel > 1) {   #-# 1.2.01k
    push @article, "$config{'violation'}\n";
   };
   push @article, $config{'nr'},"\n";
   if (defined($nr) and (defined($config{$nr}))) {
    push @article, ev('nr-known'), "\n"; # Variablen expandieren
    push @article, ev($nr), "\n";        # Variablen expandieren
   };
   if (defined($header{'x-trace'}) and ($header{'x-trace'}=~/^fu-berlin.de/) and defined($config{'newscis'})) {
    push @article, "$config{'newscis'}\n";
   };
  }else{
   push @article, $config{'allok'},"\n";
  }
  
  if ($header_decoded{'subject'}=~ /$trigger_check verbose/io) {
   push @article, $config{'debug'};
   ($f=$debugmsg)=~s/\n/\n\| /g;
   $f = '| ' . $f . "\n\n";
   push @article, $f;
  };
  
  push @article, $config{'footer'};
  
  if ($feedmode) {           #-# 1.2.01k ---->
   # open server for posting
   if ($postingserver ne '') {
    $postserver = &connectserver($postingserver,$postingport,$posts_user,$posts_pass)
   } else {
    $postserver = &connectserver($server,$port,$s_user,$s_pass);
   };
   $f = \$postserver;
  } else {                   #-# 1.2.01k <-----
   if ($postingserver ne '') {
    $f = \$postserver;
    $i = "$postingserver";
    if ($postingport ne '') {
      $i .= "(Port $postingport)";
    }
   } else {
    $f = \$readserver;
    $i="$server";
    if ($port ne '') {
      $i .= " (Port $port)";
    }
   }
  };
  if (!($$f->post(@article))) {                                             #-# 1.2.01g
   op(13,"\n$serverresponse Error: " . $$f->code . ' ' . $$f->message);
   op(0,"Error writing followup to $i.\n");
   if ($$f->message =~ /imeout/ and $postingserver ne '') {
    op(10,"Retry due to timeout ...");
    $postserver = &connectserver($postingserver,$postingport,$posts_user,$posts_pass);
    if (!($postserver->post(@article))) {
     op(13,"\n$serverresponse Error: " . $$f->code . ' ' . $$f->message);
     op(0,"Error writing followup to $i during retry.\n");
    } else {
     op(2," done (written to $i).\n");
     op(2,"Message-ID was $m\@checkbot.fqdn.de>.\n");
     op(3,"$serverresponse".$postserver->code.' '.$postserver->message);
    };
   };
  } else {
   op(2," done (written to $i).\n");
   op(2,"Message-ID was $m\@checkbot.fqdn.de>.\n");
   op(3,"$serverresponse".$$f->code.' '.$$f->message);
  };
  if ($feedmode) {           #-# 1.2.01k
   $postserver->quit;
  };
  op(14,"\n$header{'message-id'}:\n$debugmsg\n\n");
 } else {
  op(15,"$header{'message-id'}:\n$debugmsg\n");
 }
} 

################################################################
# Subroutines: get_mail_address
#              encode_header / hdecode / dodecode
#              evaluate variables
#              generic output routinte (instead of 'print')
#              connect to server

sub getmailaddress {
 my($raw)=shift;
 my($tmp,$address,$name,$lp,$dp,$type);
 if($raw=~/^<?($r_address)>?$/) {
  $type = 1;
  $address = $1; 
  $name = '';
 } elsif($raw=~/^($r_address)\s+\($r_paren_phrase\)\s*$/) {
  $type = 2;
  $address = $1; 
  $tmp = quotemeta($address);
  ($name = $raw) =~ s/^$tmp\s+\(([^()]+)\)$/$1/;
 } elsif($raw=~/^(($r_quoted_word|$r_unquoted_word)(\s+($r_quoted_word|$r_unquoted_word))*)\s+<$r_address>\s*$/) {
  $type = 3;
  $name = $1;
  ($address = $raw) =~ s/.*<($r_address)>\s*$/$1/;
 };
 ($lp = $address) =~ s/^([^@]+)@.*/$1/;
 ($dp = $address) =~ s/\S*\@(\S*)$/$1/;
 chomp ($address, $name, $lp, $dp, $type);
 foreach $tmp ($address, $name, $lp, $dp, $type) {
  $tmp = lc($tmp);
 };
 return $address, $name, $lp, $dp, $type;
}

sub checkfromrp {
 # * ---> check from-header / reply-to
 my ($headername) = shift;
 my $hname = lc($headername);
 my($address,$name,$locpart,$dompart,$type)=&getmailaddress($header_decoded{$hname});
 my $tld;
 ($tld = $dompart) =~ s/.*\.([^.]+)$/$1/;        # isolate TLD
 $tld = lc($tld);
 if ($hname eq 'from') {
  if($type==1) {
   $debugmsg .= "  \"From:\"-header is type 1 [address\@do.main].\n";
  }elsif($type==2) {
   $debugmsg .= "  \"From:\"-header is type 2 [address\@do.main (full name)].\n";
  }elsif($type==3) {
   $debugmsg .= "  \"From:\"-header is type 3 [full name <address\@do.main>].\n";
  }else{
   $diag{'from'}=1;
   $diaglevel=2;
   $debugmsg .= "  $debugdiagmarker \"From:\"-syntax is incorrect.\n";
  };
 } else {
  if($type==0) {
   $diag{'reply-to'}=1;
   $diaglevel=2;
   $debugmsg .= "  $debugdiagmarker \"Reply-To:\" is incorrect.\n";
  };
 }
 $f = lc($dompart);
 if($f =~ /[^a-z0-9\-.]/) {
  $diag{$hname}=1;
  $diaglevel=2;
  $debugmsg .= "  $debugdiagmarker \"$headername:\" is incorrect: invalid chars in domain.\n";
 };
 if($type!=0) {
  # domain
  if(!defined($domain{$tld})) {
   $diag{"$hname".'-domain'}=1;
   $diaglevel=2;
   $debugmsg .= "  $debugdiagmarker \"$headername:\" is incorrect: no valid TLD.\n";
  # MX-/A-lookup
  } else {
   if ($online) {
    $res = Net::DNS::Resolver -> new();
    $res->usevc(1);
    $res->tcp_timeout(15);
    $i='okay';          #-# 1.2.01i: fixed 'bug' in logging DNS-checks
    @mx = mx($res,$dompart) or $i = $res->errorstring;
    $debugmsg .= "  DNS (\"$headername:\"): $i.\n";   #-# 1.2.01i: fixed 'bug' in logging DNS-checks
    if ($i eq 'NXDOMAIN' or $i eq 'NOERROR') {
     $debugmsg .= "  No MX-record for \"$dompart\": $i.\n";
     $i='okay';      #-# 1.2.01i: fixed 'bug' in logging DNS-checks
     $query = $res->search($dompart) or $i = $res->errorstring;
     $debugmsg .= "  DNS (\"$headername:\"): $i.\n";   #-# 1.2.01i: fixed 'bug' in logging DNS-checks
     if ($i eq 'NXDOMAIN' or $i eq 'NOERROR') {
      $debugmsg .= "  $debugdiagmarker No A-record either: $i - \"$headername:\" is not replyable.\n";
      $diag{"$hname".'-domain'}=1;
      $diaglevel=2;
     };
    };
   };
  };
  # no name, just address?
  if ($hname eq 'from') {
   if($name !~ /[a-z][^.]\S*\s+\S*([a-z][^.]\S*)+/i) {
    $diag{'noname'}=1;
    $diaglevel ||= 1;
    $debugmsg .= "  $debugdiagmarker \"From:\" does not contain full name.\"\n";
   };
  };
  # check for role accounts
  ROLES: foreach $f (@roles) {
   if ($f eq lc($locpart)) {
    $diag{"$hname".'-roles'}=1;
    $diaglevel ||= 1;
    $debugmsg .= "  $debugdiagmarker \"$headername:\" contains role account.\"\n";
    last ROLES;
   };
  };
 };
 if (defined($diag{$hname}) or defined($diag{"$hname".'-domain'}) or defined($diag{"$hname".'-roles'}) or ($debuglevel > 4)) {
  $debugmsg .= "  \"$headername:\": \"$header{$hname}\".\n";
  if ($header{$hname} ne $header_decoded{$hname}) {
   $debugmsg .= "  \"$headername:\" (decoded): \"$header_decoded{$hname}\".\n";
  };
 } elsif (defined($diag{'noname'}) and ($hname eq 'from')) {
  $debugmsg .= "  \"From:\": \"$header{'from'}\".\n";
  if ($header{'from'} ne $header_decoded{'from'}) {
   $debugmsg .= "  \"From:\" (decoded): \"$header_decoded{'from'}\".\n";
  };
 };
 return ($locpart,$dompart);
}

sub encode_header {
 my $header=shift;
 my ($word,$space,$encoded_header);
 while ($header=~/(\S+)(\s*)/g) {
  ($word,$space) = ($1,$2);
  if ($word=~/[\x80-\xFF]/) {
   $word='=?iso-8859-1?Q?'.encode_qp($word).'?=';
  }
  $encoded_header .= "$word$space";
 }
 $encoded_header =~ s/\?=(\s+)=\?iso-8859-1\?Q\?/$1/g;
 return $encoded_header;
}


sub hdecode {
  my $header=shift;
  if ($header=~/=\?.*\?(.)\?(.*)\?=/) {
    $header=~s/=\?.*\?(.)\?(.*)\?=/&dodecode($1,$2)/ge;
  };
  $header=~s/\n\t//; # unfold headers
  return $header;
}


sub dodecode {
 # decode RFC 1522 headers
 my $enc=shift;
 my $etext=shift;

 if($enc=~/^q$/i){
  $etext=decode_qp($etext);
  $etext=~s/_/' '/ge;
 }elsif($enc=~/^b$/i){
  $etext=decode_base64($etext); 
 }else{$etext=''}
 return $etext;
}


sub op {
# (debug) output
# level 0         : error messages, introduction/end
# level 1 (-v)    : + configuration and summaries 
# level 2 (-vv)   : + progress indicator
# level 3 (-vvv)  : + NNTP-replies from server(s)
# level 4 (-vvvv) : + debug-output from check-routines
# level >=10      : output also to logfile if activated
 my($level,$text,$handle) = @_;
 if ($level >= 10) {
  if ($logging) { print LOG $text; };
  $level -= 10;
 };
 $handle ||= 'STDOUT';
 if ($debuglevel >= $level and not $feedmode) {
  print $handle $text;
 };
}



sub connectserver {
 my($server,$port,$s_user,$s_pass) = @_;

 # connect to server
 op(0,"Connecting to news server ...");
 my $c = new News::NNTPClient($server,$port);

 if (!($c->code)) {
  op(0,"\nCan't connect to server. Aborting.\n");
  die "\nCan't connect to server. Aborting.\n";
 } else {
  op(0," done.\n");
 }

 $c->postok() or op(0,"Server does not allow posting?!\n");

 op(3,"$serverresponse".$c->code.' '.$c->message);

 # switch off error messages from News::NNTPClient
 $c->debug(0);

 # mode reader
 op(1,'MODE reader ...');
 if (!($c->mode_reader)) {
  op(10,"\n$serverresponse Error: " . $c->code . ' ' . $c->message . "Aborting.\n");
  die '$serverresponse Error: ' . $c->code . ' ' . $c->message . "Aborting.\n";
 } else {
  op(1," done.\n");
  op(3,"$serverresponse".$c->code.' '.$c->message);
 };

 # authorize, if needed
 if ($s_user ne '') {
  op(1,"Authentification ...");
  if ($c->authinfo($s_user,$s_pass)) {
   op(1," done.\n");
  } else {
   op(0,"\nAuthentification failure. Aborting.\n");
   die "\nAuthentification failure. Aborting.\n";
  }
  op(3,"$serverresponse", $c->code, ' ', $c->message);
 };

 op(0,"\n");
 $c;
}


################################################################
# Subroutines for reading / writing files
# - read rc
# - read/write ini
# - read domains

sub readrcfile {
 my($a,$i);
 open(RC,'<'.$pathtoini.$rcname.'.rc')||die "Could not open $pathtoini"."$rcname.rc for reading: $!";
 $a='';
 until(eof(RC)){
  $i=<RC>;
  next if(substr($i,0,1) eq ';');
  if($i=~/^\[.*\]$/){ $a=substr($i,1,-2);next; }
  $config{$a}.=$i;
 }
 close(RC);
 # check for _necessary_ entries
 foreach $i (qw/head header header-auto footer intro allok nr debug/) {
  if(!defined($config{$i})){
   op(0,"The entry [$i] is missing in the $rcname.rc file. This entry\n");
   op(0,"is necessary.\n");
   exit(1);
  }
 }
 # check for other entries
 foreach $i (qw/multipart html vcard nocharset nocontenttransferenc base64 nomid
             nomid-moz longlines longlinesig 8bitheader replytofrom reply-to sigdelimiter
             sigdelimiter-oe date from noname longsig umlauts nr-known oe moz agent
             xnews gnus macsoup slrn newscis from-domain from-roles reply-to-domain reply-to-roles/) {  #-# 1.2.01k: removed qp
  if(!defined($config{$i})){
   op(0,"\n.rc: The entry [$i] is missing in the $rcname.rc file.\n");
   op(0,"     Corresponding check will be skipped.\n");
  }
 }
}


sub readini {
 my($a,$b,$c);
 open(INI,'<'.$pathtoini.$ininame.'.ini')||die "Could not open $pathtoini"."$ininame.ini for reading: $!";
 until(eof(INI)) {
  $c=<INI>;
  if ($c=~/=/) {         # if '=' is found in line
   chomp(($a,$b)=split(/=/,$c));   # split it into parametername and -contents
   $a=~s/^\s*(.*?)\s*$/$1/g;        # delete leading/trailing whitespace
   $b=~s/^\s*(.*?)\s*$/$1/g;        # delete leading/trailing whitespace
   if ($a eq 'reader') {
    chomp(($server,$port)=split(/,/,$b));
   } elsif ($a eq 'reader_user') {
    chomp($s_user=$b);
   } elsif ($a eq 'reader_pass') {
    chomp($s_pass=$b);
   } elsif ($a eq 'poster') {
    chomp(($postingserver,$postingport)=split(/,/,$b));   
   } elsif ($a eq 'poster_user') {
    chomp($posts_user=$b);
   } elsif ($a eq 'poster_pass') {
    chomp($posts_pass=$b);
   } elsif ($a eq 'trigger_check') {
    chomp($trigger_check=$b);
   } elsif ($a eq 'trigger_ignore') {
    chomp($trigger_ignore=$b);
   } elsif ($a eq 'rcfile') {
    chomp($rcname=$b);
   } elsif ($a eq 'killfile') {
    chomp($killname=$b);
   }
  } elsif ($c =~/checkgroups:/) {
   until(eof(INI)){
    chomp(($a,$b,$c)=split(/ /,<INI>));
    @testgroups = (@testgroups, $a) unless ($a!~/^\w+(\.\w+)+/);
    if ($b eq 'y') {
     $auto{$a} = 1;
    }else{
     $auto{$a} = 0;
    };
    $watermark{$a} = $c;
    if (!defined($watermark{$a})) {$watermark{$a} = 0};
   }
  }
 }
 close(INI);
 if($server eq '') {
  op(0,"You have to define a reading server in $ininame.ini\n");
  exit(1);
 }
 if($trigger_check eq '') {
  $trigger_check='check';
 }
 if($trigger_ignore eq '') {
  $trigger_ignore='(ignore)|(no[ ]*repl(y|(ies)))|(nocheck)';
 }
 if($rcname eq '') {
  $rcname=$ininame;
 } elsif ($rcname=~/\.rc$/) {
  $rcname=~s/(.*?)\.rc$/$1/;
 }
 if($killname eq '') {
  $killname=$ininame;
 } elsif ($killname=~/\.kill$/) {
  $killname=~s/(.*?)\.kill$/$1/;
 }
 if(scalar(@testgroups) == 0) {
  op(0,"You have to define at least one testgroup in $ininame.ini\n");
  exit(1);
 }
}


sub writeini {
 my($r,$tmp,$point);
 open(INI,'<'.$pathtoini.$ininame.'.ini')||die "Could not open $pathtoini"."$ininame.ini for reading: $!";
 until(eof(INI)) {
  $r = <INI>;
  $tmp .= $r;
  if ($r =~/checkgroups:/) {
   last;
  }
 }
 close (INI);
 open(INI,'>'.$pathtoini.$ininame.'.ini')||die "Could not open $pathtoini"."$ininame.ini for writing: $!";
 print INI $tmp;
 foreach $testgroup (@testgroups) {
  print INI "$testgroup ";
  if ($auto{$testgroup} == 0) {
   print INI 'n '
  }else{
      print INI 'y '
  };
  print INI "$watermark{$testgroup}\n";
 }
 close(INI);
}


sub readdomains {
 my ($i,@domains); 
 open(DOM,'<'.$pathtoini.'domains')||die "Could not open \"$pathtoini"."domains\" for reading: $!";
 chomp(@domains = split(/ /,<DOM>));
 close(DOM);
 $i = 0;
 until(!defined(@domains[$i])) {
  $domain{$domains[$i]} = 'valid';
  $i++;
 };
}

__END__
