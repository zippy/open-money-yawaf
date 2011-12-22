#-------------------------------------------------------------------------------
# Field::Date.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package Field::Date;

use strict;

use base 'Field';
use Time::Local;


$Field::ValidationData{'validdate'} =
	sub {
			my $self = shift;
			my $value = shift;
			my ($y,$m,$d) = split(/-/,$value);
			return (($y+$m+$d > 0) && 
				($m < 1 || $d < 1 || $y < 99 || $d > 31 || $m > 12) || 
				($d > 30 && ($m == 4 || $m == 6 || $m == 9 || $m == 11)) ||
				($m == 2 && ($d > 29 || ($d > 28 && ($y%4 != 0))))
				)?'validdate_err':'';
		};
$Field::ValidationData{'validdate_err'} = '<FONT class="errortext">Bad date</font> ';

$Field::ValidationData{'futuredate'} =
	sub {
			my $self = shift;
			my $value = shift;
			my ($y,$m,$d) = split(/-/,$value);
			my ($sec,$min,$hour,$day,$month,$year) = localtime(time);
			$year += 1900;
			$month++;
			return (($y > $year) || ($y == $year && $m > $month) || ($y == $year && $m == $month && $d > $day))?'':'futuredate_err';
		};
$Field::ValidationData{'futuredate_err'} = '<FONT class="errortext">Date must be in the future</font> ';
$Field::ValidationData{'pastdate'} =
	sub {
			my $self = shift;
			my $value = shift;
			my ($y,$m,$d) = split(/-/,$value);
			my ($sec,$min,$hour,$day,$month,$year) = localtime(time);
			$year += 1900;
			$month++;
			return (($y < $year) || ($y == $year && $m < $month) || ($y == $year && $m == $month && $d <= $day))?'':'pastdate_err';
		};
$Field::ValidationData{'pastdate_err'} = '<FONT class="errortext">Date must be in the past</font> ';

#		elsif ($v eq 'pastdate') {
#		elsif ($v eq 'futuredate') {

sub buildHTML
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	my @ey;
	my @em;
	my @ed;
	my $default = $self->{'default'};
	if ($default ne '') {
		my ($s,$m,$h,$md,$mo,$y) = localtime;
		if ($default eq 'curyear') {
			@ey = ('default',$y+1900);
		}
		elsif ($default eq 'curyearmonth') {
			@ey = ('default',$y+1900);
			@em = ('default',$mo+1);
		}
		elsif ($default eq 'curdate') {
			@ey = ('default',$y+1900);
			@em = ('default',$mo+1);
			@ed = ('default',$md);
		}
	}
	return $q->textfield(-name => "dm_$f",-size=>2,-maxlength=>2,@em) . '/'.
		  $q->textfield(-name => "dd_$f",-size=>2,-maxlength=>2,@ed) . '/'.
		  $q->textfield(-name => "dy_$f",-size=>5,-maxlength=>4,@ey)
}

sub buildHTMLnoEdit
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	my $page = shift;
	
	return $q->param("dm_$f").'/'.$q->param("dd_$f").'/'.$q->param("dy_$f");
}


sub getFieldValueFromQuery
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	
	my $year = $q->param('dy_'.$f);
	my $month = $q->param('dm_'.$f);
	my $day = $q->param('dd_'.$f);

	$month = int($month);
	$day = int($day);

	if ($year ne '') {
		$year = int($year);
		if ($year < 70 && $year >= 0) {
			$year += 2000;
		}
		elsif ($year >= 70 && $year <= 99) {
			$year += 1900;
		}
	}
	else {
		$year = 0;
	}
	return sprintf("%04d-%02d-%02d",$year,$month,$day);
}

sub setQueryFromFieldValue
{
	my $self = shift;
	my $field = shift;
	my $q = shift;
	my $recordP = shift;
	
	my $v = $recordP->{$field};
	
	$v =~ s/ .*$//;
	
	my ($y,$m,$d) = split (/-/,$v);
	$y = "" if $y == 0;
	$m = "" if $m == 0;
	$d = "" if $d == 0;

	$q->param("dy_$field" => $y);
	$q->param("dm_$field" => $m);
	$q->param("dd_$field" => $d);
}
1;