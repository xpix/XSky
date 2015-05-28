# XSky
Controller written in perl for a sky payload with raspberry A+. 

This controller will fly in a payload on a helium ballon near to the sky. I'll use a raspberry A+ becouse to save (a lot) of Energy. I'll use a SD-Card with 32GByte to save the recorded videos (segements a x minutes). The Idea, at the ground the controller recognize that the altitude soesnt change. In this case he try to find a WIFI (Your Phone Tethering Wlan), the user run around the last sended position and the payload connect automaticly. Now he can download all videos or check the website to get his position.



# Hardware
(thats only examples and my personal setup)
* Raspberry PI A+: https://www.raspberrypi.org/products/model-a-plus/
* SD Card 32GB: http://amzn.com/B00M55C0NS
* Wifi Stick for RPI: http://amzn.com/B003MTTJOY
* Baofeng UV-3r Two way radio: http://amzn.com/B007UMQUPA 
* GPS Neo6 Module: http://amzn.com/B00H28RUSS
* DS18B20 Sensor Waterproof: http://amzn.com/B008HODWBU
* BMP180 Module: http://amzn.com/B00PQ2Z7UA
* some dupont wires: http://amzn.com/B00A6SOGC4
* 

# Features
* send APRS String over GPIO as Soundmodem afsk
* get sensor (outside temperature, pressure, ...) data's direct over GPIO and I2C
* try to connect to wifi acces point (iphone tethering) every x minutes if altitude not changed
* auto switch off wifi if payload flying to save energy
* check battery voltage _ToDo_
* display a webpage with all informations (GPS/Sensors/...)
* record video via RPI Cam to SD Card
* start script for reboot or crashes
* use ssdv for live pictures via LoRa Modules at 433 MHz


# Install

I use the raspbian image: https://www.raspbian.org/
To install please call this command line in your _fresh_ raspberry.
```
sudo aptitude install pip python-pyaudio \
   libjson-xs-perl \
   gpsd \
   libdatetime-perl \
   gpsd-clients \
   libnet-gpsd3-perl \
   libanyevent-perl \
   libanyevent-httpd-perl
   
sudo pip install afsk
```
Also you have to install the python afsk package for encode the APRS String in AFSK1200.

# Configure
* sudo dpkg-reconfigure gpsd


# Test
* call cgps -s
* check your position on aprs.fi o.a.
