#-------------------------------------------------------------------------------
# OMImportAccounts.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OMImportAccounts;

use strict;
use base 'PAGE::Form';
use OMUtils;
use Carp;

sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;

	my $q = $app->query();
	
	$self->OMUtils::AddDomainSelect($app,'domain','steward');
	$self->{'params'}->{'fieldspec'}->{'import'} =
	Field::TextArea->new(
		'name' => 'import',
		'validation' => ['required'],
		'rows' => 24,
		'columns' => 70
		);
	push (@{$self->{'params'}->{'fields'}},'import');
	$self->OMUtils::AddCurrencySelect($app,'currency');

	$self->SUPER::setup($page_name,$app);
}

sub doSubmit
{
	my $self = shift;
	my $app = $self->param('app');
	my $q = $app->query();
	
	my $sql = $self->param('sql');

	my @accounts = split(/\n/,OMUtils::_unixify($q->param('import')));	
	my $x;
	my %acts;
	my @errs;
	foreach (@accounts) {
		my @fields = split(/,/);
		my ($name,$password,$fname,$lname,$email,$phone,$fax,$address1,$address2,$city,$state,$zip,$country) = @fields;
		if (@fields != 13) {
			push @errs, "incorrect number of fields for account name $name";
		}
		my $n = $sql->Quote($name);
		$acts{$name} = {
			'name' => $n,
			'password' => $sql->Quote($password),
			'created' => 'NOW()',
			'lname' => $sql->Quote($lname),
			'fname' => $sql->Quote($fname),
			'email' => $sql->Quote($email),
			'address1' => $sql->Quote($address1),
			'address2' => $sql->Quote($address2),
			'city' => $sql->Quote($city),
			'state' => $sql->Quote($state),
			'zip' => $sql->Quote($zip),
			'phone' => $sql->Quote($phone),
			'fax' => $sql->Quote($fax),
			'country' => $sql->Quote($country),
			};
		if ($sql->GetCount('account',"name = $n")) {
			push @errs, "account $n already exist";
		}
	}

	if (!@errs) {

		my $domain = $q->param('domain');	
		my $currency = $q->param('currency');	
		my $om = $app->param('om');
		my $om_domain_id = $om->_domain2id($domain);
		my %user_ids;
		foreach my $n (keys %acts) {
			my $act = $acts{$n};
			my $user_id = $sql->InsertRecord('account',$act,1);
			my %rec;
			my $err = OMUtils::CreateAccount($app,$n,$domain,'user_om_accounts',$user_id);
			$rec{'user_id'} = $user_id;
			$rec{'class'} = "'user'";
			$rec{'om_domain_id '} = $om_domain_id;
			$sql->InsertRecord('user_domains',\%rec,1);
			
			if ($currency ne '') {
				my @acts = ("$n^$domain");
				my $join_ids = $om->join_currency('currency'=>$currency,'join_authorization'=>'','accounts'=>\@acts); #'access_authorization'=> {act_id=>'auth_block'}
				if (!defined $join_ids || scalar (keys %$join_ids) == 0) {
					push (@errs,qq#the open money network did not allow you to join this currency ($om->{'error'})#);
				}
				else {
					foreach my $account (keys %$join_ids) {
						if ($join_ids->{$account}) {
							my $id = $sql->InsertRecord('user_member_currencies',{'currency' => $sql->Quote($currency),'user_id'=>$user_id,'account'=>$sql->Quote($account)},1);
						}
					}
				}
			}
		}
	}
	if (@errs) {
		my $err = join('<br>',@errs);
		$self->addTemplatePairs('error.import' => qq#<span class="errortext">$err</span>#);
	}
	else {
		$self->addTemplatePairs('import_successful' => 1);
	}
	return $self->show();
}


1;