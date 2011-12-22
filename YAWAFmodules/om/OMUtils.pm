#-------------------------------------------------------------------------------
# OMUtils.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OMUtils;

use strict;
$OMUtils::account_selector_name = 'account';
$OMUtils::account_cookie_name = 'account';

sub CreateAccount {
	my $app = shift;
	my $account_name = shift;
	my $domain = shift;
	my $table = shift;
	my $user_id = shift;

	my $om = $app->param('om');
	my $sql = $app->param('sql');

	my ($account_id,$domain_id,$is_local) = $om->_resolve_name("$account_name^$domain",'^');

	my $om_id;
	my $err;
	
	if ($account_id != 0) {
		$err = "an account with that name already exists in the selected domain";
	}
	else {
		$om_id = $om->new_account('domain' => $domain);
		$err = "the open money network was unable to allocate an account ($om->{'error'})" if $om_id == 0;
	}
	if ($om_id != 0) {
		my $id = $sql->InsertRecord($table,{'om_account_id' => $om_id,'account_name'=>$sql->Quote($account_name),'user_id'=>$user_id},1);
	}
	return $err;
}

sub GetAccountIDfromCookie{

	my ($app,$q) = (@_);

	my $user_id = $app->getUserID();
	my $sql = $app->param('sql');
	
	my $cookie_act = $q->cookie($OMUtils::account_cookie_name);
	my $query_act = $q->param($OMUtils::account_selector_name);

	my $the_act;
	# an account specification via the querry overrides the cookie and resets it!
	if (defined($query_act) && (!defined($cookie_act) || $cookie_act ne $query_act)) {
		$the_act = $query_act;
		$app->add_cookie($q->cookie(-name=>$OMUtils::account_cookie_name,-value=>$query_act));
	}
	else {
		$the_act = $cookie_act;
	}
	
	# verify that this user actually has access to the account specified by the cookie and the query (no cheating)
	# 
	if ($the_act ne '') {
		$the_act = '' if !_can_user_access_account($app,$user_id,$the_act);
	}
	# get the default account value for this user
	if ($the_act eq '') {
		my $r = $sql->GetRecord('user_om_accounts,om_account',"user_id = $user_id and om_account.id=om_account_id" ,'account_name','domain_id');
		if (defined $r) {
			my $om = $app->param('om');
			$the_act = $r->{'account_name'}.'^'.$om->_domain_id2name($r->{'domain_id'});
		}
		$q->param($OMUtils::account_selector_name => $the_act);
		$app->add_cookie($q->cookie(-name=>$OMUtils::account_cookie_name,-value=>$the_act));
	}
	return $the_act;
}

sub AddAccountSelector
{
	my $self = shift;
	my $app = shift;
	my $q = shift;
	my $the_act = shift;
	
	my $sql = $app->param('sql');

	my $r =  _getUserRecords($app,'user_om_accounts,om_account',['account_name','om_account_id','domain_id'],'om_account.id=om_account_id');

	if (@$r == 1) {
#		my $act_name = $r->[0]->{'account_name'};
		my $act_name = $the_act;
		$self->addTemplatePairs($OMUtils::account_selector_name,$act_name);
	}
	elsif (@$r > 1){
		$self->addFlagsToTemplatPairs('multiple_accounts');
		my $om = $app->param('om');
		
		my @accounts;
		my %account_labels;
		foreach (@$r) {
			my $act_name = $_->{'account_name'};
			my $d = $om->_domain_id2name($_->{'domain_id'});
			my $act = $act_name.'^'.$d;
			$act_name = $act if $d ne '';
			push(@accounts,$act);
			$account_labels{$act} = $act_name;
		}

		$self->{'params'}->{'fieldspec'}->{$OMUtils::account_selector_name} =
			Field::Select->new(
				'name' => $OMUtils::account_selector_name,
				'values' => \@accounts,
				'labels' => \%account_labels,
				'default' => $the_act,
				'onchange' => 'document.act.submit()',
				);
		push (@{$self->{'params'}->{'fields'}},$OMUtils::account_selector_name);
	}
}

