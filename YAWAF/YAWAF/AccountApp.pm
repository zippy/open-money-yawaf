#-------------------------------------------------------------------------------
# YAWAF::AccountApp.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package YAWAF::AccountApp;

use strict;
use base 'YAWAF';
use Session;
use SQL;
require 'logEvents.pl';
use DateTime;

sub session_timeout {
	my $self = shift;
	return $self->_scalar_param('SESSION_TIMEOUT',60*60*24*7,undef,@_);
}
sub login_fields {
	my $self = shift;
	return $self->_scalar_param('LOGIN_FIELDS',['id','name','email','password','fname','lname','privFlags','prefFlags','prefStartPage','prefLanguage','timeZone'],undef,@_);
}
sub login_fields_for_tmpl {
	my $self = shift;
	return $self->_scalar_param('LOGIN_FIELDS_FOR_TMPL',['id','name','fname','lname','email'],undef,@_);
}
sub default_time_zone {
	my $self = shift;
	return $self->_scalar_param('DEFAULT_TIME_ZONE','America/New_York',undef,@_);
}

sub yawaf_init
{
	my $self = shift;
	my $rprops = shift;

	# Set session_timeout()
	if (exists($rprops->{SESSION_TIMEOUT})) {
		$self->session_timeout($rprops->{SESSION_TIMEOUT});
	}
	# Set login_fields()
	if (exists($rprops->{LOGIN_FIELDS})) {
		$self->login_fields($rprops->{LOGIN_FIELDS});
	}
	# Set login_fields_for_tmpl()
	if (exists($rprops->{LOGIN_FIELDS_FOR_TMPL})) {
		$self->login_fields_for_tmpl($rprops->{LOGIN_FIELDS_FOR_TMPL});
	}

}

sub no_login_page
{
	my $self = shift;
	my $page_name = shift;
	my $module_name = shift;
	if ($module_name eq '') {
		return exists $self->param('noLoginPages')->{$page_name};
	}
	return ($self->module_directory()."::$module_name")->is_no_login_page($page_name);
}

sub yawaf_get_page
{
	my $self = shift;
	my $full_page_name = shift;
	my $q = $self->query();
	my $saveparams;
	my $session_id = $q->cookie('session');

	my ($page_name,$module) = $self->SUPER::yawaf_setup_module($full_page_name);

	unless ($page_name eq 'login' || $page_name eq 'logout' || (defined $self->param('session')) || $self->validateSession($session_id) || $self->no_login_page($page_name,$module)) {
		$page_name = 'login';
		$module = '';
		$saveparams = 1;
	}

	unless ($self->checkPrivs($page_name)) {
		$q->delete_all;
		$page_name = 'noPrivs';
	}
	
	my $user_id = $self->getUserID;
	if ($user_id > 0) {
		my @p = $q->param;
		my $c;
		foreach (@p) {
			$c .= "$_=".$q->param($_).'&';
		}
		chop $c;
		&main::logEvents($self->param('sql'),$self->param('event_table'),'access',$page_name,$user_id,undef,join ('',$c)) ;
	}

	my $page = $self->SUPER::yawaf_setup_page($page_name,$module);
	
	$self->doLogout if $page_name eq 'logout';
	
	
	# add in all the account information into the page template
	my $session = $self->param('session');
	if (defined $session) {
		$self->yawaf_set_account_info($page,$session);
	}
	if ($saveparams) {
		$page->addTemplatePairs('login_params' => &_encodeQueryParams($q));
		# the session nust have timed out so set a flag for the login template to be able to say it
		$page->addFlagsToTemplatPairs('sessionTimeout') if $session_id ne '';
	}
	return $page;	
}

sub start_page {
	my $self = shift;
	
	my $ui = $self->param('user_info');
	return $ui->{'prefStartPage'} if (defined $ui && $ui->{'prefStartPage'} ne '');
	
	return $self->SUPER::start_page(@_);
}

sub yawaf_set_account_info
{
	my $self = shift;
	my $page = shift;
	my $session = shift;
	
	my @privs = @{$self->param('user_privs')};
	$page->addFlagsToTemplatPairs(map $_ = "user_priv_$_",@privs);
	my @prefs = @{$self->param('user_prefs')};
	$page->addFlagsToTemplatPairs(map $_ = "user_pref_$_",@prefs);

	my $recordP = $self->param('user_info');

#	$page->addFlagsToTemplatPairs('account_type_'.$recordP->{'type'});

	$page->addTemplatePairs(
		'session_id' => $session->{'id'},
		);
	foreach (@{$self->login_fields_for_tmpl()}) {
		$page->addTemplatePairs('user_'.$_ => $recordP->{$_});
	}
}


sub doLogin {
	my $self = shift;
	my $name = shift;
	my $pass = shift;
	my $sql = $self->param('sql');

	
	my $recordP = $sql->GetRecord($self->param('account_table'),'name ='.$sql->Quote($name).' and password='.$sql->Quote($pass),@{$self->login_fields()});
	if ($recordP != undef) {
		if ($recordP->{'id'} > 0) {
			$sql->UpdateRecords($self->param('account_table'),{lastLogin => 'NOW()', lastLoginIP=>$sql->Quote($ENV{REMOTE_ADDR}) } ,"id=$recordP->{'id'}",1);
		}
		&main::logEvents($sql,$self->param('event_table'),'login','success',$recordP->{'id'},undef,$ENV{REMOTE_ADDR});
		return $self->setupSession($recordP);
	}
	else {
		&main::logEvents($sql,$self->param('event_table'),'login','failed',undef,undef,$ENV{REMOTE_ADDR});
		return undef;
	}
}

