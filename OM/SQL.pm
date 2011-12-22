#-------------------------------------------------------------------------------
# OM::SQL.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OM::SQL;

use strict;
use Carp;
use base 'OM';

sub do_new_account {
	my $self = shift;
	my $params = shift;

	my $table = $self->{'account_table'};
	my $sql = $self->{'sql'};
	
	my %recs = ('created'=>'NOW()');
	$recs{'access_control'} = $sql->Quote($params->{'access_control'}) if exists $params->{'access_control'};
	return $sql->InsertRecord($table,\%recs,1);
}

sub do_trade_record {
	my $self = shift;
	my $params = shift;

	my $account_id = $params->{'account'};
	my $with_account_id = $params->{'with'};
	my $currency_id = $params->{'currency'};
	my $datetime = $params->{'datetime'};
	my $spec = $params->{'specification'};
	my $spec_text = _encodeSpec($spec);

	my $sql = $self->{'sql'};
	my $table = $self->{'ledger_table'};
	my %recs = (
		'created'=>"from_unixtime($datetime)",
		'account_id'=>$account_id,
		'with_account_id'=>$with_account_id,
		'currency_id'=>$currency_id,
		'transaction'=>$sql->Quote($spec_text)
		);
	
	#we should be locking the summary at this point so there aren't any collisions
	my $record_id = $sql->InsertRecord($table,\%recs,1);
	if ($record_id != 0) {
		my $r = $sql->GetRecord($self->{'summary_table'},"account_id=$account_id and currency_id=$currency_id",'summary','id');
		my $summary;
		if (defined $r) {
			$summary = _decodeSummary($r->{'summary'});
		}
		$summary->{'balance'}+=$spec->{'amount'};
		$summary->{'volume'}+=abs($spec->{'amount'});
		$summary->{'last'} = $datetime;
		my %sumrec = ('summary'=>_encodeSummary($summary));
		if (defined $r) {
			$sql->UpdateRecords($self->{'summary_table'},\%sumrec,"id=$r->{'id'}");
		}
		else {
			$sumrec{'account_id'} = $account_id;
			$sumrec{'currency_id'} = $currency_id;
			my $summary_id = $sql->InsertRecord($self->{'summary_table'},\%sumrec);
		}
	}
	return $record_id;

}

sub _filter2where
{
	my $filter = shift;
	my $whereP = shift;
	my $limitP = shift;
	if (exists $filter->{'currencies'}) {
		my @w;
		foreach (@{$filter->{'currencies'}}) {
			push @w,"currency_id = $_";
		}
		$$whereP = "($$whereP) and (".join(' or ',@w).")";
	}
	if (exists $filter->{'limit'}) {
		my @w;
		$$limitP = $filter->{'limit'};
	}
}

sub do_trade_summary {
	my $self = shift;
	my $params = shift;
	
	my $account_id = $params->{'account'};
	my $where = "account_id=$account_id";
	
	my $filter = $params->{'filter'};
	if ($filter) {
		_filter2where($filter,\$where);
	}
	
	my $sql = $self->{'sql'};
	my $table = $self->{'summary_table'};
	my $r = $sql->GetRecords($table,$where,['summary','currency_id']);
	foreach (@$r) {
		$_->{'summary'} = _decodeSummary($_->{'summary'});
	}
	return $r;
}

sub do_trade_history {
	my $self = shift;
	my $params = shift;
	
	my $account_id = $params->{'account'};
	my $where = "account_id=$account_id";
	my $limit;
	
	my $filter = $params->{'filter'};
	if ($filter) {
		_filter2where($filter,\$where,\$limit);
	}

	my $sql = $self->{'sql'};
	my $table = $self->{'ledger_table'};
	my $r = $sql->GetRecords($table,$where,['created','with_account_id','currency_id','transaction'],'created desc',undef,undef,$limit);
	foreach (@$r) {
		$_->{'transaction'} = _decodeSpec($_->{'transaction'});
	}
	return $r;
}


sub do_new_currency {
	my $self = shift;
	my $params = shift;

	my $spec = _encodeSpec( $params->{'specification'});

	my $table = $self->{'currency_table'};
	my $sql = $self->{'sql'};	
	my %recs = ('created'=>'NOW()','specification' => $sql->Quote($spec));
	$recs{'access_control'} = $sql->Quote($params->{'access_control'}) if exists $params->{'access_control'};
	return $sql->InsertRecord($table,\%recs,1);
}

sub do_join_currency {
	my $self = shift;
	my $params = shift;
	
#	$self->{'error'} = 'Function not yet implemented';
#	return 0;	
	my $table = $self->{'currency_accounts_table'};
	my $sql = $self->{'sql'};
	my %ids;
	my $currency_id = $params->{'id'};
	foreach (@{$params->{'accounts'}}) {
		if (!$sql->GetCount($table,"account_id = $_ and currency_id=$currency_id")) {
			my %recs = ('created'=>'NOW()','account_id' => $_, 'currency_id'=> $currency_id);
			$ids{$_} = $sql->InsertRecord($table,\%recs,1);
		}
	}
	return \%ids;
}

#-------
sub _encodeSpec
{
	my $spec = shift;
	my $spec_text;
	while (my($k,$v) = each(%$spec)) {
		$spec_text .= "$k:$v\n";
	}
	return $spec_text;
}
sub _decodeSpec
{
	my $text = shift;
	my %s;
	my @l = split(/\n/,$text);
	foreach (@l) {
		/([^:]*):(.*)/;
		$s{$1}=$2;
	}
	return \%s;
}

sub _decodeSummary
{
	my $s = shift;
	my ($b,$v,$l);
 	if ($s =~ /(.*)~(.*)~(.*)/) {
 		($b,$v,$l) = ($1,$2,$3);
 	}
 	else {
 		($b,$v,$l) = (0,0,undef);
 	}
 	return {'balance'=>$b,'volume'=>$v,'last'=>$l};
}
sub _encodeSummary
{
	my $s = shift;
	return "$s->{'balance'}~$s->{'volume'}~$s->{'last'}";
}

1;