# this setup and resolve as exact analogs over in OMCurrencyUtils so it should be refactored!
sub SetupUserAccounts {
	my $page = shift;
	my $app = shift;
	my $sql = $app->param('sql');
	
	my $r =  _getUserRecords($app,'user_om_accounts,om_account',['account_name','om_account_id','domain_id'],'om_account.id=om_account_id');
	my $om = $app->param('om');
	
	foreach (@$r) {
		$_->{'account'} = $_->{'account_name'}.'^'.$om->_domain_id2name($_->{'domain_id'});
	}

	$page->addTemplatePairs('has_accounts' => 1) if @$r>0;
	$page->addTemplatePairs('has_multiple_accounts' => 1) if @$r>1;

	return $r;
}

sub SetupUserOwnedCurrencies {
	my $page = shift;
	my $app = shift;
	my $om = $app->param('om');

	my $r =  _getUserRecords($app,'user_owned_currencies,om_currency',['currency_name','om_currency_id','domain_id'],'om_currency.id=om_currency_id');
	foreach (@$r) {
		$_->{'currency'} = $_->{'currency_name'}.'~'.$om->_domain_id2name($_->{'domain_id'});
	}
	
	$page->addTemplatePairs('has_currencies' => 1) if @$r>0;

	return $r;
}

sub SetupUserMemberCurrencies {
	my $page = shift;
	my $app = shift;

	my $sql = $app->param('sql');
	my $user_id = $app->getUserID();

	my $where .= "user_id = $user_id";
	my $r = $sql->GetRecords('user_member_currencies',$where,['currency','account']);
	foreach (@$r) {

		# later we should look up the currencys long name here.
		my $c = $_->{'currency'};
		if ($c =~ /^([^~]+)/) {
			$c = $1;
		}
		$_->{'currency_name'} = $c;
	}
	$page->addTemplatePairs('member_of_currencies' => 1) if @$r>0;

	return $r;
}

sub SetupUsersInCurrency {
	my $page = shift;
	my $app = shift;
	my $currency = shift;

	my $sql = $app->param('sql');
	my $user_id = $app->getUserID();
	if ($currency =~ /^([^~]+)/) {
		$currency = $1;
	}
	
	my $where .= "currency_name = '".$currency."' and  user_owned_currencies.om_currency_id=om_currency_accounts.currency_id";
	my $r = $sql->GetRecords('om_currency_accounts,user_owned_currencies',$where,['account']);
	my @users_in_currency = ('');
	foreach (@$r) {
		push @users_in_currency, $_->{'account'};
	}
	$page->{'params'}->{'fieldspec'}->{'trade_with'} =
		Field::Select->new(
			'name' => 'trade_with',
			'values' => \@users_in_currency,
			);
	push (@{$page->{'params'}->{'fields'}},'trade_with');
}


sub SetupUserDomains {
	my $page = shift;
	my $app = shift;
	my $classes = shift;

	my $r =  _getUserRecords($app,'user_domains,om_domain',['name','parent','class','om_domain.id'],'om_domain.id=om_domain_id');
	my @domains;
	my $is_steward;
	my $is_admin;
	my $is_member;
	foreach (@$r) {
		my $user_class = $_->{'class'};
		$is_steward  = 1 if ($user_class eq 'steward');
		$is_admin  = 1 if ($user_class eq 'admin');
		$is_member  = 1 if ($user_class eq 'member');
		my @classes = split(',',$classes);
		if (grep($user_class eq $_,@classes)) {
			my $d = $_->{'name'};
			$d .= '.'.$_->{'parent'} if $_->{'parent'} ne '';
			push @domains,{'domain_name' => $d, 'domain_id' => $_->{'id'}, 'class' => $_->{'class'}};
		}
	}
	
	$page->addTemplatePairs('is_domain_admin' => 1) if $is_admin;
	$page->addTemplatePairs('is_domain_member' => 1) if $is_member;
	$page->addTemplatePairs('is_domain_steward' => 1) if $is_steward;
	$page->addTemplatePairs('can_admin' => 1) if $is_steward || $is_admin;

	return \@domains;
}


sub AddDomainSelect {
	my $self = shift;
	my $app = shift;
	my $field_name = shift;
	my $class = shift;
	my $by_id = shift;


	my $domains = SetupUserDomains($self,$app,$class);
#	my $om = $app->param('om');
#	my $domains = $om->domains();
	my @domains;
	my %labels;
	my $default;
	$default = $app->userDefaultDomain();
	foreach (@$domains) {
		my $d = $by_id?$_->{'id'}:$_->{'domain_name'};
		push @domains,$d;
		$labels{$d} = $_->{'domain_name'};
	}
	if (@domains > 0) {
		$self->{'params'}->{'fieldspec'}->{$field_name} =
		Field::Select->new(
			'name' => $field_name,
			'values' => \@domains,
			'labels' => \%labels,
			'default' => $default,
			);
		push (@{$self->{'params'}->{'fields'}},$field_name);
	}
	return $domains;
}

