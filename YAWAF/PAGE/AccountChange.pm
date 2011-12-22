#-------------------------------------------------------------------------------
# PAGE::Account.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package PAGE::AccountChange;

use strict;

use base 'PAGE::Edit';

sub beforeUpdate
{
	my $self = shift;
	my $id = shift;
	my $pairsP = shift;

	my $sql = $self->param('sql');
	my $app = $self->param('app');
	my $p = $self->{'params'};
	my $table = $p->{'table'};
	my $q = $app->query();

	my $pass = $pairsP->{'oldPass'};

	delete $pairsP->{'oldPass'};
	my $recordP = $sql->GetRecord($table,'id = '.$id.' and password = '.$pass,'id') if $q->param('oldPass') ne '';

	if (defined $recordP) {
		return 1;
	}
	else {
		$self->{'returnPagePassthruValues'} = ['name' => $pairsP->{'name'}];
		return 0;
	}
}

1;