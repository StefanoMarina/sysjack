package Options;

use strict;
use warnings;
use JSON;

sub parseCommandLine {
  my %commandLine = ();
  
  foreach (@_) {
    my $string = $_;
    if ($_ =~ /(\w+)=(.*)/ ) {
      $commandLine{lc $1} = $2;
    }elsif ($_ =~ /^-.*/) {
      $commandLine{$_} = 1;
    } else {
      die "Verb already defined.\n" if (exists $commandLine{'verb'});
      $commandLine{'verb'} = $string;
    }
  }
  
  return %commandLine;
}

sub loadConfigFile {
  my ($configFile, $key) = @_;
  my $rawData = readFile($configFile);
  if (!defined $key) {
    return %{from_json($rawData)};
  } else {
    my %js = %{from_json($rawData)};
    die "Configuration file $configFile has no key $key" if ! exists $js{$key};
    return %{$js{$key}};
  }
}

# data is hash ref
sub saveConfigFile {
  my ($configFile, $data, $key) = @_;
  if (defined $key && "" ne $key) {
    my %js = loadConfigFile($configFile);
    $js{$key} = $data;
    $data = \%js;
  }
  open (FH, '>', "$configFile") or die $!;
  print FH JSON->new->ascii->pretty->encode($data);
  close(FH);
}

sub readFile {
  my ($filename) = @_;
  my $rawData=  "";
  open (FH, '<', $filename) or die $!;
  $rawData .= $_ while <FH>;
  close (FH);
  return $rawData;
}
1;
