#-------------------------------------------------------------------------------
# OM::AccessController.pm
# �2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OM::AccessController;

use strict;
use Carp;

sub new {
	my $class = shift;
	my $spec = shift;
	my $self = {'spec'=>$spec};
	
	bless $self, $class;
	$self->_initialize();

	return $self;
}

sub _initialize
{
	my $self = shift;
}

sub checkAccess {
	my $self = shift;
	my $authorization = shift;
	my $action = shift;
	
	return 1 if (!defined $authorization);
	
	my $action_spec = $self->{'spec'}->{$action};
	my $auth_spec = $authorization->{$action};
	return $action_spec == $auth_spec;
	
}


1;