sub setupSession {
	my $self = shift;
	my $recordP = shift;
	my $session = Session->new($self->param('sql'),undef,$recordP->{'id'},$self->session_timeout(),$self->param('session_table'));
	return $self->_setupSession($recordP,$session);
}

sub _setupSession {
	my $self = shift;
	my $recordP = shift;
	my $session = shift;

	$self->param('session' => $session);
	$self->setUserInfo($recordP);
	
	my $q = $self->query();
	

	# allow admins to su over to other users.
	my $su = int($q->param('su'));
	if ($su > 0 && ($su != $self->{'user_id'}) && ($self->userHasPriv('admin'))) {
		$q->delete('su');
		my $recordP = $self->param('sql')->GetRecord($self->param('account_table'),'id = '.$su,@{$self->login_fields()});
		return $self->setupSession($recordP);
	}
	
	my $cookie = $q->cookie(-name=>'session',-value=>$session->{id});#$self->session_timeout().'s'
	$self->add_cookie($cookie);

	return $session;
}

sub getUserRecord
{
	my $self = shift;
	my $id = shift;
	
	return	$self->param('sql')->GetRecord($self->param('account_table'),'id='.$id,@{$self->login_fields()});
}

sub setUserInfo
{
	my $self = shift;
	my $recordP = shift;
	$self->param('user_info' => $recordP);

	my $flags = $recordP->{'privFlags'};
	my @privs = split (/,/,$flags);
	$self->param('user_privs' => \@privs);

	$flags = $recordP->{'prefFlags'};
	my @prefs = split (/,/,$flags);
	$self->param('user_prefs' => \@prefs);
}

sub doLogout {
	my $self = shift;

	my $q = $self->query();
	if (defined $self->param('session')) {
		my $session = $self->param('session');
		$session->delete();
		$self->delete('session');
	}
	my $cookie = $q->cookie(-name=>'session',-value=>'',-expires=>'+0s');
	$self->header_props(-cookie=>$cookie);
}


sub validateSession {
	my $self = shift;
	my $session_id = shift;

	if ($session_id ne '') {
		my $session = Session->new($self->param('sql'),$session_id,undef,$self->session_timeout(),$self->param('session_table'));
		return 0 if $session == undef;
		my $user_id = $session->{'user_id'};
		my $recordP = $self->getUserRecord($user_id);
		return 0 if $recordP == undef;
		$self->_setupSession($recordP,$session);
		return 1;
	}
	else {
		return 0;
	}
}

sub _encodeQueryParams
{
	my $q = shift;
	my @names = $q->param;
	my @qs;
	my $name;
	foreach $name (@names) {
		my @values = $q->param($name);
		foreach (@values) {
			push @qs, "$name=$_";
		}
	}
	return join('&',@qs);
}

sub checkPrivs {
	my $self = shift;
	my $page_name = shift;
	
	my $privsTable = $self->param('privsTable');
	
	return 1 unless defined $privsTable;
	return 1 unless exists $privsTable->{$page_name};
	my $priv = $privsTable->{$page_name};

	#$priv can be a single priv type
	return $self->userHasPriv($priv) if (!ref($priv));

	#or an array of priv types that need to be checked any of which is valid
	if (ref($priv) eq 'ARRAY') {
		foreach (@$priv) {
			return 1 if $self->userHasPriv($_);
		}
	}
	return 0;
}

sub userHasPriv {
	my $self = shift;
	my $priv = shift;
	foreach (@{$self->param('user_privs')}) {
		return 1 if $priv =~ /$_/;
	}
	return 0;
}

sub getUserID
{
	my $self =shift;
	my $uiP = $self->param('user_info');
	return $uiP->{'id'} if (defined $uiP);
	return 0;
}

sub getUserTimeZone
{
	my $self =shift;
	my $uiP = $self->param('user_info');
	my $tz = $self->default_time_zone;
	$tz = $uiP->{'timeZone'} if (defined $uiP && $uiP->{'timeZone'} ne '');
	return $tz;
}

sub convertUnixTimeToUserTime
{
	my $self = shift;
	my $time = shift;
	my $tz = $self->getUserTimeZone;
	return $self->convertUnixTimeToTimeZoneTime($time,$tz);
}

sub convertUnixTimeToTimeZoneTime
{
	my $self = shift;
	my $time = shift;
	my $tz = shift;
	
	$time = 0 if !defined($time);
	my $d = DateTime->from_epoch( epoch => $time);
	$d->set_time_zone($tz);
	return $d->month.'/'.$d->day.'/'.$d->year.' '.($d->hour<10?'0':'').$d->hour.':'.($d->minute<10?'0':'').$d->minute.':'.($d->second<10?'0':'').$d->second;
}

# override getLanguage to account for the user's specific langauge
sub getLanguage
{
	my $self =shift;
	my $uiP = $self->param('user_info');
	my $qlang = $self->query->param('lang');
	return $qlang if $qlang ne '';
	return $uiP->{'prefLanguage'} if (defined $uiP);
	return '';
}

1;