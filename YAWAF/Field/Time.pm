#-------------------------------------------------------------------------------
# Field::Time.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package Field::Time;

use strict;

use base 'Field';


$Field::ValidationData{'validtime'} =
	sub {
			my $self = shift;
			my $value = shift;
				
			$value =~ /([0-9]+):([0-9]+):00/;
			
			my ($h,$m) = ($1,$2);

			return (($h+$m > 0) && ($h < 0 || $m < 0 ||  $h > 23 || $m > 59 ))?'validtime_err':'';
		};
$Field::ValidationData{'validtime_err'} = '<FONT class="errortext">Bad time</font> ';

#		elsif ($v eq 'pasttime') {
#		}
#		elsif ($v eq 'futuretime') {

sub buildHTML
{
	my $self = shift;
	my $f = shift;
	my $q = shift;

	return $q->textfield(-name => "th_$f",-size=>2,-maxlength=>2) . ':'.
		   $q->textfield(-name => "tm_$f",-size=>2,-maxlength=>2) . ' '.
		   $q->popup_menu(-name => "tap_$f",-values=>['AM','PM']);
}

sub buildHTMLnoEdit
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	my $page = shift;

	return $q->param("th_$f").':'.$q->param("tm_$f").' '.	$q->param("tap_$f");
}

sub getFieldValueFromQuery
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	
	my $hours = $q->param('th_'.$f);
	my $minutes = $q->param('tm_'.$f);
	my $ap = $q->param('tap_'.$f);

	$hours = '' if $hours !~ /[0-9]/;
	$minutes = '' if $minutes !~ /[0-9]/;

	return '00:00:00' if ($hours eq '' && $minutes eq '');
#die "'$hours - $minutes'";

	if ($ap eq 'AM') {
		$hours = 0 if $hours eq '12';
	}
	else {
		$hours += 12 if $hours ne '12';
	}

	return sprintf("%02d:%02d:00",$hours,$minutes);
}

sub setQueryFromFieldValue
{
	my $self = shift;
	my $field = shift;
	my $q = shift;
	my $recordP = shift;
	
	$recordP->{$field} =~ /^([0-9]+):([0-9]+)/;
	my ($h,$m) = ($1,$2);

	my $ap;
	if ($h >= 12) {
		$h -= 12 if $h > 12;
		$ap = "PM";
	}
	else {
		$h = '12' if $h eq '00';
		$ap = "AM";
	}
	$q->param("th_$field" => $h);
	$q->param("tm_$field" => $m);
	$q->param("tap_$field" => $ap);
}

1;