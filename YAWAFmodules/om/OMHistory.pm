#-------------------------------------------------------------------------------
# OMHistory.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OMHistory;

use strict;
use base 'PAGE::Form';
use OMUtils;
use Carp;
use PAGE::Pagination;
use PAGE::Feed;

sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;

	my $q = $app->query();
	
	my $act_id = OMUtils::GetAccountIDfromCookie($app,$q);
	$self->OMUtils::AddAccountSelector($app,$q,$act_id);

	$self->addTemplatePairs('act' => $act_id);
	
	$q->{'__account'} = $act_id;

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
		my $offset = $q->param("_n");
		my $default_items_per_page = $q->param("_i")?$q->param("_i"):25;

		my %filter = ('limit' => $default_items_per_page,'offset' => $offset);
		my ($h,$total_count) = $om->trade_history('account' => $account,'filter' => \%filter);

		my @history;
		my $tz = $app->getUserTimeZone;
		my $is_feed = $q->param('feed');
		foreach (@$h) {
			my $r = {
				'trade_id'=>$_->{'transaction_id'},
				'trade_date'=>$is_feed?PAGE::Feed::dateConvert($_->{'created'}):$app->convertUnixTimeToTimeZoneTime($_->{'created'},$tz),
				'trade_with'=>$_->{'with_account'},
				'trade_currency'=>$_->{'currency'},
				'trade_amount'=>$_->{'transaction'}->{'amount'},
				'trade_for'=>$_->{'transaction'}->{'description'},
				'trade_tax'=>$_->{'transaction'}->{'tax-status'}
				};
				foreach my $f (qw(trade_amount trade_currency trade_for)) {
					$r->{$f} = $q->escapeHTML($r->{$f});
				}
			push(@history, $r);
		}

		if (defined @history) {
			if ($is_feed) {
				$self->{'charset'} = 'utf-8';
				$self->{'MIME_type'} = 'application/rss+xml';
				$self->{'tmpl_file_name'} = 'history_feed.html';
				$self->addTemplatePairs('last_trade_date' => $history[0]->{'trade_date'}) ;
			} else {
				PAGE::Pagination::Add($self,$default_items_per_page,$offset,$total_count);
			}
			$self->addTemplatePairs('history' => \@history) ;
		}
	}

	$self->SUPER::show;
}

1;