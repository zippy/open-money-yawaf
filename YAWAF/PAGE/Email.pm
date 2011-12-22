#-------------------------------------------------------------------------------
# PAGE::Email.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package PAGE::Email;

use strict;

use base 'PAGE::Form';
use sendmail;
require 'logEvents.pl';

sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;
	my $q = $app->query();

	$self->SUPER::setup($page_name,$app);
		
	if ($q->param('m') ne 'submit') {
		$self->prepareFields($app,'from');
		$self->prepareFields($app,'to');
	}
}

#load the data for the fields from the appropriate source
sub loadFields {
	my $self = shift;
	my $app = shift;
	my $type = shift;

	my $q = $app->query();
	my $sql = $app->param('sql');
	my $p = $self->{'params'};

	my $spec = $p->{$type};
	my $source = $spec->{'source'};
	my %data;
	my $fields = $spec->{'fields'};
	if ($source eq 'curUser') {
		my $recordP = $app->param('user_info');
		foreach (@$fields) {
			$data{$_} =  $recordP->{$_};
		}
	}
	elsif ($source eq 'query') {
		foreach (@$fields) {
			$data{$_} =  $q->param($_);
		}
	}
	elsif ($source eq 'spec') {
		foreach (@$fields) {
			$data{$_} =  $spec->{$_};
		}
	}
	elsif ($source eq 'queryid') {
		my $uid;
		if ($spec->{'idIsUserID'}) {
			$uid = $app->getUserID;
		}
		else {
			$uid = int($q->param('id'));
			$self->addTemplatePairs('id',$uid);
		}
		if ($uid != 0) {
			my $where = 'id = '.$uid;
			$where .= ' and '.$spec->{'where'} if exists $spec->{'where'};
			my $rP = $sql->GetRecord($spec->{'table'},$where,@$fields);
			if (defined $rP) {
				# use the keys of rP instead of @fields so that we can have compound SQL fields
				# but still return simple key names (i.e. concat(fname,' ',lname) as name )
				foreach (keys %$rP) {
					$data{$_} =  $rP->{$_};
				}
			}
		}
	}
	return \%data;
}

# when we have the field data, put it in the query or the template as specified
sub prepareFields
{
	my $self = shift;
	my $app = shift;
	my $type = shift;
	my $p = $self->{'params'};
	my $q = $app->query();

	my $dataP = $self->loadFields($app,$type);
	
	my $spec = $p->{$type};
	my $addToPage = $spec->{'addToPage'};
	if (defined $addToPage) {
		my $f = (ref($addToPage) eq 'ARRAY')?$addToPage:$spec->{'fields'};
		foreach (@$f) {
			$self->addTemplatePairs($type.'_'.$_,$dataP->{$_});
		}
	}
	my $addToQuery = $spec->{'addToQuery'};
	if (defined $addToQuery) {
		my $f = (ref($addToQuery) eq 'ARRAY')?$addToQuery:$spec->{'fields'};
		foreach (@$f) {
			$q->param($type.'_'.$_,$dataP->{$_});
		}
	}
}

# if the data was supposed to go into a querry we get if from there
# else we get it from loadFields
sub getFields
{
	my $self = shift;
	my $app = shift;
	my $type = shift;
	my $p = $self->{'params'};
	my $q = $app->query();

	my $spec = $p->{$type};
	return undef if !defined($spec);
	
	my $dataP = $self->loadFields($app,$type);
	my $addToQuery = $spec->{'addToQuery'};
	if (defined $addToQuery) {
		my $f = (ref($addToQuery) eq 'ARRAY')?$addToQuery:$spec->{'fields'};
		foreach (@$f) {
			$dataP->{$_} = $q->param($type.'_'.$_);
		}
	}
	return $dataP;
}


sub doSubmit
{
	my $self = shift;

	my $sql = $self->param('sql');
	my $app = $self->param('app');
	my $q = $app->query();
	my $p = $self->{'params'};

	my $to = $self->getFields($app,'to');
	my $from = $self->getFields($app,'from');
	my $cc = $self->getFields($app,'cc');
	
	require HTML::Template;
	my $tmpl = HTML::Template->new_file($self->page_name.'.email', 'path', [$app->tmpl_path()]);
	my @recordFields;

	foreach (keys %$from) {
		push @recordFields,'from_'.$_,$from->{$_};
	}
	foreach (keys %$to) {
		push @recordFields,'to_'.$_,$to->{$_};
	}
	if (defined($cc)) {
		foreach (keys %$cc) {
			push @recordFields,'cc_'.$_,$cc->{$_};
		}
	}
	
	foreach (@{$p->{'fields'}}) {
		push @recordFields,$_,$q->param($_);
	}

	$tmpl->param(@recordFields);
	my $message = $tmpl->output;
	my $F = $from->{'email'};
	my $T = $to->{'email'};
	my @recipients;
	push @recipients,split(/,/,$T);
	if (defined $cc) {
		my $C = $cc->{'email'};
		push @recipients,split(/,/,$C) if $C ne '';
	}
	my $result  = &sendmail($message,$app->param('SMTP_SERVER'),$F,@recipients);
#	$self->addTemplatePairs('err'=> $result);
	if ($result) {
		$self->addFlagsToTemplatPairs('success');
		&main::logEvents($sql,$app->param('event_table'),'email',undef,$app->getUserID,undef,$message);
	}
	else {
		$self->addFlagsToTemplatPairs('failure');
	}
	return '';

}

1;