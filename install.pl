#!/usr/bin/perl

use strict;
use warnings;
use JSON;
use Cwd;

BEGIN {push @INC, getcwd()."/src";}
use options;

my ($USER) = `who | awk '{print \$1}'` =~ /^(\w+)/gm;
chomp($USER);

my %options = Options::parseCommandLine(@ARGV);
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

die "Invalid JSON data $CONFIG_FILE.\n" if (!exists $JSON{'units'} || !exists $JSON{'card'} || !exists $JSON{'jack'});
my %UNITS = %{$JSON{'units'}};
my $unit = lc $options{'verb'};

die "Module $unit is unknown" if (!exists ($UNITS{$unit}));
print "Found module $unit\n";
my $commandLine = $UNITS{$unit};

$commandLine = replaceAll('card', $commandLine);
$commandLine = replaceAll('jack', $commandLine);
$commandLine = replaceAll('user', $commandLine);

print "Unit $unit has command Line: $commandLine\n";

my $source = "";

if (-e "./src/$unit.service.in") {
  print "Found custom service source.\n";
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

my $answer = (exists $options{'-y'}) ? "i" : "";

$answer = "s" if exists $options{'-s'};

while ($answer eq "" || !($answer =~ /[IiLl]/)) {
  print "\nService ready. (i)nstall, (l)ocal or (s)tring?";
  $answer = lc <STDIN>;
  chomp($answer);
}

if ( lc($answer) =~ /[il]/) {
  open (FH, '>', "$unit.service") or die $!;
  print FH $source;
  close (FH);
  if ($answer eq "i") {
    if (-e "/etc/systemd/system/$unit.service") {
      system "sudo systemctl stop /etc/systemd/system/$unit.service";
      system "sudo systemctl disable /etc/systemd/system/$unit.service";
    }
    system "sudo cp $unit.service /etc/systemd/system";
    system "sudo systemctl enable $unit";
    system "rm $unit.service";
      
    print "Type sudo systemctl start $unit to start service.\n";
  } else {
    print "created file $unit.service.\n";
  }
} else {
  print $commandLine . "\n";
}

