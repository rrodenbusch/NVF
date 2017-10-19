use lib "$ENV{HOME}/bin";
use strict;
use warnings;
use NVF_Socket;
use Log::Log4perl qw(:easy);


my @Gates = ('Gate_Bottom','GATE_RIGHT','GATE_LEFT','GateTop');

Log::Log4perl::init('/home/mThinx/bin/Log4Perl.conf');
my $logger = Log::Log4perl->get_logger();
$logger->info("Startup");
my $intf = NVF_Socket->new($logger);
 
# create a connecting socket
my ($host,$port) = ('127.0.0.1','8888');
my $socket = $intf->ConnectNVF($host,$port);
die "cannot connect to the server $!\n" unless $socket;
$logger->info("Connected to the server");
my $NVFresp = $intf->GetNVFID();

my ($start,$end) = ('2017-07-25 00:00:00','2017-07-25 23:59:59');
my $i = 0;
my $abort = 0;
$SIG{HUP} = sub { print "$i\n"};
$SIG{ABRT} = sub { $abort = 1};

do {
	#$NVFresp = NVF_Socket::GetNVFCounters($socket, $start,$end, @Gates);
	#sleep 5;
	$NVFresp = $intf->GetRunPath();
	if ($i % 12 == 0) {
		$logger->info("Completed loop number $i");
		print "Completed $i\t $NVFresp->{RequestDate}\n";
	}
	$i++;
	sleep 5;
} while ((!$abort) && $NVFresp);

if ($abort) {
	$logger->info("Aborting at count $i!");
	print "Aborting at count $i\n" if ($abort);
} else {
	$logger->warn("Exiting at count $i!");
	print "Exiting at $i\n" if (!$abort);
}

$intf->close();

1;