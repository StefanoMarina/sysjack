#!/usr/bin/perl

##  This program is free software: you can redistribute it and/or modify
##  it under the terms of the GNU General Public License as published by
##  the Free Software Foundation, either version 3 of the License, or
##  (at your option) any later version.
##
##  This program is distributed in the hope that it will be useful,
##  but WITHOUT ANY WARRANTY; without even the implied warranty of
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##  GNU General Public License for more details.
##
##  You should have received a copy of the GNU General Public License
##  along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use JSON;
use Cwd;

BEGIN {push @INC, getcwd() ."/src";}
use options;

my %options = Options::parseCommandLine(@ARGV);
my $CONFIG_FILE = (exists $options{'config'}) ? $options{'config'} : "config.json";

my $isJackPresent = `which jackd`;
my $isAlsaPresent = `which aplay`;
my $isAlsaCapPresent = (-e "./src/alsacap/alsacap");
my $answer = "";

my ($USER) = `who | awk '{print \$1}'` =~ /^(\w+)/gm;
chomp ($USER);

my $HOME = "/home/$USER";
my $TARGET_DIR = "/opt/sysjack";

my $BACKUP_FOLDER = $HOME."/.sysjack";

sub requestInput {
  my ($text, $regex, $defaultAnswer) = @_;
  my $answer = undef;
  
  while (!defined $answer || ($answer eq "\n" && !defined $defaultAnswer) 
    || ($answer ne "\n" && !($answer =~ /$regex/))) {
      print "\n$text:";
      $answer = <STDIN>; 
      chomp($answer) if ($answer ne "\n");
  }
  
  if (defined $defaultAnswer && $answer eq "\n") {
    $answer = $defaultAnswer;
  }
  
  print "\n";
  return $answer;
}

sub doBackup {
   
  system "mkdir -p $BACKUP_FOLDER; chown $USER $BACKUP_FOLDER" 
    if (! (-d $BACKUP_FOLDER) );
  
  my ($origFile, $destFile) = @_;
  my $date = `date +%s`;
  chomp($date);
  $destFile = "$BACKUP_FOLDER/$destFile.$date.backup";
  system "cp $origFile $destFile";
  print "Made backup copy of $origFile in $BACKUP_FOLDER\n.";
  return $destFile;
}

print '
  # SYSJACK v. 1.0
  systemd jackd service
  
  2021 Stefano Marina.
  This script will install SysJack, a systemd service for jack daemon,
  useful if you want to auto-launch jack (i.e. headless pi box.).
  This script will touch some important configuration files of your
  system, see README.md.
  
  # AGREEMENT
  This script is under GPL3.
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  Press (a)gree if you agree to continue at your own risk, any other key to exit:';

$answer = <STDIN>;
exit 0 if (! ($answer =~ /[Aa]/) );

if ($isAlsaPresent eq "") {
  print "Error: ALSA utils not present!\n";
  print "Do you want me to install alsa-utils? (y)es, (enter) to skip: ";
  
  $answer = <STDIN>;
  if ($answer =~ /[yY][\n\r]*/) {
    system ("sudo apt-get install alsa-utils");
    print ("Restart install.pl");
    exit 0;
  }
  exit 1;
}

if ($isJackPresent eq "") {
  print "Error: jack is not present!\n";
  $answer = requestInput("Do you want me to install jackd2? (y)es or (enter) to skip", "[yY]", "skip");
    
  if ($answer =~ /[Yy]/) {
    system ("sudo apt-get install --no-recommends jackd2 a2jmidid aj-snapshot");
    print ("Restart install.pl");
    exit 0;
  }
  
  exit 2;
}

if (!$isAlsaCapPresent) {
  print "ALSA Capabilities (c) 2007 Volker Schatz\n";
  print "alsacap is not present. This will not enable us to see the sound card capabilities.\n";

  $answer = requestInput ("Make alsacap? (y)es or (enter) to skip:", "[Yy]", "skip");
  
  if ($answer =~ /[Yy]/) {
    my $result = `cd src/alsacap; make; cd ../..`;
    print "check out if installation was correct...";
    if (-e "src/alsacap/alsacap") {
      print "OK.\n Restart program.\n";
    } else {
      print "FAILED.\n Please try to build manually at src/alsacap.\n";
      exit 1;
    }
    exit 0;
  }
}

my @output = `aplay -l | grep \"\\[\"`;
my @cards;

foreach (@output) {
  my %card;
  if ($_ =~ /^\w+ (\d+): (\w+) \[([^\]]+)\], \w+ (\d+): ([^\[]+).*/) {
    $card{'card_id'} = $1;
    $card{'card_shortname'} = $2;
    $card{'card_longname'} = $3;
    $card{'device_id'} = $4;
    $card{'device_name'} = $5;
    $card{'alsa_id'} = "hw:$1,$4";
    push @cards, \%card;
  } else {
    print "no match.\n";
  }
}

print "\n\n# CONFIG\nUser: $USER\nHome: $HOME\nConfiguration file: $CONFIG_FILE\nBackup folder: $BACKUP_FOLDER\n";

print "User is assumed to be '$USER'. press (enter) to confirm or enter new user name:";
$answer = <STDIN>;
chomp ($answer);

if ($answer ne "") {
  $USER = $answer;
  $HOME = "/home/$USER";
}

print "\nHome dir is $HOME. Press (enter) to confirm or input new path:";
$answer = <STDIN>;
chomp ($answer);
$HOME = $answer if ($answer ne "");

my $index = 0;
print "# AUDIO CARD\n";
print "Audio cards found:\n";

