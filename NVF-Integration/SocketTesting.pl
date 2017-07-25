use lib "$ENV{HOME}/bin";
use strict;
use warnings;
use NVF_Socket;
use Log::Log4perl qw(:easy);

my @Gates = ('Gate_Bottom','GATE_RIGHT','GATE_LEFT','GateTop');
Log::Log4perl::init('/home/mThinx/bin/Log4Perl.conf');
my $logger = Log::Log4perl->get_logger();
$logger->info("Startup");   
 
# create a connecting socket
my ($host,$port) = ('127.0.0.1','8888');
my $socket = NVF_Socket::ConnectNVF($host,$port);
die "cannot connect to the server $!\n" unless $socket;
$logger->info("Connected to the server");
my $NVFresp;

my ($start,$end) = ('2017-07-25 00:00:00','2017-07-25 23:59:59');
my $i = 0;

do {
	$i++;
	$NVFresp = NVF_Socket::GetNVFCounters($socket, $start,$end, @Gates);
	sleep 5;
	$NVFresp = NVF_Socket::GetRunPath($socket);
	sleep 5;
	$logger->info("Completed loop number $i");
} while ($i < 1000);

# notify server that request has been sent
shutdown($socket, 1);
$socket->close();

1;