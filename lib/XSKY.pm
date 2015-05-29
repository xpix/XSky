package XSKY;
# ------------- XSKY Module -------------------

use strict;
use warnings;

# ------------- MODULES  ----------------
use JSON::XS qw(decode_json);

# ------------- GLOBAL VARS ----------------
my $aprs_bin = '/usr/local/bin/aprs';
my $aplay    = '~/XSky/bin/send_aprs';
my $ping     = '/bin/ping';
my $nice     = '/usr/bin/nice';
my $gpscmd   = '/usr/bin/gpspipe -w -n 10 | grep --color=never TPV | head -1';
my $ds18b20  = '~/XSky/bin/ds18b20.sh';
my $wi_off   = '/usr/sbin/rfkill block wifi';
my $wi_on    = 'sudo ~/XSky/bin/reconnect.sh';
my $wifils   = 'sudo iwlist wlan0 scan | grep -i ESSID';
my $search_ip= 'ifconfig -a wlan0 | grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}"';


my $GPS      = {};
my $DEBUG    = 0;

sub new {
   my $class = shift;
   my $self = {};
   bless $self, $class;

   $self->{cfg} = $self->getconfig(shift);

   $DEBUG = shift || $self->cfg('DEBUG') || 0;
   
   return $self;
}

sub cfg {  
   my $self = shift; 
   my $name = shift or return $self->{cfg};
   return $self->{cfg}->{$name} 
      or die "Unable to find config entry: $name"; 
}

sub data { 
   my $self = shift; 
   return { 
      gps => $self->getGPS(),
   };
}
  
