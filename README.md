# XSky
perl controller for a sky payload with raspberry A+

# Features
* send APRS String over GPIO as Soundmodem afsk
* get sensor data's direct over GPIO
* try to connect to wifi acces point (iphone tethering) every x minutes when altitude not changed
* display a webpage with all informations (GPS/Sensors/...)
* record video via RPI Cam to SD Card
* start script for reboot or crashes
* use ssdv for live pictures via LoRa Modules at 433 MHz


# Install

sudo aptitude install \
   libjson-xs-perl \
   gpsd \
   libdatetime-perl \
   gpsd-clients \
   libnet-gpsd3-perl \
   libanyevent-perl \
   libanyevent-httpd-perl

# Configure
* sudo dpkg-reconfigure gpsd


# Test
* call cgps -s
* check your position on aprs.fi o.a.
