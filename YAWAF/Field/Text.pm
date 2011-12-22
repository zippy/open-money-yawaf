#-------------------------------------------------------------------------------
# Field::Text.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package Field::Text;

use strict;

use base 'Field::QueryField';

sub _initialize
{
	my $self = shift;
	$self->{'htmlParamList'} = ['name','default','size','maxlength','onChange'];
}

sub makeHTML
{
	my $self = shift;
	my $q = shift;
	my $page = shift;
	return $q->textfield(@_);
}

sub getFieldValueFromQuery
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	
	my $v = $q->param($f);
	$v = uc $v if exists $self->{'forceCaps'};
	return $v;
}


1;