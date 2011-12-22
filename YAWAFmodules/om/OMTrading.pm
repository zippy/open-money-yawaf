#-------------------------------------------------------------------------------
# OMTrading.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OMTrading;

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
	
	my $account = OMUtils::GetAccountIDfromCookie($app,$q);
	$self->OMUtils::AddAccountSelector($app,$q,$account);

	$self->addTemplatePairs('act' => $account);

	my $om = $app->param('om');
	
	$q->{'__account'} = $account;

	my $m = OMUtils::SetupUserMemberCurrencies($self,$app);
	
	my @currencies;
	my %currency_labels;
	foreach (@$m) {
		if ($account eq $_->{'account'}) {
			my $id = $_->{'currency'};
			push (@currencies,$id);
			$currency_labels{$id} = $_->{'currency_name'};
		}
	}
	
	my $currency = $q->param('trade_currency');
	if ($currency eq '') {
		$currency = $q->param('currency');
	}
	if ($currency eq '' && @$m) {
		$currency = $m->[0]->{'currency'};
	}
	$q->{'__currency'} = $currency;
	$q->{'__my_currencies'} = \%currency_labels;
	$self->addTemplatePairs(
		'currency_name' => $currency_labels{$currency},
		'currency' => $currency,
		'transaction_id' => time
		);
		
	OMUtils::SetupUsersInCurrency($self,$app,$currency);


	if (@currencies) {
		$self->{'params'}->{'fieldspec'}->{'trade_currency'} =
		Field::Select->new(
			'name' => 'trade_currency',
			'values' => \@currencies,
#			'labels' => \%currency_labels,
			'validation' => ['required'],
			'onchange' => q#document.trade.m.value='show';document.trade.submit()#,
			);
		push (@{$self->{'params'}->{'fields'}},'trade_currency');
	}

	$self->SUPER::setup($page_name,$app);
}

sub show
{
	my $self = shift;
	my $app = $self->param('app');
	my $om = $app->param('om');
	my $q = $app->query();

	my $account = $q->{'__account'};

	if ($account ne '') {
		my $currency = $q->{'__currency'};
		
		my %filter = ('currencies' => [$currency]);
	
		my $s = $om->trade_summary(
			'account' => $account,
			'filter' => \%filter
			);
		my @sum;
		foreach (@$s) {
			my $summary =  $_->{'summary'};
			push (@sum,$self->OMUtils::InterpretSummary($app,$om,$currency,$summary));
		}
	
		$self->addTemplatePairs('summary' => \@sum) if (defined @sum);
		$filter{'limit'} = 5;
		my ($h,$total) = $om->trade_history(
			'account' => $account,
			'filter' => \%filter
			);
	
		my @history;
		my $tz = $app->getUserTimeZone;
		foreach (@$h) {
			my $r = {
				'trade_date'=>$app->convertUnixTimeToTimeZoneTime($_->{'created'},$tz),
				'trade_with'=>$_->{'with_account'},
				'trade_amount'=>$_->{'transaction'}->{'amount'},
				'trade_for'=>$_->{'transaction'}->{'description'},
				'trade_tax'=>$_->{'transaction'}->{'tax-status'}
				};
			foreach my $f (qw(trade_amount trade_currency trade_for)) {
				$r->{$f} = $q->escapeHTML($r->{$f});
			}
			push(@history, $r);
		}
	
		$self->addTemplatePairs('history' => \@history) if (defined @history);
	}
	
	$self->SUPER::show;
}

sub doSubmit
{
	my $self = shift;
	my $app = $self->param('app');
	my $sql = $self->param('sql');
	my $q = $app->query();
	my $om = $app->param('om');
	
	my $account = $q->{'__account'};
	my $domain;
	$account =~ /\^(.*)$/;
	$domain = $1;
	my $with_account = $q->param('trade_with');
	$with_account .= '^'.$domain if $with_account !~ /\^/;

	my @errors;
	my $spec = {
		'amount' => -$q->param('trade_amount'),
		'description' => $q->param('trade_for'),
		'tax-status' => $q->param('trade_tax_status'),
	};
	my $currency = $q->param('trade_currency');
	croak (q#that's not a currency this account is a member of#) if !exists($q->{'__my_currencies'}->{$currency});
	$q->{'__currency'} = $currency;
	my $t = time;
	my $s = $om->record_trade(
		'datetime' => $t,
		'transaction_id' => $q->param('transaction_id'),
		'account' => $account,
		'with' => $with_account,
		'currency' =>  $currency,
		'specification' => $spec
		);

	if ($s == 0) {
		push (@errors,qq#there was a problem recording your transaction ($om->{'error'})#);
	}

	if (@errors) {
		$self->addTemplatePairs('trading_error' => '<span class="errortext">'.join(',',@errors).'</span>');
	}
	$q->delete('transaction_id','trade_with','trade_amount','trade_for');
	return $self->show;				
}


1;