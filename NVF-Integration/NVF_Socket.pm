package NVF_Socket;
##########################################
#
#  Basic Socket configuration for NVF
#
##########################################
use strict;
use warnings;
use IO::Socket::INET;
use Log::Log4perl qw(:easy);

 
sub ConnectNVF {
	my $logger = Log::Log4perl->get_logger();
	my ($host,$port) = @_;
	
	# auto-flush on socket
	$| = 1;
	 
	# create a connecting socket
	my $socket = new IO::Socket::INET (
	    PeerHost => $host,
	    PeerPort => $port,
	    Proto => 'tcp',
	);
	$logger->error("Cannot connect to the server $!") unless $socket;
	$logger->debug("Connected to $host $port on socket") if $socket;
	return $socket;

}

sub ParseResponse {
	my ($resp,$req) = @_;
	$resp =~ s/\{//g;
	$resp =~ s/\}//g;
	my @fields = split('\|',$resp);
	my $parsed;
	my $cur = shift(@fields);
	$parsed->{"App"} = $cur;
	$cur = pop(@fields);
	$parsed->{$req} = $cur;
	foreach $cur (@fields) {
		my @subfields = split(':',$cur);
		$parsed->{$subfields[0]} = $subfields[1];	
	}
	return $parsed;
}
sub GetNVFID {
	my $logger = Log::Log4perl->get_logger();
	my $socket = shift;
	my $req = 'PRFX_GET_INSTALLATION_ID("HEX");';
	# data to send to a server
	my $size = $socket->send($req);
	$logger->trace("Sent ID request data of length $size");

	# receive a response of up to 1024 characters from server
	my $response = "";
	$socket->recv($response, 1024);
	$logger->debug("Received ID response: $response");
	my $fields = ParseResponse($response,'NVFID');
	return $fields;
}

sub GetNVFCounters {
	my $socket = shift;
	my $start = shift;
	my $end = shift;
	my @cntrs = @_;
	
	my $logger = Log::Log4perl->get_logger();
	my $req = 'PRFX_GET_VL_COUNTERS_BY_NAME(';
	my $gatelist = join('",',@cntrs) . ',';
	$req .= $gatelist . ',"' . $start . '","' . $end . '");';
	
	# data to send to a server
	my $size = $socket->send($req);
	$logger->trace("Sent counter request, data of length $size");

	# receive a response of up to 1024 characters from server
	my $response = "";
	$socket->recv($response, 1024);
	$logger->debug("Received counter response: $response");
	my $fields = ParseResponse($response,'NVFCounters');
	return $fields;
}

sub GetRunPath {
	my $logger = Log::Log4perl->get_logger();
	my $socket = shift;
	my $req = 'PRFX_GET_DEFAULT_RUN_PATH();';
	# data to send to a server
	my $size = $socket->send($req);
	$logger->trace("Sent Path request data of length $size");

	# receive a response of up to 1024 characters from server
	my $response = "";
	$socket->recv($response, 1024);
	$logger->debug("Received Path response: $response");
	my $fields = ParseResponse($response,'RunPath');
	return $fields;
}



1;