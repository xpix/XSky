# XSky
perl controller for a sky payload with raspberry A+

# Features
* send APRS String over GPIO as Soundmodem afsk
* add an access point if altitude not changed
* display a webpage with all informations (GPS/Sensors/...)
* record video via RPI Cam to SD Card

# Install
Module:
* http://search.cpan.org/~mikem/Device-BCM2835-1.8/lib/Device/BCM2835.pm
* http://search.cpan.org/~srezic/perl-GPS/ (in git)

Packages:
* sudo apt-get install hostapd dnsmasq (for WLAN AccesPoint)
* https://menzerath.eu/artikel/raspberry-pi-als-wlan-access-point-nutzen/ (German)
