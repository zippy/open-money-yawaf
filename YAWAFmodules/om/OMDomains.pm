#-------------------------------------------------------------------------------
# OMDomains.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OMDomains;

use strict;
use base 'PAGE::Form';
use OMUtils;

sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;

	
	$self->SUPER::setup($page_name,$app);
}


sub show
{
	my $self = shift;
	my $app = $self->param('app');
	my $om = $app->param('om');

	my $d = $om->domains();

	$self->addTemplatePairs('domains' => $d) if (defined($d) && @$d);
	$self->SUPER::show;
}



1;