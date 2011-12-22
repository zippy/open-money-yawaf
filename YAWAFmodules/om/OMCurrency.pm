#-------------------------------------------------------------------------------
# OMCurrency.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OMCurrency;

use strict;
use base 'PAGE::Form';
use OMUtils;

sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;

	my $r = OMUtils::SetupUserOwnedCurrencies($self,$app);
	OMUtils::AddDomainSelect($self,$app,'domain','user,admin,steward');	
	$self->SUPER::setup($page_name,$app);
}

sub doSubmit
{
	my $self = shift;
	my $app = $self->param('app');
	my $sql = $self->param('sql');
	my $q = $app->query();
	
	my $om = $app->param('om');
	my $currency_name = $q->param('currency_name');
	my $advanced = $q->param('advanced');
	my $domain = $q->param('domain');
	
	my $spec;
	if ($advanced) {
	 	$spec = OMUtils::_parseSpec($q->param('currency_spec'));
	}
	else {
		my %s;
		foreach ('description','name','type','unit') {
			my $v = $q->param($_);
			if (defined $v) {
				$v = OMUtils::_unixify($v);
				$v =~ s/\n/\\n/;
				$s{$_} = $v;
			}
		}
		$spec = \%s;
	}

	#BOGUS this is a cheat because we shouldn't know the table names here at all.  It's part of the current structural failures of
	#where the names of currencies are stored.
	my $domain_id = $om->_domain2id($domain);
	if ($sql->GetCount('om_currency,user_owned_currencies',"domain_id=$domain_id and currency_name=".$sql->Quote($currency_name).' and om_currency.id = om_currency_id')) {
		$self->addTemplatePairs('error.currency_name' => qq#<span class="errortext">there is already a currency with that name in the specified domain</span>#);
		return $self->show;				
	}

	my $om_id = $om->new_currency('domain' => $domain, 'specification'=>$spec);
	if ($om_id == 0) {
		$self->addTemplatePairs('error.currency_name' => qq#<span class="errortext">the open money network was unable to create a new currency ($om->{'error'})</span>#);
		return $self->show;				
	}
	else {
		my $user_id = $app->getUserID();
		my $id = $sql->InsertRecord($self->{'params'}->{'table'},{'om_currency_id' => $om_id,'currency_name'=>$sql->Quote($currency_name),'user_id'=>$user_id},1);
	}
	$q->param('currency_name',$currency_name.'~'.$domain);
	return '';
}

1;