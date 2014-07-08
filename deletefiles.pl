#!usr/bin/perl

use strict;
use warnings;

my $directory = '.';

opendir (DIR, $directory) or die $!;

while (my $file = readdir(DIR))
{
	if ($file =~ /\.xml/)
	{
		unlink($file);
		print "\rDeleted $file";
	}
}