foreach (@cards) {
  $index += 1;
  print "\t $index: $_->{'card_id'},$_->{'device_id'}: $_->{'card_longname'} / $_->{'device_name'}\n";
}


$answer = requestInput("Select audio card (1-$index)", "\\d+", "");
  
exit 0 if (scalar($answer) > $index);
my $selected_card = $cards[$answer-1];

print "Selected $selected_card->{'device_name'}\n";

if ($isAlsaCapPresent) {
 my $alsacoutput = `./src/alsacap/alsacap -C $selected_card->{'card_id'} -D $selected_card->{'device_id'}`;
 print $alsacoutput . "\n"; 
 if ($alsacoutput =~ /sampling rate (\d+)\.\.(\d+)/) {
   $selected_card->{'samplerate'} =  requestInput(
    "Sampling rate - card range is $1 to $2. Input number or skip for $2",
    "\\d+", $2);
 } else {
    print "Unable to determine sample rate. Using default 48000.\n"; 
    $selected_card->{'samplerate'} = "48000";
  }
} else  {
  print "Unable to determine sample rate. Using default 48000.\n";
  $selected_card->{'samplerate'} = "48000";
}

my %jack;
print "# JACK params\n";

$jack{'buffersize'} = requestInput(
  "Input buffer size (lower= less latency, more cpu needed - must be power of 2) or (enter) for default (512)",
  "\\d+", 512);
$jack{'ports'} = requestInput ("Input max number of jack ports (2 - 256, at least 2 for each client) or (enter) for default (16)", "\\d+", 16);
$jack{'priority'} = requestInput ("JACK process priority (1 - 95, the higher the better) or (enter) for  default (80)", "\\d+", "80");
$jack{'alsa_mode'} = uc (requestInput ("Device mode: (c)apture only, (p)layback only, (d)uplex (default: p)", "[cCpPdD]", "P"));
$jack{'alsa_periods'} = requestInput ("Playback latency periods (default 2, usb should be 3, higher  may prevent xruns) or (enter) for default (2)", "\\d+", "2");
$jack{'timeout'} = requestInput ("client timeout in ms - 500 min, or (enter) for default (2000)", "\\d+", "2000");

if (-e "/etc/security/limits.d/audio.conf.disabled" || ! -e "/etc/security/limits.d/audio.conf") {
  print "Warning! 'audio' group realtime privileges were not set. JACKD will not be able to obtain realtime privileges.\n";
  print "\n\nrun sudo dpkg-reconfigure -p high jackd2\n\n";
}

$answer = requestInput("Enable JACK MIDI? may be unnecessary if you have alsa (default none): (s)eq (r)aw or (enter) for none:" , "[sSrR]", "none");
$jack{'midi'} = "-X raw" if ($answer =~ /[Ss]/);
$jack{'midi'} = "-X seq" if ($answer =~ /[rR]/);
$jack{'midi'} = "" if ($answer eq "none");

$answer = requestInput(
  "Do you want to set $selected_card->{'longname'} as the default alsa card? Requires configure to be launched as sudo. (y)es or (enter) to skip",
  "[yY]", "skip");
  
if ($answer =~ /[Yy]/) {
  print "Updating ALSA default device (/etc/asound.conf)...\n";  
  my $alsaFile = "
    pcm.SYSJACK {
      type hw
      card $selected_card->{'card_id'}
      device $selected_card->{'device_id'}
    }
    pcm.!default {
      type hw
      card $selected_card->{'card_id'}
      device $selected_card->{'device_id'}
    }
    ctl.!default {
      type hw
      card $selected_card->{'card_id'}
      device $selected_card->{'device_id'}
    }
  ";

  doBackup("/etc/asound.conf", "asound.conf") if (-e "/etc/asound.conf");
  open (FH, '>', "/etc/asound.conf") or die "$! ! Are you sure you are sudo?\n";
  print FH $alsaFile;
  close(FH);
  
  print "Forcing alsa reload. This may take a while...\n";
  if ( `which alsa` eq "") {
   system "sudo alsactl kill rescan";
  } else {
    system "alsa force-reload";
  }
}

  doBackup($CONFIG_FILE, "config.json") if (-e "$CONFIG_FILE");
  
# SYSJACK CONFIG.JSON

my %jdata;
my $key = (exists $options{'key'}) ? $options{'key'} : undef;

if (-e $CONFIG_FILE) {
  %jdata = Options::loadConfigFile($CONFIG_FILE, $key);
  $jdata{'card'} = $selected_card;
  $jdata{'jack'} = \%jack;
  ${$jdata{'user'}}{'sub_priority'} = '80' if (exists $jdata{'user'});
  
  my %units = (exists $jdata{'units'}) ? %{$jdata{'units'}} : ();
  $units{'jackd'} = '/usr/bin/jackd -R -p{jack/ports} -t{jack/timeout} -d alsa -d{card/alsa_id} -{jack/alsa_mode} -p {jack/buffersize} -n {jack/alsa_periods} -r {card/samplerate} -s {jack/midi}';
  $jdata{'units'} = \%units;
  
} else {
  %jdata = (
    'card' => $selected_card,
    'jack' => \%jack,
    'user' => { 'sub_priority' => '80'},
    'units' => {'jackd' => '/usr/bin/jackd -R -p{jack/ports} -t{jack/timeout} -d alsa -d{card/alsa_id} -{jack/alsa_mode} -p {jack/buffersize} -n {jack/alsa_periods} -r {card/samplerate} -s'}
  );
}

# SYSJACK installation
Options::saveConfigFile($CONFIG_FILE, \%jdata, $key);

print "$CONFIG_FILE created.\n";
print "do sudo ./install.pl jackd to install JACKD service.\n";
