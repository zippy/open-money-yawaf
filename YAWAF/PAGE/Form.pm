#-------------------------------------------------------------------------------
# PAGE::Form.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package PAGE::Form;

use strict;
use Field;

use base 'PAGE';

sub _initialize
{
	my $self = shift;
	$self->{'methods'} = {'show'=>1,'submit'=>1};
}

sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;
	$self->SUPER::setup($page_name,$app);

	my $q = $app->query();
	my $sql = $app->param('sql');
	$self->param('sql' => $sql);

	my $is_submit = ($self->param('m') eq 'submit');

	my $p = $self->{'params'};
	
	$self->specErrorDie($page_name,'params undefined') if not defined($p);

	my $ticketSpec = $self->getTicketSpec();
	
	if (not $is_submit) {
		if (defined $ticketSpec) {
			my $timeout = (exists $ticketSpec->{'timeout'})?$ticketSpec->{'timeout'}:60*60*24;
			my $session = Session->new($sql,undef,time,$timeout);
			$self->addTemplatePairs('_ticket' => $session->{'id'});
		}
	}
	else {
		my $errors;
		$errors = $self->doValidation();
		if ($errors == 0) {

			if (defined $ticketSpec) {
				my $session;
				
				if ($q->param('_ticket') ne '') {
					$session = Session->new($sql,$q->param('_ticket'));
				}
				
				if (not defined $session) {
					$self->param('m' => 'show');
					$self->page_name($ticketSpec->{'badTicketPage'});
					return;
				}
				else {
					 $session->delete;
				}
			}

			my %pairs;
			if (exists $p->{'fieldPresets'}) {
				%pairs = %{$p->{'fieldPresets'}};
			}
			
			my $fP = $self->getFieldsToLoadFromQuery;
			$self->queryToHash($q,$p->{'fieldspec'},\%pairs,$fP);
			$self->param('formPairs' => \%pairs);
		}
		else {
			$self->addTemplatePairs('_errorCount' => $errors);
			if (defined $ticketSpec) {
				$self->addTemplatePairs('_ticket' => $q->param('_ticket'));
			}
			$self->param('m' => 'show');
		}
	}
}

sub getFieldsToLoadFromQuery {
	my $self = shift;
	my $p = $self->{'params'};
	return $p->{'fields'};
}

sub show {
	my $self = shift;
	my $app = $self->param('app');
	my $p = $self->{'params'};
	my $q = $app->query();

	$self->addHTMLformItems($p->{'fields'},$p->{'fieldspec'},$q);
	return $self->SUPER::show();
	
}

sub submit
{
	my $self = shift;
	
	my $return_val = $self->doSubmit();

	return $return_val if $return_val ne '';
	
	return $self->showReturnPage();
}

sub doSubmit
{
	my $self = shift;
	#override me!	
}

sub showReturnPage
{
	my $self = shift;

	my $app = $self->param('app');
	my $q = $app->query();
	my $p = $self->{'params'};
	
	if (exists $p->{'reloadAccountInfoOnReturn'}) {
		my $recordP = $app->getUserRecord($app->getUserID);
		if (defined $recordP) {
			$app->setUserInfo($recordP);
			$app->yawaf_set_account_info($self,$app->param('session'));
		}
	}

	return $self->show if exists $p->{'selfreturnpage'};

	my $page_name = $q->param('r');
	if ($q->param('rm') ne '') {
		$q->param('m' => $q->param('rm'));
	}
	elsif (exists($p->{'returnmethod'})) {
		$q->param('m' => $p->{'returnmethod'});
	}
	else {
		$q->delete('m');
	}

	$page_name = $p->{'returnpage'} if $page_name eq '';
	$page_name = $app->start_page if $page_name eq '';
	my $page = $app->yawaf_get_page($page_name);

	if (exists $self->{'returnPagePassthruValues'}){
		$page->addTemplatePairs(@{$self->{'returnPagePassthruValues'}});
	}
	return $page->getBody();
}

sub doValidation
{
	my $self = shift;
	my $app = $self->param('app');
	my $q = $app->query();

	my $fieldsP = $self->getFieldsForValidation;
	my $fspecs = $self->getFieldSpecsForValidation;

	return $self->addErrorsToPage($self->_doValidation($q,$fspecs,$fieldsP));
}

