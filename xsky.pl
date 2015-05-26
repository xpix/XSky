#!/usr/bin/env perl
use lib "lib/";

use strict;
use warnings;

use AnyEvent;
use AnyEvent::HTTPD;
use XSKY;

my $interval = 300; # intervall in seconds

my $xsky    = XSKY->new();
my $convar  = AnyEvent->condvar;
my $httpd   = AnyEvent::HTTPD->new (port => 19090);

# ------------- Main Loop ------------
# Timer to send aprs every x minutes
my $aprs_timer = AnyEvent->timer (
   after    => 5, 
   interval => $interval, 
   cb => sub { 
      $xsky->interval();
   });


# ------------- Simple Webserver -----
$httpd->reg_cb (
   '' => sub {
      my ($httpd, $req) = @_;
      my $html = '
         <html><body><h1>Hello World!</h1>
         <a href="/test">another test page</a>
         </body></html>
      ';
      $req->respond ({ content => ['text/html', $html]});
   },
   '/test' => sub {
      my ($httpd, $req) = @_;
      my $html = '
         <html><body><h1>Test page</h1>
         <a href="/">Back to the main page</a>
         </body></html>
      ';
      $httpd->stop_request;

      $req->respond ({ content => ['text/html', $html]});
   },
);

$convar->wait;

exit;

