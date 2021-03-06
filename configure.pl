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
use Cwd qw( abs_path );
use File::Basename qw (dirname);
use lib dirname(abs_path(__FILE__));
use options;

my %options = Options::parseCommandLine(@ARGV);

if (exists $options{'--help'} || exists $options{'-h'}) {
  print '
  SYSJACK configuration script
  Usage:
  ./sysjack.pl [--help|-h] [config=configuration_file] [key=json_key] [user=username]
  --help : display this help screen
  config  *filename*  select a specific file path (otherwise config.json is generated)
  key     *string* if a .json file exists, specify a property. Root object is create if missing.
  user    *username* force username
';
exit 0;
}

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
  print "Do you want me to install alsa-utils? (y = yes, any other key: cancel): ";
  
  $answer = <STDIN>;
  if ($answer =~ /[yY][\n\r]*/) {
    $answer = system ("sudo apt-get install alsa-utils");
    exit ($answer >> 8)  if ($answer != 0);
  } else {
    exit 1;
  }
}

if ($isJackPresent eq "") {
  print "Error: jack is not present!\n";
  print "Do you want me to install jackd? (y)es, any other key abort:";
  $answer = <STDIN>;
  
  if ($answer =~ /[yY]/) {
    $answer = system ("sudo apt-get install jackd2");
    exit ($answer >> 8) if ($answer != 0);
  } else {
    exit 2;
  }
}

if (!$isAlsaCapPresent) {
  print "ALSA Capabilities (c) 2007 Volker Schatz\n";
  print "alsacap is not present. This will not enable us to see the sound card capabilities.\n";
  print "make alsacap? this requires autotoools. (y)es, any other key skip:";
  $answer = <STDIN>;
  if ($answer =~ /[Yy]/) {
    $answer = system ("cd src/alsacap; make; cd ../..");
    die "ALSACAP failed. please check what went wrong!" unless -e "src/alsacap/alsacap" and ($answer == 0);
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

print "User is assumed to be '$USER'. enter user name or null to confirm:";
$answer = <STDIN>;
chomp ($answer);

if ($answer ne "") {
  $USER = $answer;
  $HOME = "/home/$USER";
}

print "\nHome dir is $HOME. Press enter to confirm or input new path:";
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


$answer = requestInput("Select audio card (1-$index, CTRL+C to quit)", "\\d+");
  
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
  "Input buffer size (default 512, lower= less latency, more cpu needed - must be power of 2)",
  "\\d+", 512);
$jack{'ports'} = requestInput ("Input max number of jack ports (2 - 256, at least 2 for each client, default 16)", "\\d+", 16);
$jack{'priority'} = requestInput ("JACK process priority (1 - 95, the higher the better, default 80)", "\\d+", "80");
$jack{'alsa_mode'} = uc (requestInput ("Device mode: (c)apture only, (p)layback only, (d)uplex (default: p)", "[cCpPdD]", "P"));
$jack{'alsa_periods'} = requestInput ("Playback latency periods (default 2, may prevent xruns)", "\\d+", "2");
$jack{'timeout'} = requestInput ("client timeout in ms - 500 min, 2000 reccomended (default)", "\\d+", "2000");

if (-e "/etc/security/limits.d/audio.conf.disabled" || ! -e "/etc/security/limits.d/audio.conf") {
  print "Warning! 'audio' group realtime privileges were not set. JACKD will not be able to obtain realtime privileges.\n";
  print "\n\nrun sudo dpkg-reconfigure -p high jackd2\n\n";
}

$answer = requestInput(
  "Do you want to set $selected_card->{'card_longname'} as the default alsa card? Requires configure to be launched as sudo. (y)es or any other key to skip",
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

  if (-e "/etc/asound.conf") {
    system "cp /etc/asound.conf /home/$USER/.sysjack/asound.conf.backup";
    open (FH, '>', "/home/$USER/.sysjack/asound.conf");
    print FH $alsaFile;
    close(FH);
    $answer = system "sudo cp /home/$USER/.sysjack/asound.conf /etc/";
    die "Installation of asound.conf failed." if ($answer != 0);
  }

  doBackup("/etc/asound.conf", "asound.conf") if (-e "/etc/asound.conf");

  
  print "Forcing alsa reload. This may take a while...\n";
  if ( `which alsa` eq "") {
   system "sudo alsactl kill rescan";
  } else {
    system "sudo alsa force-reload";
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
  $units{'jackd'} = '/usr/bin/jackd -R -p{jack/ports} -t{jack/timeout} -d alsa -d{card/alsa_id} -{jack/alsa_mode} -p {jack/buffersize} -n {jack/alsa_periods} -r {card/samplerate} -s';
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
