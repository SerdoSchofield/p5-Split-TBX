#!usr/bin/perl

package Split::TBX;
use strict;
use warnings;
# use feature 'state';
use XML::Twig;
use open ':encoding(utf8)', ':std';

our $VERSION = 0.01;

_run(@ARGV) unless caller();



##globals##
my %subjectFieldList;
my %langList;
my @termList;
my $totalEntries = 0;
my $isGUI = 0;
my $textCtrl;

sub scan
{
	my ($self, $fh, $GUI, $entries) = @_;
	$isGUI = 1;
	$textCtrl = $GUI;
	
	my $fname = $fh;
	$fname =~ s/\.\w+$//i;
	$fh = _handle($fh);

	($fname, $fh, $entries) = _readTBXbinary($fh, $fname, $entries);
	
	my @subjectList = keys(%subjectFieldList);
	("@subjectList" =~ /[a-z]/i) ? (@subjectList = sort @subjectList) : (@subjectList = sort { $a <=> $b }(@subjectList));
	
	my @langList = sort(keys(%langList));
	
	return ($fname, $fh, $entries, \@subjectList, \@langList, \%subjectFieldList, \%langList);
	
	# ($fh, $outType, $outTypes_ref, $fhout, $totalEntries)  arguments that Output takes
}

sub split
{
	my ($self, $fh, $outType, $outTypes_ref, $fhout, $totalEntries, $subjectFieldList_href, $langList_href, $GUI) = @_;
	
	$textCtrl = $GUI;
	%subjectFieldList = %{$subjectFieldList_href};
	%langList = %{$langList_href};
	my %outTypes = %$outTypes_ref;
	
	$textCtrl->{text_ctrl_header}->AppendText("\n");
	$textCtrl->{text_ctrl_header}->AppendText("Searching for termEntries containing language(s): ".join (' ', @{$outTypes{'language'}})." (This may take some time depending on the file size.)\n");
	if (_output($fh, $outType, $outTypes_ref, $fhout, $totalEntries))
	{
		return 1;
	}
}

