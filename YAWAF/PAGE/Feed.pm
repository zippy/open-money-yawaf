#-------------------------------------------------------------------------------
# Feed.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package PAGE::Feed;

use strict;
use base 'PAGE::Query';
use DateTime;

sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;

	my $q = $app->query();
	my $p = $self->{'params'};
	
	$self->{'charset'} = 'utf-8';
	$self->{'MIME_type'} = 'application/rss+xml';
	$self->addTemplatePairs(
			'title' => $p->{'title'},
			'link' =>  $p->{'link'},
		);	
	my $map = $p->{'entryFieldMap'};
	my %clean_map;
	foreach (keys %$map) {
		my $field = $map->{$_};
		$field = $1 if ($field =~ /.* as (.*)/);
		$clean_map{$_} = $field;
	}
	
	$p->{'name'}='items';
	$p->{'order'} = "$clean_map{'entry_updated'} DESC";
	my ($main_table) = split(/,/,$p->{'table'});
	my @fields = ($main_table.'.id');
	push @fields,@{$p->{'fields'}} if exists $p->{'fields'};

	foreach (keys %$map) {
		push @fields,$map->{$_};
	}
	$p->{'fields'} = \@fields;
	
	$self->SUPER::setup($page_name,$app);
	
	my $rP = $self->getTemplatePairValue($p->{'name'});

	if (defined $rP && scalar @$rP) {
		foreach my $r (@$rP) {
			foreach (keys %clean_map) {
				my $f = $clean_map{$_};
				$r->{$_} = $r->{$f},
			}
			$r->{'entry_updated'} = &dateConvert($r->{'entry_updated'});
			$r->{'entry_created'} = &dateConvert($r->{'entry_created'}) if exists $map->{'entry_created'};
			$r->{'entry_link'} =  $p->{'entry_link'};
			$r->{'entry_title'} = $q->escapeHTML($r->{'entry_title'});
			$r->{'summary'} = $q->escapeHTML($r->{'summary'});
		}
		$self->addTemplatePairs(
			'updated' => $rP->[0]->{'entry_updated'}
		);
	}
}

sub dateConvert
{
	my $time = shift;
	$time = 0 if !defined($time);
	my $d = DateTime->from_epoch( epoch => $time);
	$d->set_time_zone('UTC');
	return $d->strftime("%a, %d %b %Y %H:%M:%S %z");
#  This is a Atom date:	return $d->year.'-'.($d->month<10?'0':'').$d->month.'-'.($d->day<10?'0':'').$d->day.'T'.($d->hour<10?'0':'').$d->hour.':'.($d->minute<10?'0':'').$d->minute.':'.($d->second<10?'0':'').$d->second.'Z';
}

1;