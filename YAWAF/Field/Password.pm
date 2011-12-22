#-------------------------------------------------------------------------------
# Field::Password.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package Field::Password;

use strict;

use base 'Field::QueryField';

sub _initialize
{
	my $self = shift;
	$self->{'htmlParamList'} = ['name','size','maxlength','onChange'];
}

sub makeHTML
{
	my $self = shift;
	my $q = shift;
	my $page = shift;
	return $q->password_field(@_);
}


1;