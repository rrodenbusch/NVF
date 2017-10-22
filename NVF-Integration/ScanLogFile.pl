use strict;
use warnings;
use Getopt::Std;
use Log::Log4perl qw(:easy);

# Setup Signals
my %sig = ( HUP => 0, ABRT => 0, USR1 => 0, USR2 => 0, CONT => 0 );
$SIG{HUP}  = sub {$sig{HUP} = 1};
$SIG{ABRT} = sub {$sig{ABRT} = 1};
$SIG{USR1} = sub {$sig{USR1} = 1};
$SIG{USR2} = sub {$sig{USR2} = 1};
$SIG{CONT} = sub {$sig{CONT} = 1};
my $self;

sub usage {
	my $string = 
			" Usage ScanLogFile -d [IN|OUT|BOTH] -g gate1,gate2,gate3 -w delay(sec)  fname\n" . 
			"\t\\-g CSV list of gates to scan, default (all)\n".
			"\t\\-d Direction IN, OUT, BOTH. Default BOTH\n" .
			"\t\\-w Wait time repeats. Reset counter if no update (sec)\n" .
			"\t\\-h Help\n";
	return($string);
}	# usage

sub setOptions {
	my %opt;
	my $opts = \%opt;
	
	getopts('hg:d:w:', $opts) or die usage();  # options as above. Values in %opts
	$self->{mingap} = 9999999;
	$self->{mingap} = $opts->{w} if (defined($opts->{w}));
	
	$self->{gates} = '';
	$self->{gates} = $opts->{g} if (defined($opts->{g}));
	
	$self->{direction} = 'BOTH';
	$self->{direction} = $opts->{d} if (defined($opts->{d}));
	
	$self->{dirname} = './';
	$self->{dirname} = $opts->{d} if (defined($opts->{d}));	
	
	if ($opts->{h}) {
		die usage();
	}
	$self->{fname} = $ARGV[0];
}


setOptions();
open(my $fh, $self->{fname}) or die "Unable to open $self->{fname}\n\t$!";
my $line = <$fh>;
$line =~ s/\R//g;
my @header = split(',',$line);
my ($lastTime,$curTime,$lastCnt,$curCnt) = (time(), time(),'','');
my (@diffs,@oldCnts,@newCnts,@fields);
while ($sig{ABRT} == 0) {
    while (my $line = <$fh>) {
    	$line =~ s/\R//g;
    	@fields= split(',',$line);
    	$curTime = shift(@fields);
    	$curCnt = join(',',$line);
    	@diffs = ();
    	if ($curCnt ne $lastCnt) {  # New data point
    		my $gap = $curTime - $lastTime;
    		if ($gap > $self->{delay}) { # New data after long gap
				@oldCnts = split(',',$lastCnt);
				@newCnts = split(',',$curCnt);
				while (my $cnt1 = shift(@oldCnts)) {
					my $cnt2 = shift(@newCnts);
					my $delta = $cnt2 - $cnt1;
					push(@diffs, $delta); 
				}
				print "$curTime,$gap," . join(',',@diffs) . "\n";
    		}
    		$lastCnt = $curCnt;
    	}
    }
    # eof reached on FH, but wait a second and maybe there will be more output
    sleep 5;
    seek $fh, 0, 1;      # this clears the eof flag on FH
}
1;