sub interval {
   my $self = shift;
   my $good = 0;

   $GPS = $self->getGPS();

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

   # Get Temperatures and other Data
   my $sensors = $self->getSensorData();
   
   # Build ARPS String
   my $aprs = $self->aprs_build($sensors);
   warn "Build Aprs: '$aprs'\n" if $DEBUG;

   my $WavPath = $self->cfg('WavPath');
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
sub getGPS {
   my $self    = shift;
   my $cache   = shift;
   my $GPS;

   # Get GPS Position from running gpsd
   my $i = 0;
   while($i++ < 5){
      $GPS = eval{ decode_json( $self->sys($gpscmd)) };
      warn $@ && last if($@);
   
      $GPS->{alt}    //=   0;
      $GPS->{lat_NS} //= 'N';
      $GPS->{lon_EW} //= 'E';
                  
      warn scalar localtime.sprintf(" GPS: %s, %s, %s, %s, %s\n",
         $GPS->{lat_NS}, $GPS->{lat}, $GPS->{lon_EW}, $GPS->{lon}, $GPS->{alt} )
            if $DEBUG;

      last if($GPS->{lat} and $GPS->{alt});
   }

   return $GPS;
}


sub getSensorData {
   my $self    = shift;

   # DS18B20 Outside Temp sensors
   my $out_tmp = $self->sys($ds18b20);

   return { 
      temp_out => $out_tmp, 
   };
};

sub aprs_build {
   my $self    = shift;

   # '2015-05-24T17:41:48.000Z' => 174148
   ($GPS->{'time'}) = $GPS->{'time'} =~ /T(.+?)\./si; # 
   $GPS->{'time'} =~ s/\://sig;

   if($GPS->{alt}){
      $self->{GSP_ALT} = $GPS->{alt};
   }
   else {
      # Remember to old altitude unable to get actual altitude
      $GPS->{alt} = $self->{GSP_ALT};
   }

   # Calculate Latitude to degrees
   my ($degrees, $minutes, $seconds, $sign) = $self->decimal2dms($GPS->{lat});
   $GPS->{lat} = sprintf('%02d%02d.%02d', $degrees, $minutes, $seconds);

   # Calculate Longitude to degrees
   ($degrees, $minutes, $seconds, $sign) = $self->decimal2dms($GPS->{lon});
   $GPS->{lon} = sprintf('%03d%02d.%02d', $degrees, $minutes, $seconds);

   # Get additional Informations
   my $SEN = $self->getSensorData();

   # Build APRS String
   return sprintf('/%sh%s%s/%s%sO%03d/%03d/A=%06d/FSHABIII;OT:%02.2f',
            $GPS->{'time'},      # 130515 
            $GPS->{lat},         # 4913.19258
            $GPS->{lat_NS},      # N
            $GPS->{lon},         # 00831.27270
            $GPS->{lon_EW},      # E
            $GPS->{ept} || 0,    # 054
            $GPS->{speed} || 0,  # 054
            $GPS->{alt} * 3.2808 || 0,    # Alt in ft
            $SEN->{temp_out},
         );
};

sub aprs_wav {
   my $self    = shift;
   my $aprs    = shift or return;

   my $CallSign= $self->cfg('CallSign'); 
   my $WavPath = $self->cfg('WavPath');

   $self->sys($aprs_bin, "-c $CallSign -o $WavPath \"$aprs\"");

   return $WavPath;
};

sub aprs_send {
   my $self    = shift;
   my $wavefile= shift or return;
   my $nodelete= shift || 0;
   
   warn "Send Audio File ..." if($DEBUG);
   
   my $i = 0;
   while($i++ < $self->cfg('SendRepeats')){
      $self->sys($aplay, $wavefile);

      my $waittime = int(rand(15));
      warn "Wait $waittime seconds and send again." if($DEBUG);
      sleep($waittime); # wait and send a second time
   }

   unlink($wavefile) if(not $nodelete);

   warn "Audio File sended." if($DEBUG);

   return 1;
};

# Check if altitude change, if not then the balloon has landed and 
# we try to connect to an Access Point (Laptop, RPI)
# http://unix.stackexchange.com/questions/12005/how-to-use-linux-kernel-driver-bind-unbind-interface-for-usb-hid-devices
# http://raspberrypi.stackexchange.com/questions/6782/commands-to-simulate-removing-and-re-inserting-a-usb-peripheral
sub checkWlan {
   my $self    = shift;
   my $alt     = shift || return;
   
   my $landed = $self->landed($alt);
   return if($landed < 0); # unknown state do nothing

   if($self->landed($alt)){
      $self->wlan_on;
   } else {
      $self->wlan_off;
   }

};

sub landed {
   my $self = shift;
   my $alt  = shift || return;

   my $treshold = $self->cfg->{AltThreshold};
   my $landed = -1; # unknown
   
   if($alt and $self->{alt_old}){

      my $differ = 0;
      if($alt < $self->{alt_old}){
         $differ = $self->{alt_old} - $alt;
      }
      else{
         $differ = $alt - $self->{alt_old};
      }

      if($differ <= $treshold){
         $landed = 1; # landed 
      } else {
         $landed = 0; # flying
      }
   }

   $self->{alt_old} = $alt;

   return $landed;
}

sub wlan_on {
   my $self    = shift;

   # Check if connected ...
   if(not $self->sys($search_ip)){
      # not connected ...
      warn "Switch WLAN ON";
      $self->sys($wi_on);
   }
   
   return 1;   
}

sub wlan_off {
   my $self    = shift;

   warn "Switch WLAN OFF";
   $self->sys($wi_off);
}

# Call system command
sub sys {
   my $self    = shift;
   my $command = shift;
   my @params  = @_;
   
   my $systemcmd = sprintf('%s %s %s 2>&1', $nice, $command, join(' ', @params));
   my $output = `$systemcmd`;
   chomp $output;
   
   if($? == 0){
      return $output;
   }
   warn sprintf('Call return wrong exit status %d: %s for cmd "%s"', $?, $output, $systemcmd)
      if($DEBUG);
   return 0;
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

sub getconfig {
   my ($self, $file) = @_;
   die "No file in getConfig" unless $file;
   my $return = {};

   my $text = $self->sys("cat $file")
      or die "Unable to find $file";
   $text =~ s/\r//sig;

   foreach my $line (split(/\n/, $text)){
      chomp $line;
      next if($line =~ /^\#/);
      next if(not $line);
      my ($key, $val) = $line =~ /^(.+?)\s*\:\s*(.+?)$/si;
      $return->{$key} = $val;
   }
   
   return $return;
}

1;
