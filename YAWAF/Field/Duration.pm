#-------------------------------------------------------------------------------
# Field::Duration.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package Field::Duration;

use strict;

use base 'Field';


sub buildHTML
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	
	my $fv;
	my $use_table = !$self->{'notable'};
	my $usedays = ! exists $self->{'nodays'};

	my $dv;
	$dv = $q->textfield(-name => "dd_$f",-size=>2,-maxlength=>2).'Days' if $usedays;
	my $hv = $q->textfield(-name => "dh_$f",-size=>3,-maxlength=>3).'Hours';
	my $mv = $q->textfield(-name => "dm_$f",-size=>3,-maxlength=>3).'Minutes';
	if ($use_table) {
		$fv = qq*<table border="0" cellpadding="3" cellspacing="3"><tr><td width=70>$dv</td><td>$hv</td><td>$mv</td></tr></table>*
	}
	else {
		$fv = "$dv $hv $mv";
	}

	return $fv;
}

sub buildHTMLnoEdit
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	my $page = shift;
	my $fv;
	
	my $dv = $q->param("dd_$f");
	my $hv = $q->param("dh_$f");
	my $mv = $q->param("dm_$f");
	return if ($dv eq '' && $hv eq '' && $mv eq '');
	$fv .= $dv.' Days ' if ! exists $self->{'nodays'};
	$fv .= $hv.' Hours ';
	$fv .= $mv.' Minutes ';
	return $fv;
}

sub getFieldValueFromQuery
{
	my $self = shift;
	my $f = shift;
	my $q = shift;

	my $v;
	my $hours = $q->param('dh_'.$f);
	my $minutes = $q->param('dm_'.$f);
	my $days = $q->param('dd_'.$f);
	
	$hours = '' if $hours !~ /[0-9]/;
	$minutes = '' if $minutes !~ /[0-9]/;
	
	if ($hours eq '' && $minutes eq '') {
		if (exists $self->{'nodays'}) {
			return '';
		}
		elsif ($days !~ /[0-9]/) {
			return '';
		}
	}
	
	$v = $minutes+$hours*60;
	if (not exists $self->{'nodays'}) {
		$v += $days*60*24;
	}
	return $v;
}

sub setQueryFromFieldValue
{
	my $self = shift;
	my $field = shift;
	my $q = shift;
	my $recordP = shift;
	my $usedays = not exists $self->{'nodays'};
	
	my ($d,$h,$m);
	my $v = $recordP->{$field};

	if ($v ne '') {
		if ($usedays) {
			$d = int($v/(60*24));
			$v -= $d*60*24;
		}
		$h = int($v/60);
		$m = $v - $h*60;
	}
	else {
		$q->delete("dh_$field");
		$q->delete("dm_$field");
		$q->delete("dd_$field") if $usedays;
	}
	$q->param("dh_$field" => $h);
	$q->param("dm_$field" => $m);
	$q->param("dd_$field" => $d) if $usedays;

#die "$field= $h-$m|".$q->param("dh_$field").','.$q->param("dm_$field") if $field eq 'Hosproc_EpiTimeBir';
}
1;