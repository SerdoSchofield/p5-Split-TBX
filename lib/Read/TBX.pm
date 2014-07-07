#!usr/bin/perl

package Read::TBX;
use strict;
use warnings;
use XML::Simple;
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
	my $fh = $_[0];
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
	$fh = _handle($fh); #convert $fh into filehandle if it isn't already

	_readTBXBinary($fh)
}

sub _readTBXBinary
{
	my $fh = shift;
	binmode($fh);
	my $capture;
	my $termEntryCapture;
	
	while(read($fh, my $byteCount, 1000))
	{	

		
	}
}

sub _readTBXSimple
{
	my $fh = shift;
}