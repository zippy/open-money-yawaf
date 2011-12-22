#-------------------------------------------------------------------------------
# OMActNew.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OMActNew;

use strict;
use base 'PAGE::Form';
use OMUtils;

sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;

	OMUtils::AddDomainSelect($self,$app,'domain','user,admin,steward');
	$self->SUPER::setup($page_name,$app);
}

sub doSubmit
{
	my $self = shift;
	my $app = $self->param('app');
	my $q = $app->query();
	
	my $account_name = $q->param('account_name');
	my $domain = $q->param('domain');
	my $user_id = $app->getUserID();
	
	my $err = OMUtils::CreateAccount($app,$account_name,$domain,$self->{'params'}->{'table'},$user_id);
	if ($err ne '') {
		$self->addTemplatePairs('error.account_name' => qq#<span class="errortext">$err</span>#);
		return $self->show;				
	}
	return '';
}

1;