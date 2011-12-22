#-------------------------------------------------------------------------------
# Field::CheckBox.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package Field::CheckBox;

use strict;

use base 'Field::QueryField';

sub _initialize
{
	my $self = shift;
	$self->{'htmlParamList'} = ['name','checked','value','label','onClick'];
}

sub makeHTML
{
	my $self = shift;
	my $q = shift;
	my $page = shift;
	my @f = @_;
	push (@f,'label','') if not exists $self->{'label'};
	return $q->checkbox(@f);
}

sub getFieldValueFromQuery
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	
	my $v = $q->param($f);
	$v = 'N' if not defined $v;
	return $v;
}

1;