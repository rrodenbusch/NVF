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
use Getopt::Std;

sub usage {
	my $string = 
			" Usage NVF_Integration  gate1 gate2 gate3 ...\n" . 
			"\t\\-H Host IP default 127.0.0.1\n" .
			"\t\\-P Port default 8888\n" .
			"\t\\-d Output directory\n" .
			"\t\\-l Log configuration file\n" .
			"\t\\-w Wait time between counts (sec)\n" .
			"\t\\-h Help\n";
	return($string);
}	# usage

sub setOptions {
	my ($self,$opts) = @_;
	
	$self->{host} = '127.0.0.1';
	$self->{host} = $opts->{H} if (defined($opts->{H}));
	
	$self->{port} = 8888;
	$self->{port} = $opts->{P} if (defined($opts->{P}));
	
	$self->{logconf} = '/home/mThinx/bin/Log4Perl2.conf';
	$self->{logconf} = $opts->{l} if (defined($opts->{l}));
	
	$self->{dirname} = './';
	$self->{dirname} = $opts->{d} if (defined($opts->{d}));	
	
	$self->{pollInterval} = 5;
	$self->{pollInterval} = $opts->{w} if (defined($opts->{w}));
	
	if ($opts->{h}) {
		die usage();
	}
}

sub new {
	my $class = shift;
	my $signals = shift;
	my %opts;

	my $self = {}; 
	bless( $self, $class );    # make $self an object of class $class
	
	getopts('hH:P:l:d:w:', \%opts) or die usage();  # options as above. Values in %opts
	push ( @{$self->{gates}},@ARGV);
	$self->{header} = "Time";
	foreach my $gate (@{$self->{gates}}) {
		$self->{header} .= ",$gate IN,$gate OUT";
	}
	$self->{header} .= "\n";
	die usage() if (defined($opts{h}) || (scalar ($self->{gates}) < 1 ));
	$self->setOptions(\%opts);
	$self->{sigs} = $signals;
	$self->{sigs}->{HUP} = 0;
	$self->{sigs}->{CONT} = 0;
	$self->{sigs}->{USR1} = 0;
	$self->{sigs}->{USR2} = 0;
	$self->{prevPoll} = time();
	 
	Log::Log4perl::init($self->{logconf});
	$self->{logger} = Log::Log4perl->get_logger();
	return $self;
}	# new

sub closeSocket {
	my $self = shift;
	# notify server that request has been sent
	my $socket = $self->{sock};
	
	shutdown($socket,1);
	$socket->close();
	delete $self->{sock};
}	# close

sub openDatafile {
	my $self = shift;
	close( $self->{fh} ) if ( defined( $self->{fh}) );
	 
	my $epoch = time();
	my $fname = $self->{dirname} ."/$epoch.NVFData.csv";
	if (open(my $fh,">$fname") ) {
		# auto-flush on socket
		select((select($fh), $| = 1)[0]);
		$self->{fh} = $fh;
		print $fh $self->{header};
	} else {
		delete $self->{fh};
	}
}

sub outputDataline {
	my ($self,$counts) = @_;
	my $fh = $self->{fh};
	my $line = join(',',@$counts);
	my $epoch=time();
	print $fh "$epoch,$line\n" if (defined($self->{fh}));	
}

sub ConnectNVF {
	my $self = shift;
	$self->close() if (defined($self->{sock}));
		
	my $socket = new IO::Socket::INET ( PeerHost => $self->{host}, 
											PeerPort => $self->{port}, Proto => 'tcp',);
	$self->{sock} = $socket;
	$socket->autoflush();
	# create a connecting socket
	if ( $socket ){
		$self->{logger}->debug("Connected to $self->{host} $self->{port} on socket");
		$self->openDatafile();
		my $ID = $self->GetNVFID();
		my $Path = $self->GetRunPath();
		$self->{logger}->info("Connected to ID: $ID @ $Path");
	} else {
		$self->{logger}->error("Cannot connect to the server $!") unless $self->{sock};
	}
	return $self->{sock};
}	# ConnectNVF

sub handleUSR1 {
	# Restart the logging into a new file
	my $self = shift;
	$self->{logger}->info("Received USR1 signal, starting new data file");
	$self->openDatafile();
	$self->{sigs}->{USR1} = 0;
}

sub handleUSR2 {
	my $self = shift;
	$self->{sigs}->{logger}->info("Received USR1 signal, starting new data file");
	$self->{sigs}->{USR2} = 0;
}

sub handleCONT {
	my $self = shift;
	$self->{sigs}->{HUP} = 0;
	$self->{sigs}->{CONT} = 0;
	$self->{sigs}->{HUP} = 0;
}

sub handleHUP {
	my $self = shift;
	$self->closeSocket();
	$self->{sigs}->{HUP} = 1;
	# Wait for the CONT signal to restart;
}

sub pollWait {
	my ($self) = @_;
	$self->checkSignals();
	my $delta = time() - $self->{prevPoll};
	my $wait = $self->{pollInterval} - $delta;
	sleep ($wait) if ($wait > 0);
	$self->{prevPoll} = time();
}

