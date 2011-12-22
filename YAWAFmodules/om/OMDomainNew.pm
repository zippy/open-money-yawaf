#-------------------------------------------------------------------------------
# OMDomainNew.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OMDomainNew;

use strict;
use base 'PAGE::Form';
use OMUtils;

sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;

	my $r = OMUtils::AddDomainSelect($self,$app,'parent_domain','steward');
	$self->SUPER::setup($page_name,$app);
}

sub doSubmit
{
	my $self = shift;
	my $app = $self->param('app');
	my $sql = $self->param('sql');
	my $q = $app->query();
	
	my $om = $app->param('om');
	my $domain_name = $q->param('domain_name');
	my $parent_domain = $q->param('parent_domain');
	my $description = $q->param('description');

	my %s;
	foreach ('description',) {
		my $v = $q->param($_);
		if (defined $v) {
			$v = OMUtils::_unixify($v);
			$v =~ s/\n/\\n/;
			$s{$_} = $v;
		}
	}
	my $spec = \%s;

	my $om_id = $om->new_domain(
		'parent_domain' => $parent_domain,
		'name' => $domain_name,
		'specification' => $spec
		);
	if ($om_id == 0) {
		$self->addTemplatePairs('error.domain_name' => qq#<span class="errortext">the open money network was unable to create that domain ($om->{'error'})</span>#);
		return $self->show;				
	}
	else {
		my $user_id = $app->getUserID();
		my $id = $sql->InsertRecord($self->{'params'}->{'table'},{'om_domain_id' => $om_id,'user_id'=>$user_id,'class'=>'"steward"'},1);
	}
	return '';
}

1;