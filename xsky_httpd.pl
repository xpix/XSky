#!/usr/bin/env perl
use lib "lib/";

use strict;
use warnings;

use AnyEvent;
use AnyEvent::HTTPD;
use XSKY;

my $cfgfile = shift 
   or die "Please call $0 path_to_configfile!";

my $xsky    = XSKY->new($cfgfile);
my $HTTPD_PORT = $xsky->cfg->{HTTPD_PORT} || 9080;

my $convar  = AnyEvent->condvar;
my $httpd   = AnyEvent::HTTPD->new (port => $HTTPD_PORT);

printf "
   HTTPS Service on Port $HTTPD_PORT
   Open Source balloon tracker
   (c) 2015 / Frank (xpix) Herrmann
   Walldorf / Germany

";

my $data;
my $aprs_timer = AnyEvent->timer (
   after    => 0, 
   interval => 60, 
   cb => sub { 
      my $tmp = $xsky->data();                 # get GPS Data
      if($tmp->{gps}->{'lat'}){
         $data->{'gps'}->{old} = '';
         $data = $tmp; # use only good data
      }else{
         $data->{'gps'}->{old} = scalar localtime          # mark data as old data
            if(not exists $data->{'gps'}->{old});
      }
      $data->{cfg} = $xsky->cfg;             # Configuration data
      $data->{sen} = $xsky->getSensorData;   # Sensor data

      # Check if altitude change, if not the balloon has landed and 
      # we try connect to home ssid (Iphone tethering)
      my $wlanState = $xsky->checkWlan( $data->{gps}->{'alt'} );
   });

# ------------- Simple Webserver -----
$httpd->reg_cb (
   '' => sub {
      my ($httpd, $req) = @_;
      my $html = `cat templates/index.html`;
      
      my $block_warning = '';
      $block_warning = qq|<div class="alert alert-warning" role="alert">Bad GPS Signal. Last good data: $data->{gps}->{'old'}</div>|
         if($data->{gps}->{'old'});

      $html = eval 'return qq#'.$html.'#;'; # interpolate from data
      $req->respond ({ content => ['text/html', $html]});
   }
);

$convar->wait;

exit;

