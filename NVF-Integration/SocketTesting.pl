use lib "$ENV{HOME}/bin";
use strict;
use warnings;
use NVF_Socket;
use Log::Log4perl qw(:easy);

my @Gates = ('RIGHT','Left','Top');
my ($start,$end) = ('2017-07-25 00:00:00','2017-07-25 23:59:59');

my $curNVF = NVF_Socket->new('/home/mThinx/bin/Log4Perl.conf');


$curNVF->ConnectNVF('127.0.0.1','8888') or die "cannot connect to the server $!\n";
print "Connected to Server\n";
my $NVFresp = $curNVF->GetNVFID();
$curNVF->{logger}->info("Connected\n");
$NVFresp = $curNVF->GetRunPath();

my ($i,$abort) = (0,0);
$SIG{HUP} = sub { print "$i\n"};
$SIG{ABRT} = sub { $abort = 1};

my ($epoch,$in,$out);
do {
	($in,$out) = $curNVF->getCurrentCount('GATE_MAIN');
	$epoch = time();
	if ($i % 12 == 0) {
		$curNVF->{logger}->info("Completed loop number $i");
		print "Completed $i\t $NVFresp->{RequestDate}\n";
	}
	$i++;
	sleep 5;
} while ((!$abort) && $NVFresp);

if ($abort) {
	$curNVF->{logger}->info("Aborting at count $i!");
	print "Aborting at count $i\n" if ($abort);
} else {
	$curNVF->{logger}->warn("Exiting at count $i!");
	print "Exiting at $i\n" if (!$abort);
}

$curNVF->close();

1;