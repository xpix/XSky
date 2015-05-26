package XSKY;
# ------------- XSKY Module -------------------

# ------------- MODULES  ----------------
use JSON::XS qw(decode_json);

# ------------- GLOBAL VARS ----------------
my $SPort    = shift || '/dev/ttyAMA0';
my $CallSign = shift || 'DH6IAG-11';
my $WavPath  = '/run/shm/aprs.wav';
my $aprs_bin = '/usr/local/bin/aprs';
my $aplay    = '~/XSky/bin/send_aprs';
my $ping     = '/bin/ping';
my $nice     = '/usr/bin/nice';
my $gpscmd   = '/usr/bin/gpspipe -w -n 10 | grep --color=never TPV | head -1';
my $DEBUG    = 1;
my $GPS      = {};

sub new {
   my $class = shift;
   my $self = {};
   bless $self, $class;

   unlink($WavPath);

   return $self;
}
  
sub interval {
   my $self = shift;
   my $good = 0;

   # Get GPS Position from running gpsd
   my $i = 0;
   while($i++ < 5){
      $GPS = eval{ decode_json( $self->sys($gpscmd)) };
      warn $@ && next if($@);
      $GPS->{lat_NS} = 'N';
      $GPS->{lon_EW} = 'E';
                  
      warn scalar localtime.sprintf(" GPS: %s, %s, %s, %s, %s\n",
         $GPS->{lat_NS}, $GPS->{lat}, $GPS->{lon_EW}, $GPS->{lon}, $GPS->{alt} )
            if $DEBUG;

      last if($GPS->{lat} and $GPS->{alt});
   }


   if(not $GPS->{lat}){
      if($self->{gpsfail}++ >= 2){
         $self->sys('sudo', 'reboot');
      }
      warn "No GPS Position!";
      return 0;
   }
   else {
      $self->{gpsfail} = 0;
   }

   # Check if altitude change, if not the balloon has landed and 
   # we try connect to home ssid (Iphone tethering)
   my $wlanState = $self->checkWlan( $GPS->{alt} );

   # Get Temperatures and other Data
   my $sensors = $self->getSensorData();
   
   # Build ARPS String
   my $aprs = $self->aprs_build($sensors);
   warn "Build Aprs: '$aprs'\n" if $DEBUG;

   if(not -s $WavPath){
      # Create aprs wav audio file
      my $wavefile = $self->aprs_wav($aprs);
   
      # Send aprs wav audio file
      my $result = $self->aprs_send($wavefile);
   }
   else {
      warn "Skip wave generation for other process\n";
   }
};

# ------------- HELPERS ---------------------
sub getSensorData {
   my $self    = shift;

   return {};
};

sub aprs_build {
   my $self    = shift;

   # '2015-05-24T17:41:48.000Z'
   ($GPS->{'time'}) = $GPS->{'time'} =~ /T(.+?)\./si; # 
   $GPS->{'time'} =~ s/\://sig;

   # Calculate Latitude to degrees
   my ($degrees, $minutes, $seconds, $sign) = $self->decimal2dms($GPS->{lat});
   $GPS->{lat} = sprintf('%02d%02d.%02d', $degrees, $minutes, $seconds);
warn "Lat: ".$GPS->{lat};
   # Calculate Longitude to degrees
   ($degrees, $minutes, $seconds, $sign) = $self->decimal2dms($GPS->{lon});
   $GPS->{lon} = sprintf('%03d%02d.%02d', $degrees, $minutes, $seconds);
warn "Lon: ".$GPS->{lon};

   return sprintf('/%sh%s%s/%s%sO%03d/%03d/A=%06d/FSHABIII Balloon',
            $GPS->{'time'},      # 130515 
            $GPS->{lat},         # 4913.19258
            $GPS->{lat_NS},      # N
            $GPS->{lon},         # 00831.27270
            $GPS->{lon_EW},      # E
            $GPS->{ept} || 0,    # 054
            $GPS->{speed} || 0,  # 054
            $GPS->{alt} || 0,    # 054
         );
};

sub aprs_wav {
   my $self    = shift;
   my $aprs    = shift or return;
   
   $self->sys($aprs_bin, "-c $CallSign -o $WavPath \"$aprs\"");

   return $WavPath;
};

sub aprs_send {
   my $self    = shift;
   my $wavefile= shift or return;
   my $nodelete= shift || 0;
   
   warn "Send Audio File ..." if($DEBUG);

   $self->sys($aplay, $wavefile);

   my $waittime = int(rand(15));
   warn "Wait $waittime seconds and send again." if($DEBUG);
   sleep($waittime); # wait and send a second time

   $self->sys($aplay, $wavefile);

   unlink($wavefile) if(not $nodelete);

   warn "Audio File sended." if($DEBUG);

   return 1;
};

# Check if altitude change, if not then the balloon has landed and 
# we try to connect to an Access Point (Laptop, RPI)
# http://unix.stackexchange.com/questions/12005/how-to-use-linux-kernel-driver-bind-unbind-interface-for-usb-hid-devices
# http://raspberrypi.stackexchange.com/questions/6782/commands-to-simulate-removing-and-re-inserting-a-usb-peripheral
# sudo sh -c 'echo 1-1 > /sys/bus/usb/drivers/usb/unbind'
# sudo sh -c 'echo 1-1 > /sys/bus/usb/drivers/usb/bind'
sub checkWlan {
   my $self    = shift;
   my $alt     = shift || return;

   # Init wlanState and old altitude
   $self->{wlan_state} = 0 if(not exists $self->{wlan_state});
   $self->{old_alt} = 0    if(not exists $self->{old_alt});

   # Altitude not changed?
   if($self->{old_alt} == $alt){
      # ping => ok ... return
      if($self->sys($ping, '-c 1 www.google.de')){
         return 1;
      }
      else {
         warn "Switch WLAN ON";
         # Switch USB WLAN ON
         # Try to connect to an Access Point
         # wait a minute 
         # ping
         # fail => wlan off
      }
   }
   else {
      warn "Switch WLAN OFF";
      # Changed Altitude
      # check if USB WLAN off
      # if not switch USB Wlan off
   }

   $self->{old_alt} = $alt;
   return $self->{wlan_state};
};

# Call system command
sub sys {
   my $self    = shift;
   my $command = shift;
   my @params  = @_;
   
   my $systemcmd = sprintf('%s %s %s 2>&1', $nice, $command, join(' ', @params));
   my $output = `$systemcmd`;
   
   if($? == 0){
      return $output;
   }
   warn sprintf('Call return wrong exit status %d: %s for cmd "%s"', $?, $output, $systemcmd);
};

sub decimal2dms {
   my $self    = shift;
   my ($decimal) = @_;
   
   my $sign = $decimal <=> 0;
   my $degrees = int($decimal); # 49.219891333 = 49
   
   # convert decimal part to minutes
   my $dec_min = abs($decimal - $degrees) * 60; # 49.219891333 - 49 * 60 = 
   my $minutes = int($dec_min);
   my $seconds = ($dec_min - $minutes) * 100; # Lat: 38deg and 22.20 min (.20 are NOT seconds, but 1/100th of minutes)
   
   return ($degrees, $minutes, $self->round($seconds), $sign);
}

sub round {
   my ($self, $wert) = @_;
   return int(10 * $wert + 0.5) / 10;
}

1;
