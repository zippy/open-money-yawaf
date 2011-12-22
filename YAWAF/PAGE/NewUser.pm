#-------------------------------------------------------------------------------
# PAGE::NewUser.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package PAGE::NewUser;

use strict;
use base 'PAGE::Edit';
use sendmail;

sub beforeCreate
{
	my $self = shift;
	my $pairsP = shift;
	my $q = shift;
	my $sql = $self->param('sql');
	
	my $password = &generatePassword();
	$pairsP->{'password'} = $sql->Quote($password);
	
	$self->{'__PASSWORD'} = $password;
	return 1;
}

sub afterCreate
{
	my $self = shift;
	my $id = shift;
	my $pairsP = shift;
	my $q = shift;
	my $sql = shift;


	my $account_name = $pairsP->{'name'};
	$account_name =~ /'(.*)'/;
	$account_name = $1;
	my $email = $pairsP->{'email'};
	$email =~ /'(.*)'/;
	$email = $1;

	my $app = $self->param('app');
	my $err;
	
	$err = $self->doNewUser($app,$sql,$id,$account_name,$email,$pairsP);
	if ($err ne '') {
		$self->addTemplatePairs('error' => $err);
		$self->addFlagsToTemplatPairs('failure');
	}
	else {
		$self->addFlagsToTemplatPairs('success');
		$self->sendEmail($app,$q,$email,$self->page_name.'.email',
			['username' => $account_name,
			'password' => $self->{'__PASSWORD'}
			]
		);
		$self->addTemplatePairs('password_email',$email);
		my $notify = $app->param('notify_of_new_user');
		if ($notify ne '') {
			my $name;
			$pairsP->{'fname'} =~ /'(.*)'/;
			$name = $1;
			$pairsP->{'lname'} =~ /'(.*)'/;
			$name .= ' '.$1;
		
			$self->sendEmail($app,$q,$notify,$self->page_name.'-admin.email',
				['user_email' => $email,
				'name' => $name,
				'username' => $account_name
				]
				);
		}
	}
	
}

sub doNewUser {
	my $self = shift;
#	my ($app,$sql,$id,$account_name,$email,$pairsP) = @_;
#OVERRIDE ME!
	return '';
}

sub sendEmail
{
	my $self = shift;
	my $app = shift;
	my $q = shift;
	my $to = shift;
	my $tmpl_file = shift;
	my $fields = shift;
	
	require HTML::Template;

	push (@$fields,'to' => $to,'from'=>$app->param('SYSTEM_FROM'),'_url' => $q->url());
	my @paths;
	push (@paths,$app->tmpl_path());
	if (exists $self->{'tmpl_params'}) {
		push (@paths,@{$self->{'tmpl_params'}->{'path'}});
	}
	my $tmpl = HTML::Template->new_file($tmpl_file, 'path', \@paths);
	$tmpl->param(@$fields);
	return &sendmail($tmpl->output,$app->param('SMTP_SERVER'),$app->param('SYSTEM_FROM'),$to);
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