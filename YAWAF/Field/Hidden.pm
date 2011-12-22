#-------------------------------------------------------------------------------
# Field::Hidden.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package Field::Hidden;

use strict;

use base 'Field::QueryField';

sub _initialize
{
	my $self = shift;
	$self->{'htmlParamList'} = ['name','default'];
}

sub makeHTML
{
	my $self = shift;
	my $q = shift;
	my $page = shift;
	return $q->hidden(@_);
}


1;