#-------------------------------------------------------------------------------
# OMDomainAdmin.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OMDomainAdmin;

use strict;
use base 'PAGE::Form';
use OMUtils;

sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;

	my $r = OMUtils::AddDomainSelect($self,$app,'domain_select','admin,steward');
	
	my $q = $app->query();
	
	my $html;
	if (@$r > 1) {
		my @v;
		foreach (@$r) {
			push (@v,$_->{'domain_name'});
		}
		$html = $q->popup_menu(
			'-name' => 'domain_select',
			'-values' => \@v,
#			'onChange' => 'document.act.submit()',
		);
	}
	else {
		$html = $r->[0]->{'domain_name'};
	}
	$self->addTemplatePairs('domain_select',$html);
	
	$self->SUPER::setup($page_name,$app);
}


1;