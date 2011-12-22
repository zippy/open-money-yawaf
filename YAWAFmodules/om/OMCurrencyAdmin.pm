#-------------------------------------------------------------------------------
# OMCurrencyAdmin.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OMCurrencyAdmin;

use strict;
use base 'PAGE::Form';
use OMUtils;
use PAGE::Pagination;

sub _initialize
{
	my $self = shift;
	$self->SUPER::_initialize;

	$self->{'methods'}->{'recalc_sum'} = 1;	
}


sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;

	my $m = OMUtils::SetupUserOwnedCurrencies($self,$app);
	
	my $q = $app->query();

	my @currencies;
	my %currency_labels;
	my $currency = $q->param('admin_currency');

	my $found;
	foreach (@$m) {
		my $id = $_->{'currency'};
		push (@currencies,$id);
		$currency_labels{$id} = $_->{'currency_name'};
		$found = 1 if ($id eq $currency);
	}

	if (!$found && @$m) {
		$currency = $m->[0]->{'currency'};
	}
	
	$q->{'__currency'} = $currency;
	$q->{'__my_currencies'} = \%currency_labels;
	$self->addTemplatePairs(
		'currency_name' => $currency_labels{$currency},
		'currency' => $currency
		);

	if (@currencies) {
		$self->{'params'}->{'fieldspec'}->{'admin_currency'} =
		Field::Select->new(
			'name' => 'admin_currency',
			'values' => \@currencies,
#			'labels' => \%currency_labels,
			'validation' => ['required'],
			'onchange' => q#document.admin.m.value='show';document.admin.submit()#,
			);
		push (@{$self->{'params'}->{'fields'}},'admin_currency');
	}


	if ($q->param('action') eq 'reverse') {
		$self->{'params'}->{'fieldspec'}->{'reverse_tx_id'}->{'validation'} = ['required'];
	}
	elsif ($q->param('action') eq 'trade') {
		foreach ('trade_for','trade_from','trade_to','trade_amount','trade_tax_status') {
			$self->{'params'}->{'fieldspec'}->{$_}->{'validation'} = ['required'];
		}
	}
	
	$self->SUPER::setup($page_name,$app);
}

sub recalc_sum
{
	my $self = shift;
	my $app = $self->param('app');
	my $om = $app->param('om');
	my $sql = $self->{'sql'};
	my $r = $sql->GetRecords('om_summary','',['account_id','currency','id']);
	foreach my $s (@$r) {
		my $ledgerP = $sql->GetRecords('om_ledger',"$s->{'account_id'} = account_id and currency=".$sql->Quote($s->{'currency'}),['transaction','created'],'created');
		my %summary;
		if (scalar(@$ledgerP)) {
			foreach my $l (@$ledgerP) {
				my $t = OM::Service::_decodeSpec($l->{'transaction'});
				$summary{'balance'}+=$t->{'amount'};
				$summary{'volume'}+=abs($t->{'amount'});
			}
			$summary{'last'} = $ledgerP->[scalar(@$ledgerP)-1]->{'created'};
		}
		else {
			$summary{'balance'} = 0;
			$summary{'volume'} = 0;
		}
		my %sumrec = ('summary'=> &OM::Service::_encodeSummary(\%summary));
		$sql->UpdateRecords('om_summary',\%sumrec,"id=$s->{'id'}");
	}
	return $self->show;
}

