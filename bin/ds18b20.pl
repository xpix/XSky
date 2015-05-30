#!/usr/bin/perl
$sensor_temp = `cat /sys/bus/w1/devices/*-*/w1_slave 2>&1`;
if ($? == 0)
{
   if ($sensor_temp !~ /NO/)
   {
      $sensor_temp =~ /t=(\d+)/i;
      $tempreature = ($1/1000); # My sensor seems to read about 6 degrees high, so quick fudge to fix value

      print "$tempreature\n";
      exit;
   }
   die "Error locating sensor file or sensor CRC was invalid";
}
