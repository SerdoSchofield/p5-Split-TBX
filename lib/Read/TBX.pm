#!usr/bin/perl

package Read::TBX;
use strict;
use warnings;
use feature 'state';
use XML::Twig;
use open ':encoding(utf8)', ':std';

our $VERSION = 0.01;

_run(@ARGV) unless caller();

sub readTBX
{
	my $fh = shift;
	_testXML($fh);
}

sub _run
{
	(@_ >= 1) or die "Usage: perl TBX.pm <input TBX file> at lib/Read/TBX.pm line 19.";
	my $fh = shift;
	_testXML($fh);
}

sub _handle
{
	## no critic (RequireBriefOpen)
    my $fh = shift;
    my $handle;
    if ($fh) {
        if ( ref($fh) eq 'GLOB' ) {
            $handle = $fh;
        }
		#emulate diamond operator
		elsif ($fh eq q{-}){
			$handle = \*STDIN;
		}
        else {
            open $handle, '<', $fh or die "Couldn't open $fh";
        }
    }
    return $handle;
}


sub _testXML
{
	my $fh = shift; 
	my $originalName = $fh;
	$originalName = "Report\\".$1 if $originalName =~ m/(.*(?=\.tbx\w*))/;
	$fh = _handle($fh); #convert $fh into filehandle if it isn't already

	_readTBXBinary($fh, $originalName)
}

sub _readTBXBinary
{
	my ($fh, $originalName) = @_;
	binmode($fh);
	my ($capture, $martifHeaderCapture);
	my ($extracted, $none, $offset) = 0;
	
	do{
		my $rc = read($fh, my $byteCount, 1);
		$capture .= $byteCount;
		if ($capture =~ m!(<martifHeader.+?/martifHeader>)!s)
		{
			$martifHeaderCapture = $1;
			$extracted = 1;
		}
		if ($capture =~ m!<body!)
		{
			$none = 1;
		}
	} until ($extracted) or ($none);
	
	if ($extracted)
	{
		if(printTemp($originalName, "headerinfo", $martifHeaderCapture))
		{
			print "\n Printed Header Information\n";
		}
		$capture = '';
	}
	
	my $count = 0;
	my $rc = 1;
	while ($rc > 0)
	{
		my ($cycles, $head) = 0;
		my $termEntryCapture = '';
		while( $count < 5000)
		{
			my $entryCount = 0;
			$none = 0;
			do{	
				$cycles++;
				$offset = 0;
				$head = 0;
				$rc = read($fh, my $byteCount, 1000, $offset);
				$capture .= $byteCount;
				$offset = $cycles*1000 + $head;
				if ($capture =~ m!(.+?/termEntry>)!gs)
				{
					$entryCount++;
					$head = length $capture;
					my $tmpCapt = $1;
					$termEntryCapture .= $1 if ($tmpCapt =~ m!(<termEntry.+?/termEntry>)!s);
					
					$capture =~ s/\Q$tmpCapt//;
					
					print "\r Found termEntry on cycle $cycles!";
				}
				if ($capture =~ m!/text>!s) { $none = 1 }
				
			} until ($entryCount == 5000 || $none);
			if (!$extracted) { last; }
			$capture = '';
			$extracted = 0;
		}
		$count++;
		if(printTemp($originalName, "termEntries", $termEntryCapture, $count))
		{
			print "\nPrinted a termEntryCollection\n";
		}
	}
}

sub printTemp
{
	my ($originalName, $tmpName, $tmpContent, $number) = @_;
	my $fhtmp;
	state $previous = 0;
	$previous = 500*($number - 1) if defined $number;
	
	if (defined $previous && defined $number)
	{
		$number = ($previous+1)."-".(500*$number);
	}
	
	if (defined $number)
	{
		open $fhtmp, '>', $originalName.$tmpName."_".$number.".xml";
		print $fhtmp $tmpContent;
		close $fhtmp;
		return 1;
	}
	else
	{
		open $fhtmp, '>', $originalName.$tmpName.".xml";
		print $fhtmp $tmpContent;
		close $fhtmp;
		return 1;
	}
}

sub _readTBXSimple
{

}