sub show
{
	my $self = shift;
	my $app = $self->param('app');
	my $om = $app->param('om');
	my $q = $app->query();

	my $currency = $q->{'__currency'};

	my $offset = $q->param("_n");
	my $default_items_per_page = $q->param("_i")?$q->param("_i"):25;

	my %filter = ('limit' => $default_items_per_page,'offset' => $offset);

	my $stats = $om->get_currency_stats(
		'currency'=>$currency,
		'filter'=>\%filter
		);

	my $h = $stats->{'history'};
	my $total_count = $stats->{'transaction_count'};
	
	my %account_names;
	my $accounts = $stats->{'accounts'};
	foreach (@$accounts) {
		my $id = $_->{'account_id'};
		my $an = $om->_account_id2name($id);
		$account_names{$id} = $an;
		$_->{'account'} = $an;
		$_->{'last'}=$app->convertUnixTimeToUserTime($_->{'last'})
	}
   my @accounts = sort { $a->{'account'} cmp $b->{'account'} } @$accounts;
	
	my @history;
	my $tz = $app->getUserTimeZone;
	foreach (@$h) {
		my $r = {
			'trade_id'=>$_->{'transaction_id'},
			'trade_date'=>$app->convertUnixTimeToTimeZoneTime($_->{'created'},$tz),
			'trade_from'=> $account_names{$_->{'account_id'}},
			'trade_to'=>$_->{'with_account'},
			'trade_amount'=>$_->{'transaction'}->{'amount'},
			'trade_for'=>$_->{'transaction'}->{'description'},
			'trade_tax'=>$_->{'transaction'}->{'tax-status'}
			};
		foreach my $f (qw(trade_amount trade_currency trade_for)) {
			$r->{$f} = $q->escapeHTML($r->{$f});
		}
		push(@history, $r);
	}
	PAGE::Pagination::Add($self,$default_items_per_page,$offset,$total_count);

	$self->addTemplatePairs(
		'system_volume_text'=> _convertToText($stats->{'unit'},$stats->{'volume'}),
		'system_transactions'=> $total_count,
		'history'=> \@history,
		'accounts'=> \@accounts,
		'transaction_id' => time
		);

	$self->SUPER::show;
}

# this should all really be defined inside the currency....
sub _convertToText 
{
	my $unit = shift;
	my $amt = shift;
	
	my %before = ('USD'=>1,'EUR'=>1, 'CAD'=>1,'AUD'=>1,'NZD'=>1,'GBP'=>1,'YEN'=>1,'other'=>1);
	my %symbol = (
		'USD'=>'$', 'EUR'=>'&euro;', 
		'CAD'=>'$','AUD'=>'$','NZD'=>'$',
		'GBP'=>'&pound;','MXP'=>'p','YEN'=>'&yen;','CHY'=>'Yuan',
		'other'=>'&curren;',
		'kwh'=>'kwh', 'T-h'=>'hours', 'T-m'=>'minutes');
	
	$amt = 0 if !defined($amt);
#	$amt = join(',',reverse map ($_ = scalar reverse,unpack("(A3)*",scalar reverse $amt)));
	$amt = commify($amt);
	my $s = $symbol{$unit};
	return ($before{$unit})?"$s$amt":"$amt $s";
}

sub commify {
   local $_  = shift;
   1 while s/^([-+]?\d+)(\d{3})/$1,$2/;
   return $_;
   }


sub doSubmit
{
	my $self = shift;
	my $app = $self->param('app');
	my $sql = $self->param('sql');
	my $q = $app->query();
	my $om = $app->param('om');
	
	if ($q->param('action') eq 'trade') {
		my $account = $q->param('trade_from');
		my $domain;
		$account =~ /\^(.*)$/;
		$domain = $1;
		my $with_account = $q->param('trade_to');
		$with_account .= '^'.$domain if $with_account !~ /\^/;
	
		my @errors;
		my $spec = {
			'amount' => -$q->param('trade_amount'),
			'description' => $q->param('trade_for'),
			'tax-status' => $q->param('trade_tax_status'),
		};
		my $currency = $q->{'__currency'};
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
		else {
			$self->addTemplatePairs(
				'trade_recorded' =>$account,
				't_from' =>$account,
				't_to' =>$with_account,
				't_amt' =>$q->param('trade_amount'),
				);
		}
	
		if (@errors) {
			$self->addTemplatePairs('trading_error' => '<span class="errortext">'.join(',',@errors).'</span>');
		}
		$q->delete('transaction_id','trade_from','trade_to','trade_amount','trade_for');
	}
	elsif ($q->param('action') eq 'reverse') {
		my $currency = $q->{'__currency'};
		my $id = $q->param('reverse_tx_id');
		my $result = $om->reverse_trade('currency'=>$currency,'datetime'=>time,'transaction_id'=>$id,'comment'=>$q->param('reverse_tx_comment'));
		if (!defined($result)) {
			$self->addTemplatePairs('error.reverse_tx_id' => '<span class="errortext">'.qq#the open money network did not allow you to reverse that transaction ($om->{'error'})#.'</span>');
			return $self->show;				
		}
		my $cl = $q->{'__my_currencies'};
		$q->delete_all();
		$q->{'__currency'} = $currency;
		$q->{'__my_currencies'} = $cl;
		$self->addTemplatePairs('transaction_reversed'=>1,'transaction_id'=>$id);
	}
	return $self->show;				
}

1;