sub checkSignals {
	my $self = shift;
	$self->handleCONT() if ($self->{sigs}->{CONT} == 1);
	$self->handleHUP()  if ($self->{sigs}->{HUP} == 1);
	$self->handleUSR1() if ($self->{sigs}->{USR1} == 1);
	$self->handleUSR2() if ($self->{sigs}->{USR2} == 1);
}	#checkSignals

sub ParseResponse {
	my $self = shift;
	my ($cnt,$resp) = (1,$self->{response});
	$resp =~ s/\{//g;
	$resp =~ s/\}//g;
	my @fields = split('\|',$resp);
	$self->{fields}->{App} = shift(@fields);
	my $textRSP = pop(@fields);
	$textRSP = substr($textRSP,1) if (substr($textRSP,0,1) eq '=');
	$self->{fields}->{NVFResponse} = $textRSP;
	 # drop the =
	$self->{NVFResponse} = $self->{fields}->{NVFResponse};
	foreach my $cur (@fields) {
		my @subfields = split(':',$cur);
		my $fldname = shift(@subfields);
		my $savename = $fldname;
		$savename = "$fldname".'('.$cnt++.')' while (defined($self->{fields}->{$savename}));
		$self->{fields}->{$savename} = join(':',@subfields);	
	}
	return $self->{NVFResponse};
}	# ParseResponse

sub ExchangeMessage {
	my ($self) = @_;
	my $size = length($self->{request});
	
	if ($self->{sigs}->{HUP}) {  # Waiting for CONT signam
		$self->{fields}->{NVFResponse} = "HUP";
	} else {
		if (!defined($self->{sock}) ) {
			my $curRequest = $self->{request};
			$self->ConnectNVF();
			$self->{request} = $curRequest; 
		}
		if (defined($self->{sock})) {
			my $sentchars = $self->{sock}->send($self->{request});
			if ($sentchars == $size) {
				$self->{logger}->trace("Sent: $self->{request}");
				# receive a response of up to 1024 characters from server
				my $response = "";
				$self->{sock}->recv($response, 1024);
				$self->{response} = $response;
				$self->{logger}->debug("Received: $response");
				$self->ParseResponse();
			} else {
				$self->{fields}->{NVFResponse} = "TX Error";
				$self->{logger}->info("Transmission error, data size mismatch $sentchars vs $size\n");		
			}			
		} else {
			$self->{fields}->{NVFResponse} = "Offline";						
		} 
	}
	return $self->{fields}->{NVFResponse};
}	# ExchangeMessage

sub GetNVFID {
	my $self = shift;
	$self->{request} = 'PRFX_GET_INSTALLATION_ID("HEX");';
	$self->ExchangeMessage();
	$self->{ID} = $self->{fields}->{NVFResponse};
	return $self->{ID}; 
}	# GetNVFID

sub GetRunPath {
	my $self = shift;
	$self->{request} = 'PRFX_GET_DEFAULT_RUN_PATH();';
	$self->ExchangeMessage();
	$self->{path} = $self->{fields}->{NVFResponse};
	return $self->{path};	
}	# GetRunPath

sub GetNVFCount {
	my ($self,$socket,$start,$end) = (shift,shift,shift,shift);
	my $gatelist = join('",',@_);
	my $req = 'PRFX_GET_VL_COUNTERS_BY_NAME(' .
					$gatelist . ',"' . $start . '","' . $end . '");';
	$self->{request} = $req;
	$self->ExchangeMessage();
}	# GetNVFCount

sub Restart {
	my $self = shift;
	$self->{request} = 'PRFX_GET_DEFAULT_RUN_PATH();';
	return $self->ExchangeMessage();
}	# Restart

sub formatRequest {
	my $self = shift;
	my $request =  shift .'(';
	my $param = shift;
	$request .= '"' . $param . '"' if (defined($param));
	foreach $param (@_) {
		$request .= ',"' . $param . '"';
	}
	$request .= ');';
	$self->{request} = $request;
	return $self->{request};
}	# formatRequest

sub getCurrentCounts {
	my $self = shift;
	my @counts = ();
	
	foreach my $gate (@{$self->{gates}}) {
		$self->formatRequest('PRFX_VL_COUNTERS_GET',$gate,"INPUT");
		$self->ExchangeMessage();
		my $resp1 = $self->{NVFResponse};
		$self->formatRequest('PRFX_VL_COUNTERS_GET',$gate,"OUTPUT");
		$self->ExchangeMessage();
		my $resp2 = $self->{NVFResponse};
		my ($in,$out);
		$in = $resp1 if ($resp1 =~ /^-?\d+$/);
		$out = $resp2 if ($resp2 =~ /^-?\d+$/);
		if (!defined($in) ) {
			($in,$out) = ('ERR','ERR');
			($in,$out) = ('DNE','DNE') if ($resp1 =~ /DOES NOT EXIST/);
		}
		push(@counts,$in,$out);
	}
	$self->outputDataline(\@counts);
	return(\@counts);
}	# getCurrentCounts

sub closeConnection {
	my $self = shift;
	$self->closeSocket();
	close $self->{fh};
	$self->{logger}->info("Closing connection to NVF");
}

1;