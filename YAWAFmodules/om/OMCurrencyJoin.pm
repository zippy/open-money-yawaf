#-------------------------------------------------------------------------------
# OMCurrencyJoin.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OMCurrencyJoin;

use strict;
use base 'PAGE::Form';
use OMUtils;
use Field::ScrollingList;

sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;
	my $q = $app->query();
	
#	my $m = OMUtils::SetupUserMemberCurrencies($self,$app);
#	if (@$m > 0) {
#		my %member_currencies;
#		foreach (@$m) {
#			my $act = $member_currencies{$_->{'currency'}};
#			$act = [] if !defined($act);
#			push @$act,{'account'=>$_->{'account'}};
#			$member_currencies{$_->{'currency'}}=$act;
#		}
#		my @member_currencies;
#		foreach ( keys %member_currencies) {
#			push @member_currencies,{'name'=>$_,'accounts'=>$member_currencies{$_}};
#		}
#		$self->addTemplatePairs('memberships' => \@member_currencies);
#	}
#<tmpl_if memberships> {{Currencies you are member of:}}
#<tmpl_loop memberships> 
#	<br /><tmpl_var name><tmpl_if has_multiple_accounts> in account(s) <tmpl_loop accounts><tmpl_unless name="__first__">, </tmpl_unless><tmpl_var account></tmpl_loop></tmpl_if>
#</tmpl_loop>
#</tmpl_if>
	
	
	my $sql = $app->param('sql');
	my $c = $sql->GetRecords('user_owned_currencies,om_currency,om_domain','domain_id=om_domain.id and om_currency.id=om_currency_id',['currency_name','parent','name']);
	my @v;
	foreach (@$c) {
		my $n = $_->{'currency_name'}.'~'.$_->{'name'};
		$n .= '.'.$_->{'parent'} if $_->{'parent'} ne '';
		push @v,$n;
	}
	
	$self->{'params'}->{'fields'} = ['currency_name','currency_auth'];
	
	my $c_name_field = $self->{'params'}->{'list_currencies_in_pop_up'}?
			Field::Select->new(
			'name' => 'currency_name',
			'validation' => ['required'],
			'values' => \@v
			):
			Field::Text->new(
			'name' => 'currency_name',
			'validation' => ['required'],
			'size' => 20,
			'maxlength' => 255,
			);
	
	$self->{'params'}->{'fieldspec'} = {
		'currency_name' => $c_name_field,
		'currency_auth' => Field::Text->new(
			'name' => 'currency_auth',
			'size' => 10,
			'maxlength' => 255,
			),
		};

	my $r = OMUtils::SetupUserOwnedCurrencies($self,$app);
	my $acts = OMUtils::SetupUserAccounts($self,$app);
	$q->{'_acts'} = $acts;
	my @account_values;
	my %account_labels;
	if (@$acts > 1) {
		foreach my $r (@$acts){
			push @account_values,$r->{'account'};
			$account_labels{$r->{'account'}} = $r->{'act_id'};
		}
		$self->{'params'}->{'fieldspec'}->{'account_select'} =
			Field::ScrollingList->new(
				'name' => 'account_select',
				'values' => \@account_values,
				'labels' => \%account_labels,
				'validation' => ['required'],
				'multiple' => 'true',
				'size' => @$acts,
				);
		push (@{$self->{'params'}->{'fields'}},'account_select');
	}
	
	$q->{'__accounts'} = $acts;
	
	$self->SUPER::setup($page_name,$app);
}

sub show
{
	my $self = shift;
	my $app = $self->param('app');
	my $om = $app->param('om');
	my $q = $app->query();

	my $acts = $q->{'_acts'};
	my @sum;
	foreach my $act (@$acts) {
		my $act_name = $act->{'account'};
		my $s = $om->trade_summary(
			'account' => $act_name,
			);
		foreach (@$s) {
			my $summary =  $_->{'summary'};
			my $currency =  $_->{'currency'};
			my $sH = $self->OMUtils::InterpretSummary($app,$om,$currency,$summary);
			$sH->{'account'} = $act_name;
			push (@sum,$sH);
		}
	}
	$self->addTemplatePairs('summary' => \@sum) if (defined @sum);
	
	$self->SUPER::show;
	
}

sub doSubmit
{
	my $self = shift;
	my $app = $self->param('app');
	my $sql = $self->param('sql');
	my $q = $app->query();
	
	my $om = $app->param('om');
	my $currency = $q->param('currency_name');
	my $currency_auth = $q->param('currency_auth');
	
	#this is meaningless becasue the currency is picked from the pop-up!!!
	# but needs to be fixed later.
	$currency .= '~'.$app->userDefaultDomain() if $currency !~ /\~/;
	
	my $acts = $q->{'__accounts'};
	my @accounts;
	if (@$acts > 1) {
		@accounts = $q->param('account_select');
	}
	else {
		push @accounts,$acts->[0]->{'account'};
	}
	my @errors;
		
	my $join_ids = $om->join_currency('currency'=>$currency,'join_authorization'=>$currency_auth,'accounts'=>\@accounts); #'access_authorization'=> {act_id=>'auth_block'}
	if (!defined $join_ids || scalar (keys %$join_ids) == 0) {
		push (@errors,qq#the open money network did not allow you to join this currency ($om->{'error'})#);
	}
	else {
		my $user_id = $app->getUserID();
		foreach my $account (keys %$join_ids) {
			if ($join_ids->{$account}) {
				my $id = $sql->InsertRecord('user_member_currencies',{'currency' => $sql->Quote($currency),'user_id'=>$user_id,'account'=>$sql->Quote($account)},1);
			}
		}
	}
	if (@errors) {
		$self->addTemplatePairs('error.currency_name' => '<span class="errortext">'.join(',',@errors).'</span>');
		return $self->show;				
	}
	return '';
}


1;