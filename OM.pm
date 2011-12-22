#-------------------------------------------------------------------------------
# OM.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OM;

use strict;
use Carp;
use OM::AccountServiceSQL;
use OM::CurrencyServiceSQL;
use OM::DomainServiceSQL;
use OM::NameResolverSQL;

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

sub new_account {
	my $self = shift;
	my $params = _getParams({
		'domain'=>'optional',
		'access_control'=>'optional',		
		'access_authorization'=>'optional'
		},@_);
	my $domain_service = $self->_get_domain_service($params->{'domain'},$params->{'access_authorization'});
	if (defined $domain_service) {
		return $domain_service->new_account($params->{'access_control'});
	}
	return 0;
}


sub record_trade {
	my $self = shift;
	my $params = _getParams(
		{
		'account'=>'required',
		'transaction_id'=>'required',
		'with'=>'required',
		'currency'=>'required',
		'datetime'=>'required',
		'datetime_format'=>'optional',
		'specification'=>'required',
		'account_access_authorization'=>'optional',
		'currency_access_authorization'=>'optional'
		},@_);

	my $account_service = $self->_get_account_service($params->{'account'},$params->{'account_access_authorization'});
	if (defined $account_service) {
		if ($account_service->{'account_id'} == 0) {
			$self->{'error'} = "unknown account: $params->{'account'}";
			return undef;
		}
		my $with_account_service = $self->_get_account_service($params->{'with'}); #generic record with access
		if ($with_account_service->{'account_id'} == 0) {
			$self->{'error'} = "unknown account: $params->{'with'}";
			return undef;
		}
		if ($with_account_service->{'account_id'} == $account_service->{'account_id'}) {
			$self->{'error'} = "trades must be between different accounts.";
			return undef;
		}
			
		# we should be checking in with the currency service to make sure the trade is ok.
		my $currency_service = $self->_get_currency_service($params->{'currency'},$params->{'currency_access_authorization'});
		
		my $spec = $params->{'specification'};
		my $ok = $currency_service->prepare_trade($params->{'account'},$params->{'with'},$spec);
		if (!$ok) {
			$self->{'error'} = $currency_service->{'error'};
			return 0;			
		}
		
		#this is bogus because we should be doing some kind of ACID transaction here, but for now...
		$spec->{'amount'} = -$spec->{'amount'};
		my $w =  $with_account_service->record_trade($params->{'transaction_id'},$params->{'account'},$params->{'currency'},$params->{'datetime'},$params->{'datetime_format'},$spec);
		if ($w == 0) {
			$self->{'error'} = $with_account_service->{'error'};
			return 0;
		}
		$spec->{'amount'} = -$spec->{'amount'};
		
		my $id = $account_service->record_trade($params->{'transaction_id'},$params->{'with'},$params->{'currency'},$params->{'datetime'},$params->{'datetime_format'},$spec);
		if ($id == 0) {
			$self->{'error'} = $with_account_service->{'error'};
			return 0;
		}
		return 1;
	}
	return 0;
}

sub trade_summary {
	my $self = shift;
	my $params = _getParams({
		'account'=>'required',
		'filter'=>'optional',
		'access_authorization'=>'optional'
		},@_);

	my $account_service = $self->_get_account_service($params->{'account'},$params->{'access_authorization'});
	if (defined $account_service) {
		if ($account_service->{'account_id'} == 0) {
			$self->{'error'} = "unknown account: $params->{'account'}";
			return undef;
		}
		return $account_service->get_trade_summary($params->{'filter'});
	}
	return undef
}

sub trade_history {
	my $self = shift;
	my $params = _getParams({
		'account'=>'required',
		'filter'=>'optional',
		'access_authorization'=>'optional'
		},@_);

	my $account_service = $self->_get_account_service($params->{'account'},$params->{'access_authorization'});
	if (defined $account_service) {
		if ($account_service->{'account_id'} == 0) {
			$self->{'error'} = "unknown account: $params->{'account'}";
			return undef;
		}
		return $account_service->get_trade_history($params->{'filter'});
	}
	return undef;
}