sub getFieldsForValidation
{
	my $self = shift;
	my $p = $self->{'params'};
 	return $p->{'fields'};
}
 
sub getFieldSpecsForValidation
{
	my $self = shift;
	my $p = $self->{'params'};
	my $fspecs = $p->{'fieldspec'};
}


sub _doValidation
{
	my $page = shift;
	my $q = shift;
	my $fspecs = shift;
	my $fieldsP = shift;

	my %errors;

	foreach my $f (@$fieldsP) {
		my $fspec = $fspecs->{$f};
		my $err = $fspec->isFieldValueValid($f,$q,$page);
		if ($err ne '') {
			$errors{$f} = $err;
		}
	}
	return \%errors;
}

sub addErrorsToPage
{
	my $self = shift;
	my $errorsP = shift;
	my @errors = keys(%$errorsP);
	foreach (@errors) {
#	die $_.' '.$errorsP->{$_};
		$self->addErrorToPage($_,$errorsP->{$_});
	}
	return scalar @errors;
}

sub addErrorToPage
{
	my $self = shift;
	my $f = shift;
	my $err = shift;
	$self->addTemplatePairs('error.'.$f => $err);
}

sub addHTMLformItems
{
	my $self = shift;
	my $fieldsP = shift;
	my $fspecsH = shift;
	my $q = shift;

	my $hP = $self->getHTMLformItems($fieldsP,$fspecsH,$q);
	
	my $k;
	my $v;
	while (($k,$v) = each %$hP) {
		$self->addTemplatePairs($k => $v);
	}
	
}


sub getHTMLformItems
{
	my $self = shift;
	my $fieldsP = shift;
	my $fspecsH = shift;
	my $q = shift;
	
	my %h;
	
	my $f;
	
	foreach $f (@$fieldsP) {
		my $fspec = $fspecsH->{$f};
		if (defined($fspec)) {
		my $fv = $fspec->buildHTML($f,$q,$self);
			if ($fv ne '') {
				$h{$f} = $fv;
			}
		}
	}
	return \%h;
}

sub getParamValuesFromHash
{
	my $hashP = shift;
	my $listP = shift;
	foreach (@_) {
		push (@$listP,'-'.$_,$hashP->{$_}) if exists($hashP->{$_});
	}
}

sub queryToHash {
	my $self = shift;
	my $q = shift;
	my $fspecs = shift;
	my $pairs = shift;
	my $fieldsP = shift;


	my @fields;
	my $doMapFieldNames;
	
	if (ref($fieldsP) eq 'HASH') {
		@fields = keys %$fieldsP;
		$doMapFieldNames = 1;
	}
	elsif (ref($fieldsP) eq 'ARRAY') {
		@fields = @$fieldsP;
	}
	
	
	my $sql = $self->param('sql');
	my $f;
	foreach $f (@fields) {
		my $fspec = $fspecs->{$f};
		my $v = $fspec->getFieldValueFromQuery($f,$q);
		
		# don't set the pair if this was a no load value that didn't get any value
		# entered by the user.
		next if $v eq '' && exists $fspec->{'noload'};
	
		my $nOk = exists $fspec->{'sqlNullOK'};
		my $t = $fspec->{'sqltype'};
		if ($t eq 'int') {
			if ($v =~ /^-*[0-9.]+$/) {
				$v = $v;
			}
			else {
				$v = $nOk?'NULL':0;
			}
		}
		else {
			if ($nOk && $t eq 'date' && $v eq '0000-00-00') {
				$v = 'NULL';
			}
			elsif ($nOk && $t eq 'time' && $v eq '00:00:00') {
				$v = 'NULL';
			}
			else {
				if (defined $sql) {
					$v = $sql->Quote($v);
				}
			}
		}

		if ($doMapFieldNames) {
			$pairs->{$fieldsP->{$f}} = $v;			
		}
		else {
			$pairs->{$f} = $v;
		}
	}
}

sub getTicketSpec
{
	my $self = shift;
	my $p = $self->{'params'};
	if (exists $p->{'ticket'}) {
		return $p->{'ticket'};
	}
	return undef;
}

1;