sub _AddDomainSelect {
	my $self = shift;
	my $app = shift;
	my $field_name = shift;
	my $show_root = shift;

	my $om = $app->param('om');

	my $domains = $om->domains();
	my @domains;
	my %labels;
	my $default;
	if ($show_root) {
		push @domains,'';
		$labels{''} = '-root-';
	}
	$default = $app->userDefaultDomain();
	foreach (@$domains) {
		my $d = $_->{'domain'};
		push @domains,$d;
		$labels{$d} = $d;
	}
	if (@domains > 1) {
		$self->{'params'}->{'fieldspec'}->{$field_name} =
		Field::Select->new(
			'name' => $field_name,
			'values' => \@domains,
			'labels' => \%labels,
			'default' => $default,
			);
		push (@{$self->{'params'}->{'fields'}},$field_name);
	}
}


sub AddCurrencySelect {
	my $self = shift;
	my $app = shift;
	my $field_name = shift;

	my $om = $app->param('om');

#	my $currencies = $om->currencies();
	my $sql = $app->param('sql');
	my $c = $sql->GetRecords('user_owned_currencies,om_currency,om_domain','domain_id=om_domain.id and om_currency.id=om_currency_id',['currency_name','parent','name']);
	my @currencies;
	foreach (@$c) {
		my $n = $_->{'currency_name'}.'~'.$_->{'name'};
		$n .= '.'.$_->{'parent'} if $_->{'parent'} ne '';
		push @currencies,$n;
	}
	if (@currencies > 0) {
		$self->{'params'}->{'fieldspec'}->{$field_name} =
		Field::Select->new(
			'name' => $field_name,
			'values' => \@currencies,
#			'default' => $om->default_currency(),
			'validation' => ['required'],
			);
		push (@{$self->{'params'}->{'fields'}},$field_name);
	}
}

sub InterpretSummary
{
	my $self = shift;
	my $app = shift;
	my $om = shift;
	my $currency = shift;
	my $summary = shift;

	my %s = (
		'cid' => $currency,
		'name' => $currency,  #really this should be the long name...
		'balance'=> $summary->{'balance'},
		'volume'=> $summary->{'volume'},
		'last_trade'=> $summary->{'last'}?$app->convertUnixTimeToUserTime($summary->{'last'}):''
		);
	return \%s;
}

#----------

sub _getUserRecords 
{
	my $app = shift;
	my $table = shift;
	my $fields = shift;
	my $where = shift;
	
	my $sql = $app->param('sql');
	my $user_id = $app->getUserID();
	$where = "($where) and " if $where ne '';
	$where .= "(user_id = $user_id)";
	my $r = $sql->GetRecords($table,$where,$fields);
	return $r;
}

sub _parseAccountURL
{
	my $account = shift;
	if ($account =~ /^([^\^]+)\^(.*)/) {
		return ($1,$2);
	}
	return ($account,'');
}

sub _can_user_access_account {
	my $app = shift;
	my $user_id = shift;
	my $account = shift;
	my ($account_name,$domain) = _parseAccountURL($account);
	my $sql = $app->param('sql');
	my $om = $app->param('om');
	my $domain_id = $om->_domain2id($domain);
	return $sql->GetCount('user_om_accounts,om_account',"user_id = $user_id and account_name=".$sql->Quote($account_name)." and om_account.id=om_account_id and domain_id = $domain_id");
}

sub parseSpec
{
	my $text = shift;
	my %s;
	$text = _unixify($text);
	my @l = split(/\n/,$text);
	foreach (@l) {
		/([^:]*): *(.*)/;
		$s{$1}=$2;
	}
	return \%s;
}

sub _unixify
{
	my $d = shift;
	$d =~ s/\x0d\x0a/\n/gs;	#PC style returns
	$d =~ s/\x0d/\n/gs;		#Mac style returns
#	$* = 0;
	$d;
}



1;