# Present idea XSky
XSky will be the smallest, lightwight and cheapest High Altitude Ballon Payload (HAB). I have some Experiences with two flights of HAB'S  here in germany. 

# Flights in the past
The first was a disaster, we let the balloon fly and he was gone. The second was better, we start the balloon and can follow him, we used a radio set and this send the data via baud2audio to a public gateway. After landing we got a big problem. The payload was landing on the %&$§ highest tree in the forest. After a lot of try's a forrest worker help us to get the payload back.

# What we have learned?
Here some global points to have a successfull flight:
  - Choose a payload that u don't have to ask the gouverment for a fly. Here in Germany the payload have to be under 500g.
  - Use a very long distance between the parachoute and the payload, ~10m. If balloon  land on a tree then you can get your payload.
  - Try to make a very(!) small and light payload as possible.

# Hardware or BOM
  - Raspberry pi Zero W
  - GPS Module 3.3V http://www.ebay.de/itm/272499528287
  - LoRa Module(s) SX1278
  - Temperatursensor(s) (outside/inside)
  - DIY HAT PCB for Raspberry
  - Powerbank ~3Ah via USB

# How works the payload
Everything will controlled over the altitude meters in this software. An intelligent system measure this value and switch on and off some functions:

* start payload and gps measure < 1000m altitude: WIFIAP on (to control via mobile the payload), Video on, LoRa on, GPS on
* altitude > 1000m: WIFIAP off, Video on frequently (5min on/5min off), GPS on, LoRa on
* altiude < 1000m: Wifi on/off (every 1min), LoRa on, Video off (altitude not changed for 1 min == landed)

# Framework of XSky
Please read my Instrcutions to install this Framework on your Raspberry: https://github.com/xpix/XSky/blob/master/README.md

```sh
$ cd dillinger
$ npm install -d
$ node app
```

