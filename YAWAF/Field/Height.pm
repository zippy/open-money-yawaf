#-------------------------------------------------------------------------------
# Field::Height.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package Field::Height;

use strict;

use base 'Field';


sub buildHTML
{
	my $self = shift;
	my $f = shift;
	my $q = shift;

	return $q->textfield(-name => "hf_$f",-size=>3,-maxlength=>3,-onchange=>qq*javascript:fiTocm(document.birthForm.hf_$f,document.birthForm.hi_$f,document.birthForm.$f)*).'ft '.
		  $q->textfield(-name => "hi_$f",-size=>3,-maxlength=>3,-onchange=>qq*javascript:fiTocm(document.birthForm.hf_$f,document.birthForm.hi_$f,document.birthForm.$f)*).'in &nbsp;or&nbsp; '.
		  $q->textfield(-name => "$f",-size=>5,-maxlength=>5,-onchange=>qq*javascript:cmTofi(document.birthForm.$f,document.birthForm.hf_$f,document.birthForm.hi_$f)*).'cm';
}

sub setQueryFromFieldValue
{
	my $self = shift;
	my $field = shift;
	my $q = shift;
	my $recordP = shift;
	
	my $v = $recordP->{$field};
	my $f;
	my $i;
	
	if ($v ne '') {
		$f = int($v*.03280);
		$i = ($v-$f/.03280)*.39370;
		$i =  sprintf("%2.0f",$i);
		if ($i == 12) {
			$i = 0;
			$f++;
		}
	}
	
	$q->param("hf_$field" => $f); 
	$q->param("hi_$field" => $i);
	$q->param($field => $v);
}


1;