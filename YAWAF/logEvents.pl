#-------------------------------------------------------------------------------
# logEvents.pl
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package main;

sub logEvents
{
	my $sql = shift;
	my $table = shift;
	
	my $pairsP;
	
	if (ref($_[0]) eq 'HASH') {
		$pairsP = shift;
	}
	else {
		my $type = shift;
		my $subType = shift;
		my $account_id = shift;
		my $related_id = shift;
		my $content = shift;
	
		my %pairs;
		$pairs{'type'} = $sql->Quote($type) if defined $type;
		$pairs{'subType'} = $sql->Quote($subType) if defined $subType;
		$pairs{'account_id'} = $account_id if defined $account_id;
		$pairs{'related_id'} = $related_id if defined $related_id;
		$pairs{'content'} = $sql->Quote($content) if defined $content;
		
		$pairsP = \%pairs;
	}

	$pairsP->{'date'} = 'NOW()';
	
	$sql->InsertRecord($table,$pairsP,1);  #dontquote=1 because we just did it!

}
1;