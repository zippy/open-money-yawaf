#-------------------------------------------------------------------------------
# Field.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved  
# Author: Eric Harris-Braun <eric@harrisbraun.com>
#-------------------------------------------------------------------------------

package Field;

use strict;
use Carp;

%Field::ValidationData = (
	'required' => sub {
			my $self = shift;
			my $value = shift;
			my $param = shift;
			my $q = shift;
			my $e;
			
			my $sqltype = $self->{'sqltype'};
			my $isEmptyValue = ($value eq '' || ($sqltype eq 'date' && $value eq '0000-00-00') || ($sqltype eq 'time' && $value eq '00:00:00'));
			
#		die $value." - $param" if $self->{'name'} eq 'Book_LogPostmarkDate';
			if ($param ne '') {
				$param =~ /(.*?)=(.*)/;
				my ($k,$v) = ($1,$2);
				my @vals = $q->param($k);
				$e = ($isEmptyValue) && grep(/^$v$/,@vals);
#		die "p:$param k:$k e:$e value:$value ".join(',',@vals) if $k eq 'New_Grams';
			}
			else {
				$e = ($isEmptyValue);
			}
			return $e?'required_err':'';
		},
	'required_err' => '<FONT class="errortext">*</font> ',

	'regex' => sub {
			my $self = shift;
			my $value = shift;
			my $theRE = shift;
			return (not $value =~ /$theRE/)?'regex_err':'';
		},
	'regex_err' => '<span class="errortext">Bad text</span> ',

	'int' =>  sub {
			my $self = shift;
			my $value = shift;
			my $param = shift;
			return '' if $value eq '';
			
#			die "$value - $param" if $self->{'name'} eq 'Dem_MomAge';
			return 'int_err' if !($value =~ /^[0-9-]*$/);
			if ($param =~ /([0-9-]+):([0-9-]+)/)  {
#			die "$1 - $2" if $self->{'name'} eq 'Gestation_Est';
				if ($value < $1) {
					return 'int_err-tooSmall';
				}
				elsif ($value > $2) {
					return 'int_err-tooBig';
				}
			}
			return '';
		},
	'int_err-tooSmall' => '<span class="errortext">Number too small.</span> ',
	'int_err-tooBig' => '<span class="errortext">Number too big.</span> ',
	'int_err' => '<span class="errortext">Please use numbers only.</span> ',

	'email' => sub {
			my $self = shift;
			my $value = shift;
			return ($value ne '' && !($value =~ /.+@.+\..+/))?'email_err':'';
		},
	'email_err' => '<span class="errortext">Bad e-mail format.</span> ',

	'password' => sub {
			my $self = shift;
			my $value = shift;
			my $param = shift;
			my $q = shift;
			return ($value ne $q->param($self->{'name'}.'_confirm'))?'password_err':'';
		},	
	'password_err' => q|<span class="errortext">Password not confirmed.  Please try again.</span> |,

	'unique' => sub {
			my $self = shift;
			my $value = shift;
			my $param = shift;
			my $q = shift;
			my $page = shift;
			if ($value ne '') {
				my $sql = $page->param('sql');
				my $field = $self->{'name'};
				my $where = "$field=".$sql->Quote($value);
				$where .= " and ($self->{'where'})" if exists $self->{'where'};
#				if (exists $self->{'fieldquerysub'}) {
#					my $fqs = $self->{'fieldquerysub'};
#					foreach my $k (keys %$fqs) {
#						my $value = $q->param($k);
#						$value = ($fqs->{$k} eq 'i')?int($value):$sql->Quote($value);
#						$k = '_'.$k.'_';
#						$where =~ s/$k/$value/g;
#					}
#				}
				my $recordP = $sql->GetRecord($page->{'params'}->{'table'},$where,$field,'id');
				if (defined $recordP) {
					my $id = int($q->param('id'));
					return 'unique_err' if (lc($value) eq lc($recordP->{$field})) && ($id != $recordP->{'id'});
				}
			}
			return '';
		},
	'unique_err' => '<span class="errortext">That value already exists in the database!  Try again.</span> ',
);

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

sub buildHTML
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	my $page = shift;
	
	die 'buildHTML must be overridden';
}

sub buildHTMLnoEdit
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	my $page = shift;
	
	return $q->param($f);
}

sub isFieldValueValid
{
	my $self = shift;
	my $field = shift;
	my $q = shift;
	my $page = shift;
	
	my $validation_spec = $self->{'validation'};
	
	my $value = $self->getFieldValueFromQuery($field,$q);
	my $err;
	foreach (@$validation_spec) {
		/^([a-zA-Z]*):?(.*)/;
		my $v = $1;
		my $v_param = $2;
		my $vP = $Field::ValidationData{$v};
		next if not defined $vP;
#		die "validation subroutine for $v is undefined for field $field" if not defined $vP;
		my $err_key = &$vP($self,$value,$v_param,$q,$page);
		if ($err_key ne '') {
			my $error_html = $self->{'errorhtml'};
			if (defined $error_html && exists $error_html->{$err_key}) {
				$err = $error_html->{$err_key};
			}
			else {
				$err = $Field::ValidationData{$err_key};
			}
		}
		last if $err ne '';
	}
	return $err;
}

sub getFieldValueFromQuery
{
	my $self = shift;
	my $field = shift;
	my $q = shift;

	my $v = $q->param($field);

	if (exists $self->{'isNumeric'}) {
		$v = '' if $v !~ /[0-9]/;	
	}
	
	if (exists $self->{'queryMap'}) {
		$v = $self->{'queryMap'}->{$v};
	}
	
	return $v;
}

sub setQueryFromFieldValue
{
	my $self = shift;
	my $field = shift;
	my $q = shift;
	my $recordP = shift;

	if (exists $recordP->{$field}) {
		my $v = $recordP->{$field};
		$v = '' if !defined $v;
		$q->param($field => $v);
	}
}
1;