sub new_currency {
	my $self = shift;
	my $params = _getParams(
		{
		'domain'=>'optional',
		'access_authorization'=>'optional',
		'access_control'=>'optional',
		'specification'=>'required'
		}
		,@_);
	
	my $spec = __getParams(
		{
			'name'=>'optional',
			'description'=>'optional',
			'type'=>'required',
			'unit'=>'required',
		}
		,$params->{'specification'});

	if (ref($spec) ne 'HASH') {
		$self->{'error'} = "missing spec parameter ($spec)";
		return 0;
	}
	my $domain_service = $self->_get_domain_service($params->{'domain'},$params->{'access_authorization'});
	if (defined $domain_service) {
		return $domain_service->new_currency($spec,$params->{'access_control'});
	}
	return 0;
}

sub join_currency {
	my $self = shift;
	my $params = _getParams(
		{
		 'currency'=>'required',
		 'accounts'=>'required',
		 'join_authorization'=>'optional',
		 'access_authorization'=>'optional',
		}
		,@_);
	my $currency_service = $self->_get_currency_service($params->{'currency'},$params->{'access_authorization'});
	if (defined $currency_service) {
		if ($currency_service->{'currency_id'} == 0) {
			$self->{'error'} = "unknown currency: $params->{'currency'}";
			return undef;
		}
		my $ret_val = $currency_service->join_currency($params->{'accounts'},$params->{'join_authorization'});
		
		#this doesn't handle partial success, i.e. if it joins for one account but not all of them...
		if (defined $currency_service->{'error'}) {
			$self->{'error'} = join(',',@{$currency_service->{'error'}});
		}
		else {
			foreach my $account (@{$params->{'accounts'}}) {
				#the access_authorization here is probably wrong because that's the currency access, not the account access
				my $account_service = $self->_get_account_service($account,$params->{'access_authorization'});
				if (defined $account_service) {
					$account_service->initialize_trade_summary($params->{'currency'});
				}
			}			
			return $ret_val;
		}
	}
	return undef;
}

sub reverse_trade {
	my $self = shift;
	my $params = _getParams(
		{
		'currency'=>'required',
		'datetime'=>'required',
		'transaction_id'=>'required',
		'comment'=>'optional',
		'access_authorization'=>'optional'
		},@_);
	my $currency_service = $self->_get_currency_service($params->{'currency'},$params->{'access_authorization'});
	if (defined $currency_service) {
		my $ret_val = $currency_service->reverse_trade($params->{'datetime'},$params->{'transaction_id'},$params->{'comment'});
		if (defined $currency_service->{'error'}) {
			$self->{'error'} = $currency_service->{'error'};
			return undef;
		}
		return $ret_val;
	}	
	return undef;		
}

sub get_currency_stats
{
	my $self = shift;
	my $params = _getParams(
		{
		 'currency'=>'required',
		 'filter'=>'optional',
		 'access_authorization'=>'optional',
		}
		,@_);
	my $currency_service = $self->_get_currency_service($params->{'currency'},$params->{'access_authorization'});
	if (defined $currency_service) {
		my $ret_val = $currency_service->get_currency_stats($params->{'filter'});
		return $ret_val;
	}	
	return undef;		
}
# access authorization is passwords for:
#  viewing existence
#  adding an account (create/allow)
#  adding a subdomain
#  black-listing accounts
#  black-listing outside currencies
#  freeze account
#  freeze currency
# properties:
#  adding account requires approval

sub domains {
	my $self = shift;
	my $params = _getParams(
		{
		'parent_domain'=>'optional',
		'access_authorization'=>'optional',
		}
		,@_);
	
	my $domain_service = $self->_get_domain_service($params->{'parent_domain'},$params->{'access_authorization'});
	if (defined $domain_service) {
		my $domains = $domain_service->domains();
		return $domains if (!defined($domains));
		$self->{'error'} = $domain_service->{'error'};
	}
	return undef;
}

