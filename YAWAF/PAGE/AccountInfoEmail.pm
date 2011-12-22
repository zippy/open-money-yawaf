#-------------------------------------------------------------------------------
# PAGE::AccountInfoEmail.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package PAGE::AccountInfoEmail;

use strict;

use base 'PAGE::Form';
use sendmail;

sub doSubmit
{
	my $self = shift;

	my $sql = $self->param('sql');
	my $app = $self->param('app');
	my $q = $app->query();
	my $p = $self->{'params'};
	my $table = $p->{'table'};
	my $fields = $p->{'efields'};
	my $where = $p->{'where'};
	
	my $email = $q->param('email');
	my $records = $sql->GetRecords($table,'email = '.$sql->Quote($email),$fields) if $email ne '';
	
	if (@$records) {
		require HTML::Template;
		my $tmpl = HTML::Template->new_file($self->page_name.'.email', 'path', [$app->tmpl_path()]);
		my @f = (
			'_url' => $q->url(),
			'from'=>$app->param('SYSTEM_FROM'),
			'to' => $email,
			'accounts' => $records
		);
		push (@f,'multiple_accounts',1) if @$records > 1;
		$tmpl->param(@f);
		&sendmail($tmpl->output,$app->param('SMTP_SERVER'),$app->param('SYSTEM_FROM'),$email);
		$self->addFlagsToTemplatPairs('success');
		return '';
	}
	else {
		$self->addFlagsToTemplatPairs('failure');
		return '';
	}

}

1;