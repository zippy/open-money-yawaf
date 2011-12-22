#-------------------------------------------------------------------------------
# PAGE::Login.pm
# ©2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harrisbraun.com>
#-------------------------------------------------------------------------------

package PAGE::Login;

use strict;

use base 'PAGE::Form';

sub submit
{
	my $self = shift;

	my $app = $self->param('app');
	my $q = $app->query();
	
	my $session = $app->doLogin($q->param('name'),$q->param('password'));

	my $login_params = $q->param('login_params');
	if ($session eq undef) {
		$self->addTemplatePairs(
			'login_params' => $login_params,
			'badlogin' => 1);
		return $self->show();
	}
	else {
		#successfull login then pass all the login parameters to the intended command
		my @params = split (/&/,$login_params);
		$q->delete_all();
		foreach (@params) {
			/^([^=]*)=(.*)/;
			$q->param($1,$2);
#			$s .= "$1 = $2 <br>";
		}
		my $page_name = $app->yawaf_get_page_name();

		return $app->yawaf_get_page($page_name)->getBody();
	}
}

1;