sub new_domain {
	my $self = shift;
	my $params = _getParams(
		{
		'name'=>'required',
		'parent_domain'=>'optional',
		'specification'=>'required',
		'access_authorization'=>'optional',
		'access_control'=>'optional',
		}
		,@_);
	my $spec = __getParams(
		{
			'description'=>'optional',
		}
		,$params->{'specification'});
	if (ref($spec) ne 'HASH') {
		$self->{'error'} = "missing spec parameter ($spec)";
	}
	else {
		my $domain_service = $self->_get_domain_service($params->{'parent_domain'},$params->{'access_authorization'});
		if (defined $domain_service) {
			my $id = $domain_service->new_domain($params->{'name'},$spec,$params->{'access_control'});
			return $id if ($id != 0);
			$self->{'error'} = $domain_service->{'error'};
		}
	}
	return 0;
}

sub resolve_account_name {
	my $self = shift;
	my $accountURL = shift;
	return $self->_resolve_name($accountURL,'^');
}

sub resolve_currency_name {
	my $self = shift;
	my $accountURL = shift;
	return $self->_resolve_name($accountURL,'~');
}

#--------------------------------------

sub _get_account_service {
	my $self = shift;
	my $accountURL = shift;
	my $authorization = shift;

	my ($account_id,$domain_id,$is_local) = $self->resolve_account_name($accountURL);
	# determine which account service code to instantiate depending on the
	# domain name which must be resolved down to an om num

	if ($is_local) {
		my @sqlp = %{$self->{'account_tables'}};
		return OM::AccountServiceSQL->new(
			'domain_id' => $domain_id,
			'domain_table' => $self->{'domain_tables'}->{'domain_table'},
			'account_id' => $account_id,
			'account_name' => $accountURL,
			'authorization' => $authorization,
			'sql' => $self->{'sql'},
			@sqlp
			);
	}
	croak 'non-local domains not yet implmented';
}

sub _get_domain_service {
	my $self = shift;
	my $parentDomain = shift;
	my $authorization = shift;
		
	my $domain_id = $self->_domain2id($parentDomain);
	if ($domain_id != 0) {
		my @sqlp = %{$self->{'domain_tables'}};
		return OM::DomainServiceSQL->new(
			'domain_id' => $domain_id,
			'domain_table' => $self->{'domain_tables'}->{'domain_table'},
			'account_table' => $self->{'account_tables'}->{'account_table'},
			'currency_table' => $self->{'currency_tables'}->{'currency_table'},
			'authorization' => $authorization,
			'sql' => $self->{'sql'},
			@sqlp
			);
	}

	croak 'non-local domains not yet implmented';
}


sub _get_currency_service {
	my $self = shift;
	my $currencyURL = shift;
	my $authorization = shift;
	
	my ($currency_id,$domain_id,$is_local) = $self->resolve_currency_name($currencyURL);
	# determine which account service code to instantiate depending on the
	# domain name which must be resolved down to an om num

	if ($is_local) {
		my @sqlp = %{$self->{'currency_tables'}};
		return OM::CurrencyServiceSQL->new(
			'domain_id' => $domain_id,
			'domain_table' => $self->{'domain_tables'}->{'domain_table'},
			'currency_id' => $currency_id,
			'currency_name' => $currencyURL,
			'authorization' => $authorization,
			'sql' => $self->{'sql'},
			@sqlp
			);
	}
	croak 'non-local domains not yet implmented';
}

sub _domain2id {
	my $self = shift;
	my $domain = shift;
	
	my $sql = $self->{'sql'};
	my $table = $self->{'domain_tables'}->{'domain_table'};
	my $name;
	my $parent;
	if ($domain =~ /([^.]+)\.(.+)/) {
		($name,$parent) = ($1,$2);
	}
	else {
		$name = $domain;
		$parent = '';
	}
	my $r = $sql->GetRecord($table,'name='.$sql->Quote($name).' and parent='.$sql->Quote($parent),'id');

	return defined($r)?$r->{'id'}:0;	
}