sub _run
{
	(@_ >= 1) or die "Usage: perl TBX.pm <input TBX file> (optional <linebyline>)";
	my ($fh, $entries) = @_;
	
	my $fname = $fh;
	$fname =~ s/\.\w+$//i;
	$fh = _handle($fh);

	if (_output(_CGUI(_readTBXbinary($fh, $fname, $entries))))
	{
		print "\nPrinted successfully!";
	}
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

sub _readTBXbinary
{
	(!$isGUI) ? print "\nParsing in Binary mode\n" : $textCtrl->{text_ctrl_header}->AppendText("\nParsing in Binary mode\n");
	my ($fh, $originalName, $entries) = @_;
	$entries = 20000 if (!defined $entries || $entries =~ /[a-z]/i);
	binmode($fh);
	
	my $lastPercent = '';
	my $size = -s $fh;
	my $scannedBytes = 0;
	(!$isGUI) ? print "Total Size: $size\n" : $textCtrl->{text_ctrl_header}->AppendText("Total Size: $size\n");
	(!$isGUI) ? print "\nNow scanning file for information (this could take some time depending on file size).\n" : $textCtrl->{text_ctrl_header}->AppendText("\nNow scanning file for information (this could take some time depending on file size).\n");
# 	open OUT, ">", "errorLog.log";
	my $termEntryCount;
	my $tigCount;
	my $cycles;
	my $rc = 1;
	my ($progress, $content) = (0, '');
	while ($rc > 0)
	{
		if ($content !~ m!<termEntry.+?/termEntry>!si)
		{
			$cycles++;
			$rc = read($fh, my $text, 1000);
			$progress += $rc;
			$content .= $text;
		}
		else{
			my $head = $1 if $content =~ m!(.+/termEntry>)!si;
			
			foreach my $termEntry ($head =~ m!(<termEntry.+?/termEntry>)!gsi)
			{
				$termEntryCount++;
				my $calc = ($progress / $size * 100);
				my $percent = sprintf("%.0f", $calc);
				
				##keeps line from scrolling down
				# if ($isGUI && $termEntryCount > 1)
				# {
					# my $charNums = $textCtrl->GetLastPosition;
					# my $lastLine = $textCtrl->GetNumberOfLines + 1;
					# my $lineLength = $textCtrl->GetLineLength($lastLine);
					# my $lineStart = $charNums - $lineLength;
					# $textCtrl->{text_ctrl_OUT}->Clear;
				# }

				if (!$isGUI) {print "\rParsing termEntry $termEntryCount. ($percent%)";}
				else
				{
					if ($lastPercent ne $percent)
					{
						$textCtrl->{text_ctrl_OUT}->AppendText("\nParsing termEntries. ($percent%)");
					}
					$lastPercent = $percent;
				}

				if ($termEntry =~ m!(<descrip\s*type=['\"]subjectField['\"]\s*>.+?</descrip>)!si)
				{
					foreach my $descrip ($termEntry =~ m!(<descrip\s*type=['\"]subjectField['\"]\s*>.+?</descrip>)!gsi)
					{
						my $subjectField = $1 if ($descrip =~ m!<descrip\s*type=['\"]subjectField['\"]\s*>(.+?)</descrip>!si);
						
						###check if data is separated by commas (as in IATE)###
						my @subjectFields = split (/,/, $subjectField);
						
						foreach (@subjectFields)
						{
							chomp;
							s/^\s+|\s+$//g;
							if (!exists $subjectFieldList{lc($_)} && $_ ne '')
							{
								@{$subjectFieldList{lc($_)}} = ();
								push (@{$subjectFieldList{lc($_)}}, $termEntryCount);
							}
							elsif ($_ ne '')
							{
								push (@{$subjectFieldList{lc($_)}}, $termEntryCount);
							}

							
						}
						
					}
				}
				foreach my $langSet ($termEntry =~ m!(<langSet.+?/langSet>)!gsi)
				{
					my $lang = $1 if $langSet =~ /xml:lang=\s*['\"]\s*([a-z-]+)\s*['\"]\s*>/i;
					
					###this is better, but is slower and causes a memory bloat and I don't know why###
# 					my $twig = XML::Twig->new( twig_handlers => { ignore_elts => { tig => 'discard' }, langSet => sub { $lang = $_->{'att'}->{'xml:lang'};} } );
# 					$twig->safe_parse($langSet);
# 					$twig->dispose;
					###check if data is separated by commas (as in IATE)###

					if (!exists $langList{lc($lang)} && $lang ne '')
					{
						$langList{lc($lang)} = $termEntryCount;
					}
					else
					{
						$langList{lc($lang)} .= " $termEntryCount";
					}

					# $langList{lc($lang)} = 1 if (defined $lang && !exists($langList{$lang}));
				}
# 				@langCaptures = ();
			}
# 			@termCaptures = ();
			substr $content, 0, length $head, ''; #empty content until un-parsed point
		}
	}
	
	return ($originalName, $fh, $termEntryCount);
}

sub _CGUI
{
	my ($originalName, $fh, $termEntryCount) = @_;

	print "\nScan complete!\n";
	while (1)
	{
		my %outTypes;
		$outTypes{subjectField} = '';
		@{$outTypes{language}} = ();
		
		print "\nWhat would you like to do?\n".
				"\n1: Split glossary by subject and language(s) (recommended)\n".
				"2: Split glossary by subject\n".
				"3: Split glossary by language(s) (slowest)\n".
				"\n(1,2,3, 'q' to quit):  ";
		my $in = <STDIN>;
		chomp $in;
		exit if ($in eq 'q');
		
		if ($in eq '2')
		{
			print "\n\nPlease choose from one of the subjectFields:\n";
			my $i = 0;
			
			my @list = keys(%subjectFieldList);
			("@list" =~ /[a-z]/i) ? (@list = sort @list) : (@list = sort { $a <=> $b }(@list));
			foreach (@list) { 
				$i++;
				print $_.", "; 
				if ($i == 8)
				{
					$i = 0;
					print "\n";
				}
			}
			while (1)
			{
				print "\nSubject: ";
				$in = <STDIN>;
				chomp $in;
				if ($in eq '-quit') {exit()}
				if ($in eq '-list') { 
					foreach (@list)  { 
						$i++;
						print $_.","; 
						if ($i == 8)
						{
							$i = 0;
							print "\n";
						}
					}
				}
				
				if(exists($subjectFieldList{lc($in)}))
				{
					$outTypes{subjectField} = lc($in);
					last;
				}
				
				print "\nInvalid code. Please only use those provided ('-list' to see list again):  ";
			}
			my $filename = $originalName."_subjectField($in).tbx";
			open my $fhout, ">", $filename;
			
			print "Searching $originalName for Entries containing Subject Field: $in (This may take some time depending on the file size.)\n";
			
			# print @{$subjectFieldList{lc($in)}};
			if (&_output($fh, 'subjectField', \%outTypes, $fhout, $termEntryCount))
			{
				print "\nPrinted successfully!";
			}
			close $fhout;
		}
		elsif ($in eq '3')
		{
			my $amount;
			while(1)
			{
				print "\nHow many languages would you like to split from the glossary? ";
				$amount = <STDIN>;
				chomp $amount;
				if ($amount =~ /[a-z]/i)
				{
					print "\n Only use numeric values (ex: '2').";
					next;
				}
				if ($amount > keys (%langList))
				{
					print "\nCannot split more than what is available!";
					next;
				}
				last;
			}

			print "\n\nPlease choose from the following language codes:\n";
			my $i = 0;
			foreach (sort(keys(%langList))) { 
				$i++;
				print $_."\t"; 
				if ($i == 5)
				{
					$i = 0;
					print "\n";
				}
			}
			my $x = 0;
			my $filename = $originalName."_language(";
			while (1)
			{
				$x++;
				print "\nDesired language $x: ";
				$in = <STDIN>;
				chomp $in;
				if ($in eq '-quit') {exit()}
				if ($in eq '-list') { 
					foreach (sort(keys(%langList)))  { 
						$i++;
						print "$_\t"; 
						if ($i == 5)
						{
							$i = 0;
							print "\n";
						}
					}
				}
				
				if(exists($langList{lc($in)}))
				{
					if ($x == 1) {$filename .= $in}
					else {$filename .= "-$in";}
					push (@{$outTypes{'language'}}, lc($in));
					last if ($x == $amount);
				}
				
				print "\nInvalid code. Please only use those provided ('-list' to see list again):  " if (!exists($langList{lc($in)}));
			}
			$filename .= ").tbx";
			open my $fhout, ">", $filename;
			print "\n";
			print "Searching $originalName for Entries containing language(s): ".join (' ', @{$outTypes{'language'}})." (This may take some time depending on the file size.)\n";
			if (&_output($fh, 'language', \%outTypes, $fhout, $termEntryCount))
			{
				print "\nPrinted successfully!";
			}
			close $fhout;
		}
		elsif ($in eq '1')
		{
			print "\n\nPlease choose from one of the subjectField values:\n";
			my $i = 0;
			my ($amount, $subject, $language);
			
			my @list = keys(%subjectFieldList);
			("@list" =~ /[a-z]/i) ? (@list = sort @list) : (@list = sort { $a <=> $b }(@list));
			foreach (@list) { 
				$i++;
				print $_.", "; 
				if ($i == 8)
				{
					$i = 0;
					print "\n";
				}
			}
			while (1)
			{
				print "\nSubject: ";
				$subject = <STDIN>;
				chomp $subject;
				if ($subject eq '-quit') {exit()}
				if ($subject eq '-list') { 
					foreach (@list)  { 
						$i++;
						print $_.","; 
						if ($i == 8)
						{
							$i = 0;
							print "\n";
						}
					}
				}
				
				if(exists($subjectFieldList{lc($subject)}))
				{
					$outTypes{subjectField} = lc($subject);
					last;
				}
				
				print "\nInvalid code. Please only use those provided ('-list' to see list again):  ";
			}
		
			while(1)
			{
				print "\nHow many languages would you like to split from the glossary? ";
				$amount = <STDIN>;
				chomp $amount;
				if ($amount =~ /[a-z]/i)
				{
					print "\nOnly use numeric values (ex: '2').";
					next;
				}
				if ($amount > keys (%langList))
				{
					print "\nCannot split more than what is available!";
					next;
				}
				last;
			}

			print "\n\nPlease choose from the following language codes:\n";
			$i = 0;
			foreach (sort(keys(%langList))) { 
				$i++;
				print $_."\t"; 
				if ($i == 5)
				{
					$i = 0;
					print "\n";
				}
			}
			my $x = 0;
			my $filename = $originalName."_subject($subject)_language(";
			while (1)
			{
				$x++;
				print "\nDesired language $x: ";
				$language = <STDIN>;
				chomp $language;
				if ($language eq '-quit') {exit()}
				if ($language eq '-list') { 
					foreach (sort(keys(%langList)))  { 
						$i++;
						print "$_\t"; 
						if ($i == 5)
						{
							$i = 0;
							print "\n";
						}
					}
				}
				if(exists($langList{lc($language)}))
				{
					if ($x == 1) {$filename .= $language}
					else {$filename .= "-$language";}
					push (@{$outTypes{'language'}}, lc($language));
					last if ($x == $amount);
				}
				
				print "\nInvalid code. Please only use those provided ('-list' to see list again):  " if (!exists($langList{lc($language)}));
			}
			$filename .= ").tbx";
			open my $fhout, ">", $filename;
			print "\n";
			print "Searching $originalName for Entries containing language(s): ".join (' ', @{$outTypes{'language'}})." (This may take some time depending on the file size.)\n";
			return ($fh, 'both', \%outTypes, $fhout, $termEntryCount);
		}
	}
}

sub _output 
{
	my ($fh, $outType, $outTypes_ref, $fhout, $totalEntries) = @_;
	my %outTypes = %$outTypes_ref;
	my $progress;
	my $termEntryCount = 0;
	my $content = '';
	my $printedHeader = 0;
	my $lastPercent = '';
	seek $fh, 0, 0;

	$textCtrl->{text_ctrl_OUT}->Remove(0, -1) if ($isGUI);
# 	my $size = -s $fh;
# 	my $rc = 1;
# 	while ($rc > 0)
# 	{
# 		if ($content !~ m!<termEntry.+?/termEntry>!si)
# 		{
# 			$rc = read($fh, my $text, 1000);
# 			$progress += $rc;
# 			$content .= $text;
# 		}
# 		else{
# 			if ($printedHeader == 0)
# 			{
				###print header###
# 				my $header = $1 if $content =~ m!(.+?)<termEntry!si;
# 				substr $content, 0, length $header, ''; #empty content until un-parsed point
# 				$header =~ s/(?<=>)\s+(?=<)|(?<=>)\s+$/\n/g;  ##clear formatting
# 				print $fhout $header;
# 				$printedHeader = 1;
# 			}
# 			
# 			my $head = $1 if $content =~ m!(.+/termEntry>)!si;
# 			my @termCaptures = ($head =~ m!(<termEntry.+?/termEntry>)!gsi);
# 			print "\n".(@termCaptures + 0)."\n";
# 			foreach my $termEntry ($head =~ m!(<termEntry.+?/termEntry>)!gsi)
# 			{	
# 				$termEntry =~ s/(\&#.+)/\$1/gs;
# 				$termEntryCount++;
# 				my $calc = ($progress / $size * 100);
# 				my $percent = sprintf("%.1f", $calc);
# 				print "\rPrinting termEntry $termEntryCount. ($percent%) $progress $size $calc";
# 				
# 				my $string;
# 				my ($lead, $langCycle);
# 				foreach my $langSet ($termEntry =~ m!(<langSet.+?/langSet>)!gsi)
# 				{	
# 					$langCycle++;
# 					
# 					if ($content =~ m!(.+?)\Q$langSet!si && $langCycle == 1)
# 					{
# 						$lead = $1;
# 						substr $termEntry, 0, length $lead, '';
# 						$string .= $lead;
# 					}
# 					
# 					my $lang = $1 if $langSet =~ /xml:lang=\s*['\"]\s*([a-z-]+)\s*['\"]\s*>/i;
# 					
# 					substr $termEntry, 0, length $langSet, ''; #empty content until un-parsed point
# 					$string .= $langSet if (lc($lang) eq lc($code));
# 				
# 				}
# 				$string .= $termEntry;  #print remaining termEntry tags to string
				
				###the Twig Way is too memory hungry###
				my $termEntryTwig = XML::Twig->new (
					output_encoding => 'utf8',
					pretty_print => 'indented',
# 					twig_print_outside_roots => $fhout,
# 					
					# twig_roots => { martif => 1, },
					
					start_tag_handlers => {
						# body => sub {$_->flush($fhout)},
						termEntry => sub { #skip all entries that did not have the desired subjectField (to save time)
										$termEntryCount++;
										
										my $containsLang = 0;
										my $calc = ($termEntryCount / $totalEntries * 100);
										my $percent = sprintf("%.1f", $calc);
										if (!$isGUI) { print "\rScanning termEntry $termEntryCount.  ($percent%)"; }
										else
										{
											my $percent = sprintf("%.0f", $calc);
											if ($lastPercent ne $percent)
											{
												$textCtrl->{text_ctrl_OUT}->AppendText("\nScanning termEntry $termEntryCount. $percent%");
											}
											$lastPercent = $percent;
										
										}#$textCtrl->{text_ctrl_OUT}->AppendText("\rScanning termEntry $termEntryCount.  ($percent%)");
										# print "\n @{$subjectFieldList{lc($code)}} \n";
										if($outType eq 'subjectField')
										{
											if (join ( ' ', @{$subjectFieldList{$outTypes{subjectField}}}) !~ /\b$termEntryCount\b/)
											{
												if (!$isGUI) {print "\rIgnoring termEntry $termEntryCount.";}#$textCtrl->{text_ctrl_OUT}->AppendText("\rIgnoring termEntry $termEntryCount.");
												$_->ignore; 
											}
										}
										elsif($outType eq 'language')
										{
											foreach my $lang (@{$outTypes{language}})
											{
												if ($langList{$lang} =~ /\b$termEntryCount\b/) {$containsLang = 1};
											}
											
											if ($containsLang == 0)
											{
												if (!$isGUI) {print "\rIgnoring termEntry $termEntryCount.";}#$textCtrl->{text_ctrl_OUT}->AppendText("\rIgnoring termEntry $termEntryCount.");
												$_->ignore;
											}
										}
										elsif($outType eq 'both')
										{
											if(join ( ' ', @{$subjectFieldList{$outTypes{subjectField}}}) !~ /\b$termEntryCount\b/)
											{
												if (!$isGUI) {print "\rIgnoring termEntry $termEntryCount.";}#$textCtrl->{text_ctrl_OUT}->AppendText("\rIgnoring termEntry $termEntryCount.");
												$_->ignore;
												return;
											}
										
											foreach my $lang (@{$outTypes{language}})
											{
												if ($langList{$lang} =~ /\b$termEntryCount\b/) {$containsLang = 1};
											}
											
											if ($containsLang == 0)
											{
												if (!$isGUI) {print "\rIgnoring termEntry $termEntryCount.";}#$textCtrl->{text_ctrl_OUT}->AppendText("\rIgnoring termEntry $termEntryCount.");
												$_->ignore;
												return;
											}
										
										}
									},
						langSet => sub {
										if ($outType ne 'subjectField')
										{
											my $lang = lc($_->{'att'}->{'xml:lang'});
											if (join (' ', @{$outTypes{language}}) =~ /\b$lang\b/) 
											{
												return;
											}
											else { $_->ignore }
										}
									},
					},
					
					twig_handlers => {
						text => sub {$_->flush($fhout)},
						body => sub {$_->flush($fhout)},
						# 'termEntry//descrip[@type="subjectField"]' => sub {
										# my $subj = $outTypes{subject};
										# $_->purge if (lc($_->text) !~ /\b$subj\b/) 
									# },
						termEntry => sub { 
							my $calc = ($termEntryCount / $totalEntries * 100);
							my $percent = sprintf("%.1f", $calc);
							
							if($outType eq 'language')
							{
								(!$isGUI) ? print "\r                                          Printing termEntry $termEntryCount." :
											$textCtrl->{text_ctrl_OUT}->AppendText("\r----------------------------------------->Printing termEntry $termEntryCount.");
# 								$_->purge;
								$_->flush($fhout);
							}
							
							elsif ($outType eq 'subjectField')
							{
								# if ($_->first_descendant('descrip[@type="subjectField"]')){
									(!$isGUI) ? print "\r                                          Printing termEntry $termEntryCount." :
											$textCtrl->{text_ctrl_OUT}->AppendText("\r----------------------------------------->Printing termEntry $termEntryCount.");
	# 								$_->purge;
									$_->flush($fhout);
								# } else {
									# print "\rSkipping termEntry $termEntryCount. ($percent%)";
									# $_->purge; 
								# }
							}
							elsif ($outType eq "both")
							{
								# if ($_->has_child('langSet') && $_->first_descendant('descrip[@type="subjectField"]')){
									(!$isGUI) ? print "\r                                          Printing termEntry $termEntryCount." :
											$textCtrl->{text_ctrl_OUT}->AppendText("\r----------------------------------------->Printing termEntry $termEntryCount.");
	# 								$_->purge;
									$_->flush($fhout);
								# } else {
									# print "\rSkipping termEntry $termEntryCount. ($percent%)";
									# $_->purge; 
								# }
							}
						},
					},
				);
				$termEntryTwig->safe_parse($fh) or die $@;
# 				$string = $termEntryTwig->sprint;
# 				$termEntryTwig->flush(\*$fhout);
# 				$string =~ s/(?<=>)\n$//g; #get rid of last newline
# 				print $fhout $string;
# 			}
# 			substr $content, 0, length $head, ''; #empty content until un-parsed point
# 		}
# 	}
# 	$content =~ s/(?<=>)\s+(?=<)|\s+(?=<)/\n/g;
# 	print $fhout $content;
	close $fhout;
	return 1;
}
return 1;