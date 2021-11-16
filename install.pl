#!/usr/bin/perl

use strict;
use warnings;
use JSON;
use Cwd;

BEGIN {push @INC, getcwd()."/src";}
use options;

<<<<<<< HEAD
# globals
=======
my ($USER) = `who | awk '{print \$1}'` =~ /^(\w+)/gm;
chomp($USER);

my %options = Options::parseCommandLine(@ARGV);

if (exists $options{'--help'} || exists $options{'-h'}) {
  print '
  SYSJACK installation script
  Usage:
  ./configure.pl [config=configfile] [key=jsonkey] [--help|-h] [user=username] [-y] [-s] [unit]
  
  config  *filename*  output config on custom path
  key     *keyname*   output config as a property instead of plain object
  user    *username*  force username
  -y      update/install systemd without asking
  -s      print command line string without asking
  unit    unit name inside config file (mandatory)
  
  if config is not specified, config.json on current directory is assumed.
  ';
  exit 0;
}


die "Missing unit name!" if !exists $options{'verb'};

$USER = $options{'user'} if (exists $options{'user'});

if (!exists $options{'user'}) {
  print "User is assumed to be '$USER'. press (enter) to confirm or enter new user name:";
  $answer = <STDIN>;
  chomp ($answer);

  if ($answer ne "") {
    $USER = $answer;
    $HOME = "/home/$USER";
  }
}

my $CONFIG_FILE = (exists $options{'config'}) ? $options{'config'} : "config.json";
my $key = (exists $options{'key'}) ? $options{'key'} : undef;

die "Missing $CONFIG_FILE" if ! -e $CONFIG_FILE;

my %JSON = Options::loadConfigFile($CONFIG_FILE, $key);
die "Cannot translate JSON: $!\n" if keys %JSON == 0;
>>>>>>> 2db602be93d8c3889bf16c90f5c0529f87c70f3a

my %JSON; ## global json object
my $answer; ## default answer scalar
my $USER; ## username
my %options; ## option json

sub replaceAll {
  my ($property, $string) = @_;

  my %data = %{$JSON{$property}};
  
  my $regex = "";
  my $replace = "";
  
  foreach my $k (keys %data) {
    $regex = "{$property/$k}";
    $replace = $data{$k};  
    $string =~ s/$regex/$replace/g;
  }
  
  return $string;
}

%options = Options::parseCommandLine(@ARGV);


if (exists $options{'--help'} || exists $options{'-h'}) {
  print '
  SYSJACK installation script
  Usage:
  ./configure.pl [config=configfile] [key=jsonkey] [--help|-h] [user=username] [-y] [-s] [unit]
  
  config  *filename*  output config on custom path
  key     *keyname*   read config json as a property instead of root json object
  user    *username*  force username
  -y      update/install systemd without asking
  -s      print command line string only (useful for cat)
  unit    unit name inside config file (mandatory)
  
  if config is not specified, config.json on current directory is assumed.
  ';
  exit 0;
}


die "Missing unit name!\n" if !exists $options{'verb'};

my $CONFIG_FILE = (exists $options{'config'}) ? $options{'config'} : "config.json";
my $key = (exists $options{'key'}) ? $options{'key'} : undef;
die "Missing $CONFIG_FILE" if ! -e $CONFIG_FILE;

%JSON = Options::loadConfigFile($CONFIG_FILE, $key);
die "Cannot translate JSON: $!\n" if keys %JSON == 0;

if (exists $options{'user'}) {
  $USER = $options{'user'};
} else {
  $USER = `who | awk '{print \$1}'`;
  chomp($USER);
  if (!exists $options{'-s'}) {
    print "System user is '$USER'.\n Press ENTER to confirm or input new user:";
    $answer = <STDIN>;
    chomp($answer);
    $USER = $answer if ($answer ne "");
  }
}

die "Invalid JSON data $CONFIG_FILE.\n" if (!exists $JSON{'units'} || !exists $JSON{'card'} || !exists $JSON{'jack'});
my %UNITS = %{$JSON{'units'}};
my $unit = lc $options{'verb'};

die "Module $unit is unknown" if (!exists ($UNITS{$unit}));
print "Found module $unit\n" if (!exists $options{'-s'});
my $commandLine = $UNITS{$unit};

$commandLine = replaceAll('card', $commandLine);
$commandLine = replaceAll('jack', $commandLine);
$commandLine = replaceAll('user', $commandLine);

print "Unit $unit has command Line: $commandLine\n" if (!exists $options{'-s'});

my $source = "";

if (-e "./src/$unit.service.in") {
  print "Found custom service source.\n" if (!exists $options{'-s'});
  $source = Options::readFile("./src/$unit.service.in");
} else {
  $source = Options::readFile("./src/default.service.in");
}

$source =~ s/USERNAME/$USER/g;
$source =~ s/COMMAND_LINE/$commandLine/g;

my $desc = (exists $options{'description'}) 
              ? $options{'description'}
              : "$unit process daemon";
        
$source =~ s/_DESCRIPTION/$desc/g;
$source = replaceAll('card', $source);
$source = replaceAll('jack', $source);
$source = replaceAll('user', $source);

$answer = (exists $options{'-y'}) ? "i" : "";
$answer  = (exists $options{'-s'}) ? "s" : $answer;

<<<<<<< HEAD
while ($answer eq "" || !($answer =~ /[IiLlSs]/)) {
=======
$answer = "s" if exists $options{'-s'};

while ($answer eq "" || !($answer =~ /[IiLl]/)) {
>>>>>>> 2db602be93d8c3889bf16c90f5c0529f87c70f3a
  print "\nService ready. (i)nstall, (l)ocal or (s)tring?";
  $answer = lc <STDIN>;
  chomp($answer);
}

<<<<<<< HEAD
if ($answer =~ /[il]/i ) {
  open (FH, '>', "$unit.service") or die $!;
  print FH $source;
  close (FH);


  if (lc($answer) eq "i") {
=======
if ( lc($answer) =~ /[il]/) {
  open (FH, '>', "$unit.service") or die $!;
  print FH $source;
  close (FH);
  if ($answer eq "i") {
>>>>>>> 2db602be93d8c3889bf16c90f5c0529f87c70f3a
    if (-e "/etc/systemd/system/$unit.service") {
      system "sudo systemctl stop /etc/systemd/system/$unit.service";
      system "sudo systemctl disable /etc/systemd/system/$unit.service";
    }
<<<<<<< HEAD
      system "sudo cp $unit.service /etc/systemd/system";
      system "sudo systemctl enable $unit";
      system "rm $unit.service";
      
      print "Type sudo systemctl start $unit to start service.\n";
  } else {
    print "created file $unit.service.\n" if !exists $options{'-s'};
  }
} else {
  print $source;
=======
    system "sudo cp $unit.service /etc/systemd/system";
    system "sudo systemctl enable $unit";
    system "rm $unit.service";
      
    print "Type sudo systemctl start $unit to start service.\n";
  } else {
    print "created file $unit.service.\n";
  }
} else {
  print $commandLine . "\n";
>>>>>>> 2db602be93d8c3889bf16c90f5c0529f87c70f3a
}

