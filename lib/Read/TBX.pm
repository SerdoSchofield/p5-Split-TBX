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
	my ($fh, $entries) = @_;
	_testXML($fh, $entries);
}

sub _run
{
	(@_ >= 1) or die "Usage: perl TBX.pm <input TBX file> at lib/Read/TBX.pm line 19.";
	my ($fh, $entries) = @_;
	_testXML($fh, $entries);
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
	my ($fh , $entries) = @_; 
	my $originalName = $fh;
	$originalName = "Report\\".$1 if $originalName =~ m/(.*(?=\.tbx\w*))/;
	$fh = _handle($fh); #convert $fh into filehandle if it isn't already

	_readTBXBinary($fh, $originalName, $entries);
}

sub _readTBXBinary
{
	my ($fh, $originalName, $entries) = @_;
	$entries = 20000 if !defined $entries;
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
	
	my $totalCount = 0;
	my $rc = 1;
	while ($rc > 0)
	{
		my ($cycles, $head) = 0;
		my $termEntryCapture = '';

		my $entryCount = 0;
		$none = 0;
		do{	
			$cycles++;
			$offset = 0;
			$head = 0;
			$rc = read($fh, my $byteCount, 1000, $offset);
			$capture .= $byteCount;
			$offset = $cycles*1000 + $head;
			if ($capture =~ m!(.+?/termEntry>)!s)
			{
				$head = length $capture;
				my $tmpCapt = $1;
				$termEntryCapture .= $1 if ($tmpCapt =~ m!(<termEntry.+?/termEntry>)!s);
				
				$capture =~ s/\Q$tmpCapt//;
				$entryCount++;
				$totalCount++;
				
				print "\r Found termEntry on cycle $cycles!";
				$extracted = 1 if $entryCount == $entries;
			}
			if ($capture =~ m!/text>!s) { $none = 1 }
			
		} until ($extracted || $none);
		if (!$extracted) { last; }
		$extracted = 0;
		if(printTemp($originalName, "termEntries", $termEntryCapture, $totalCount, $entries))
		{
			print "\nPrinted a termEntryCollection\n";
		}
	}
}

sub printTemp
{
	my ($originalName, $tmpName, $tmpContent, $number, $entries) = @_;
	my $fhtmp;

	if ($number)
	{
		$number = ($number)."-".($entries + $number - 1);
	}
	
	if ($number)
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