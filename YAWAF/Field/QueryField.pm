#-------------------------------------------------------------------------------
# Field::QueryField.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package Field::QueryField;

use strict;

use base 'Field';

sub buildHTML
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	my $page = shift;

	my $noEscape;
	if (exists $self->{'escapeHTML'}) {
		$noEscape = !$self->{'escapeHTML'};
	}
	$q->autoEscape(undef) if $noEscape;
	my $result = $self->makeHTML($q,$page,$self->getMyParamValues($self->{'htmlParamList'}));
	$q->autoEscape(1) if $noEscape;
	return $result
}

sub buildHTMLnoEdit
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	my $page = shift;
	my $fv;
	
	if (exists $self->{'labels'}) {
		my $v = $self->{'labels'}->{$q->param($f)};
		return '' if $v eq '-';
		return $v;	
	}
	return $q->param($f);
}

sub getMyParamValues
{
	my $self = shift;
	my $listP = shift;
	my @f;
	foreach (@$listP) {
		push (@f,'-'.$_,$self->{$_}) if exists($self->{$_});
	}
	return @f;
}

sub makeHTML
{
	my $self = shift;
	my $q = shift;
	my $page = shift;
	die 'makeHTML must be overridden';
}

1;