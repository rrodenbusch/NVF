use lib "$ENV{HOME}/bin";
use strict;
use warnings;
use NVF_Socket;
use Getopt::Std;
use Log::Log4perl qw(:easy);

# Setup Signals
my %sig = ( HUP => 0, ABRT => 0, USR1 => 0, USR2 => 0, CONT => 0 );
$SIG{HUP}  = sub {$sig{HUP} = 1};
$SIG{ABRT} = sub {$sig{ABRT} = 1};
$SIG{USR1} = sub {$sig{USR1} = 1};
$SIG{USR2} = sub {$sig{USR2} = 1};
$SIG{CONT} = sub {$sig{CONT} = 1};


# Setup command line options
my $curNVF = NVF_Socket->new(\%sig);
my ($epoch,$in,$out,$i);
do {
	($in,$out) = $curNVF->getCurrentCounts();
	$curNVF->pollWait();
} while ((!$sig{ABRT}));

$curNVF->{logger}->info("Exiting based on signal\n") if ($sig{ABRT});
$curNVF->closeConnection();

1;