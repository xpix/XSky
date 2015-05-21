#!/usr/bin/env perl
use lib "lib/";

use strict;
use warnings;

use Mojolicious::Lite;
use Mojo::IOLoop;
use GPS::NMEA;
use Device::BCM2835;

# ------------- GLOBAL VARS ----------------
my $SPort = shift || '/dev/ttyAMA0';
my $DEBUG = 1;
my $gps   = GPS::NMEA->new(Port => $SPort, Baud => 9600);
my $CallSign = 'DH6IAG';
my $WavPath  = '/run/shm/aprs.wav';
my $interval = 300; # intervall in seconds
my $aprs_bin = '/usr/local/bin/aprs';
my $aplay    = '/usr/bin/aplay';
my $amixer   = '/usr/bin/amixer';
my $ping     = '/bin/ping';

# ------------- Set Audio Output ------------
# Device::BCM2835::set_debug(1);
Device::BCM2835::init();
Device::BCM2835::gpio_fsel(&Device::BCM2835::RPI_V2_GPIO_P1_12, &Device::BCM2835::BCM2835_GPIO_FSEL_ALT5);
Device::BCM2835::gpio_fsel(&Device::BCM2835::RPI_V2_GPIO_P1_16, &Device::BCM2835::BCM2835_GPIO_FSEL_OUTP);    

# ------------- INTERVAL -------------------
Mojo::IOLoop->recurring($interval => sub {
   my $self = shift;

   # Get GPS Position
   my($ns,$lat,$ew,$lon,$alt) = ($gps->get_position, $gps->{NMEADATA}->{alt_meters} || 0);
   warn scalar localtime." GPS: $ns, $lat, $ew, $lon, $alt\n" 
      if $DEBUG;

   # Check if altitude change, if not then the balloon has landed and 
   # we switch the wlan on for next 5 minutes then switch off for 5 min
   # my $wlanState = app->checkWlan( $alt );

   # Get Temperatures and other Data
   my $sensors = app->getSensorData();
   
   # Build ARPS String
   my $aprs = app->aprs_build($gps, $sensors);
   warn "Build Aprs: '$aprs'\n" if $DEBUG;

   # Create aprs wav audio file
   my $wavefile = app->aprs_wav($aprs);

   # Send aprs wav audio file
   my $result = app->aprs_send($wavefile);

});

# ------------- HELPERS ---------------------
helper getSensorData => sub {
   my $self    = shift;

   return {};
};

helper aprs_build => sub {
   my $self    = shift;

   return sprintf('WIDE2-1:/%sh%s%s/%s%sO%03d/%03d/A=%06d/FSHABIII Balloon',
            $gps->{NMEADATA}->{ddmmyy},      # 130515 
            $gps->{NMEADATA}->{lat_ddmm},    # 4913.19258
            $gps->{NMEADATA}->{lat_NS},      # N
            $gps->{NMEADATA}->{lon_ddmm},    # 00831.27270
            $gps->{NMEADATA}->{lon_EW},      # E
            $gps->{NMEADATA}->{course_made_good} || '000',      # 054
            $gps->{NMEADATA}->{speed_over_ground} || '000',      # 054
            $gps->{NMEADATA}->{alt_meters} || 0,      # 054
         );
};

helper aprs_wav => sub {
   my $self    = shift;
   my $aprs    = shift or return;
   
   $self->sys($aprs_bin, "-c $CallSign --output $WavPath '$aprs'");

   return $WavPath;
};

helper aprs_send => sub {
   my $self    = shift;
   my $wavefile= shift or return;

   # switch RF ON via GPIO
   Device::BCM2835::gpio_write(&Device::BCM2835::RPI_V2_GPIO_P1_16, 0);
   # wait a half second
   Device::BCM2835::delay(200); # Milliseconds

   app->sys($amixer, '-d set PCM -- 200');
   app->sys($aplay, $wavefile);

   # wait a half second
   Device::BCM2835::delay(200); # Milliseconds
   # switch RF OFF via GPIO
   Device::BCM2835::gpio_write(&Device::BCM2835::RPI_V2_GPIO_P1_16, 1);

   unlink($wavefile);

   return 1;
};

# Check if altitude change, if not then the balloon has landed and 
# we try to connect to an Access Point (Laptop, RPI)
# http://unix.stackexchange.com/questions/12005/how-to-use-linux-kernel-driver-bind-unbind-interface-for-usb-hid-devices
# http://raspberrypi.stackexchange.com/questions/6782/commands-to-simulate-removing-and-re-inserting-a-usb-peripheral
# sudo sh -c 'echo 1-1 > /sys/bus/usb/drivers/usb/unbind'
# sudo sh -c 'echo 1-1 > /sys/bus/usb/drivers/usb/bind'
helper checkWlan => sub {
   my $self    = shift;
   my $alt     = shift || return;

   # Init wlanState and old altitude
   $self->{wlan_state} = 0 if(not exists $self->{wlan_state});
   $self->{old_alt} = 0    if(not exists $self->{old_alt});

   # Altitude not changed?
   if($self->{old_alt} == $alt){
      # ping => ok ... return
      if(app->sys($ping, '-c 1 www.google.de')){
         return 1;
      }
      else {
         # Switch USB WLAN ON
         # Try to connect to an Access Point
         # wait a minute 
         # ping
         # fail => wlan off
      }
   }
   else {
      # Changed Altitude
      # check if USB WLAN off
      # if not switch USB Wlan off
   }

   $self->{old_alt} = $alt;
   return $self->{wlan_state};
};

# Call system command
helper sys => sub {
   my $self    = shift;
   my $command = shift;
   my @params  = @_;
   
   my $systemcmd = sprintf('%s %s 2>&1', $command, join(' ', @params));
   my $output = `$systemcmd`;
   
   if($? == 0){
      return $output;
   }
   die sprintf('Call return wrong exit status %d: %s for cmd "%s"', $?, $output, $systemcmd);
};

# ------------- MOJO Routes ----------------
get "/" => 'index';
get "/main\.js"  => { template => 'main', format => 'js' } => 'main-js';
get "/main\.css" => { template => 'main', format => 'css'} => 'main-css';




app->start;
__DATA__

@@ index.html.ep
<html>
<head><title>main</title>
    <script src="http://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js"></script>
    <script src="<%= url_for 'main-js' %>"></script>
    <link rel="stylesheet" type="text/css" href="<%= url_for 'main-css' %>">
</head>
<body><h1>This is main</h1><div id=content><p>Lorem Ipsum</p></div></body>
</html>

@@ main.js.ep
/* this is main.js, double the amount of Lorem's */
$(function(){ $('#content').append( $('<p>and more Ipsums..</p>') ) });

@@ main.css.ep
h1 { color: #eaa; font-size: 36px; }