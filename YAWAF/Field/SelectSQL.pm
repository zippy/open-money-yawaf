#-------------------------------------------------------------------------------
# Field::SelectSQL.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package Field::SelectSQL;

use strict;

use base 'Field';


sub buildHTML
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	my $page = shift;

	my $sqlSel = $self->{'sqlselect'};
	my $name = $self->{'name'};
	die 'sqlselect not defined for field '.$name if not defined $sqlSel;
	my ($fv,$count) = $sqlSel->makeSelect($name,$page->param('sql'),$q,$q->param($name),$self->{'querrySubs'});
	return $fv;
}

sub buildHTMLnoEdit
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	my $page = shift;
	
	my $sqlSel = $self->{'sqlselect'};
	my $name = $self->{'name'};
	die 'sqlSelect not defined for field'.$name if not defined $sqlSel;
	my ($fv,$count) = $sqlSel->makeSelect($name,$page->param('sql'),$q,$q->param($name),$self->{'querrySubs'},1);
	return '' if $fv eq '-';
	return $fv;
}

1;