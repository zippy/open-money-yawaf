#-------------------------------------------------------------------------------
# NewUser.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package NewUser;

use strict;
use base 'PAGE::NewUser';

sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;

	# TODO: check here to make sure that the om account name isn't taken
	# the YAWAF name is checked by the validation flag for name, but the om name isn't

	$self->SUPER::setup($page_name,$app);
}


sub doNewUser {
	my $self = shift;
	my ($app,$sql,$id,$account_name,$email,$pairsP) = @_;

	my $om = $app->param('om');
	my $err;
	
	if (defined $om->{'default_domain'}) {
		my $domain = $om->{'default_domain'};
	
		my $om_domain_id = $om->_domain2id($domain);
	
		my %rec;
		$rec{'user_id'} = $id;
		$rec{'class'} = "'user'";
		$rec{'om_domain_id '} = $om_domain_id;
		$sql->InsertRecord('user_domains',\%rec,1);

		$err = OMUtils::CreateAccount($app,$account_name,$domain,$self->{'params'}->{'om_act_table'},$id);	
	}

	return $err;
}

1;