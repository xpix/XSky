#!/usr/bin/env perl
use lib "lib/";

use strict;
use warnings;

use AnyEvent;
use XSKY;

my $cfgfile = shift 
   or die "Please call $0 path_to_configfile!";

my $DEBUG = shift || 0;

my $xsky    = XSKY->new($cfgfile, $DEBUG);
my $convar  = AnyEvent->condvar;

my $interval = $xsky->cfg('Interval') || 300; # intervall in seconds

unlink $xsky->cfg('WavPath');

printf "
   Main Program ... 
   Open Source balloon tracker
   (c) 2015 / Frank (xpix) Herrmann
   Walldorf / Germany

";

# ------------- Main Loop ------------
# Timer to send aprs every x minutes
my $aprs_timer = AnyEvent->timer (
   after    => ($DEBUG ? 0 : 60), 
   interval => $interval, 
   cb => sub { 
      $xsky->interval();
   });

$convar->wait;

exit;

