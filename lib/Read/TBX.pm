#!usr/bin/perl

package Read::TBX;
use strict;
use warnings;
use XML::Simple;
use Test::XML;
use open ':encoding(utf8)', ':std';

our $VERSION = 0.01;

sub readTBX
{
	$fh = shift;
	testXML($fh);
}

sub _run
{
	@ARGV >= 1 or die "Usage: perl TBX.pm <input TBX file>";
	testXML($ARGV[0]);
}

sub _handle
{
	## no critic (RequireBriefOpen)
    my ( $fh ) = @_;
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
            open my $fh2, '<', $fh or die "Couldn't open $fh";
            $handle = $fh2;
        }
    }
    return $handle;
}


sub _testXML;
{
	my $fh = shift;  
	$fh = _handle($fh); #convert $fh into filehandle if it isn't already
	
	if (!is_good_xml($fh))
	{
		_readTBXBinary($fh);
	}
}

sub _readTBXBinary
{
	$fh = shift;
	$fh = binmode($fh);
	my $byteCount = undef;
	
	while(read($fh, $byteCount, 0))
	{
		$byteCount++;
		print "\n".$byteCount;
	}
}

sub _readTBXSimple
{
	$fh = shift;
}

_run() unless caller();