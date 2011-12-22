#-------------------------------------------------------------------------------
# PAGE::Account.pm
# Copyright (C) 2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package PAGE::Account;

use strict;

use base 'PAGE::Edit';
use sendmail;

sub beforeUpdate
{
	my $self = shift;
	my $id = shift;
	my $pairsP = shift;
	my $q = shift;
	my $sql = shift;
	
	my $app = $self->param('app');
	my $newPage;
	my $email = $q->param('email');
	if ($q->param('_activate') ) {
		$newPage = 'accountActivated';
	}
	elsif ($q->param('_resetpass') ) {
		$newPage = 'accountPasswordReset';
	}
	
	if ($q->param('_deletepass')) {
		$q->param('r' => 'accountPasswordDeleted');
		$pairsP->{'password'} = q*''*;
	}
	else {
		if ($q->param('_activate') ) {
			$newPage = 'accountActivated';
		}
		elsif ($q->param('_resetpass') ) {
			$newPage = 'accountPasswordReset';
		}
		
		if ($newPage ne '') {
			$q->param('r' => $newPage);
			my $pass = &generatePassword;
			$pairsP->{'password'} = $sql->Quote($pass);
			if ($email ne '') {
				my $recordP = $sql->GetRecord('account','id='.$id,'name');
				require HTML::Template;
				my $tmpl = HTML::Template->new_file($newPage.'.email', 'path', [$app->tmpl_path()]);
				$tmpl->param(
					'_url' => $q->url(),
					'from' => $app->param('SYSTEM_FROM'),
					'to' => $email,
					'password' => $pass,
					'name' => $recordP->{'name'}
					);
				&sendmail($tmpl->output,$app->param('SMTP_SERVER'),$app->param('SYSTEM_FROM'),$email);
				$self->{'returnPagePassthruValues'} = ['email' => $email];
			}
			else {
				$self->{'returnPagePassthruValues'} = ['password' => $pass];
			}
		}
	}
	return 1;
}

sub generatePassword
{
	my $pass;
	my $i = 5;
	srand (time() ^($$ +($$ << 15)));
	while ($i>0) {
		$pass .= chr(rand(26)+65);
		$i--;
	}
	return $pass;
}

1;