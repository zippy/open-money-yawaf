#-------------------------------------------------------------------------------
# OM::NameResolver.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OM::NameResolver;

use strict;
use Carp;

sub new {
	my $class = shift;
	my $self = {@_};
	
	bless $self, $class;
	$self->_initialize();

	return $self;
}

sub _initialize
{
	my $self = shift;
}


1;