sub _domain_id2name {
	my $self = shift;
	my $domain_id = shift;

	my $sql = $self->{'sql'};
	my $table = $self->{'domain_tables'}->{'domain_table'};
	my $r = $sql->GetRecord($table,"id=".int($domain_id),'name','parent');
	my $d = '';
	if (defined($r)) {
		$d = $r->{'name'};
		$d .= '.'.$r->{'parent'} if $r->{'parent'} ne '';
	}
	return $d;
}


# this is more bogusness because as I set it up before OM.pm shouldn't know about account names.
# obviously there is a problem here.
sub _account_id2name {
	my $self = shift;
	my $account_id = shift;

	my $sql = $self->{'sql'};
	my $table = $self->{'account_tables'}->{'account_table'};
	my $r = $sql->GetRecord($table,"id=".int($account_id),'domain_id');
	if (defined($r)) {
		my $domain = $self->_domain_id2name($r->{'domain_id'});
		my $r = $sql->GetRecord('user_om_accounts',"om_account_id=".int($account_id),'account_name');
		return $r->{'account_name'}.'^'.$domain if defined($r);
	}
	return '';
}


sub _resolve_name {
	my $self = shift;
	my $url = shift;
	my $separator = shift;
	
	my $domain_id;
	my ($name,$domain);
	my $pat = "([^\\$separator]+)\\$separator(.*)";
	if ($url =~ /$pat/) {
		($name,$domain) = ($1,$2);
	}
	else {
		$name = $url;
	}
	
#	if ($domain eq '') {
#		$domain_id = -1;
#	}
#	else {
		$domain_id = $self->_domain2id($domain);
#	}
	
	my $is_local;	
	my $resolver;
	if ($domain_id == 0) {
		$is_local = 0;
		croak "can't resolve a non-local domain in $url yet!";
		# do something here to actually get the correct domain id!
	}
	else {
		$resolver = OM::NameResolverSQL->new(
			'domain_id' => $domain_id==-1?0:$domain_id,
			'sql' => $self->{'sql'},
			);
		$is_local = 1;
	}
	my $id;
	if ($name ne '') {
		if ($separator eq '^') {
			$id = $resolver->ResolveAccountName($name);
		}
		else {
			$id = $resolver->ResolveCurrencyName($name);
		}
	}
	return ($id,$domain_id,$is_local);
}


sub _getParams {
	my $p = __getParams(@_);
	return $p if ref($p) eq 'HASH';
	croak($p);
}

sub __getParams {
	my $param_spec = shift;
	my $params;
	if (ref($_[0]) eq 'HASH') {
		$params = shift;
	}
	else {
		$params = {@_};
	}
	my %p;
	while (my ($param,$spec) = each(%$param_spec)) {
		if (exists($params->{$param})) {
			$p{$param} = $params->{$param};
		}
		else {
			return "$param required" if $spec eq 'required';
		}
	}
	return \%p;
}

1;

=pod

=head1 NAME

OM - 
An implementation of the open money API

=head1 SYNOPSIS

	my $om = OM->new();
	my $om_id = $om->new_account('domain' => 'some.domain.us');
	my $err = "the open money network was unable to allocate an account ($om->{'error'})" if $om_id == 0;

=head1 ABSTRACT

=head1 DESCRIPTION

=head1 LICENSE

OM : open money Perl Interface
Copyright (C) 2006-2007 Harris-Braun Enterprises, LLC, <eric -at- harris-braun.com>

This module is free software; you can redistribute it and/or modify it
under the terms of either:

a) the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version,

or

b) the "Artistic License" which comes with this module.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
the GNU General Public License or the Artistic License for more details.

You should have received a copy of the Artistic License with this
module, in the file ARTISTIC.  If not, I'll be glad to provide one.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
USA


=cut



