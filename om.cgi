#! /usr/bin/perl
#-------------------------------------------------------------------------------
# om.cgi
# Copyright (C) 2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

use lib 'YAWAF';
use strict;
use OMApp;
use YAWAF::SQL;
use OM::SQL;

require 'pages.pl';

$SIG{__DIE__} = \&dieHandler;		
sub dieHandler
{
	print "Content-Type: text/html\n\n";
	print "<FONT color=red>Error: </font>".shift;
#	exit;
#	die;
}

if ((!-e 'config.pl')) {
	require Installer;
	my $installer = Installer->new();
	$installer->{'app'}->run();
}
else {
	require 'config.pl';
	
	my $sql = YAWAF::SQL->new($main::db_host,$main::db_user,$main::db_password,$main::db_database);
	
	# Create a new instance of the open money YAWAF app
	my $om = 
	my $a = OMApp->new(
		TMPL_PATH => 'tmpl/',
		PARAMS => {
			'global_template_values' => ['_global_site_name' => $main::site_name],
			'session_table' => 'sessions',
			'account_table' => 'account',
			'event_table' => 'eventLog',
			'sql' => $sql,
			'privsTable' => \%main::pagePrivs,
			'noLoginPages' => \%main::noLoginPages,
	
			#the values are all defined in the config.pl file as set up during installation
			'SMTP_SERVER' => $main::smtp_host,
			'notify_of_new_user' => $main::admin_email,
			'SYSTEM_FROM' => $main::system_from,

			'localize' => 'en', #default language is 'en'
	
			#this is the instance of the open money network access module
			#used by this YAWAF app
			'om' => OM->new(
				'sql' => $sql,
				'default_domain' => $main::default_domain,
				'account_tables' => {
					'account_table' => 'om_account',
					'summary_table' => 'om_summary',
					'ledger_table' => 'om_ledger',
					},
				'currency_tables' => {
					'currency_table' => 'om_currency',
					'currency_accounts_table' => 'om_currency_accounts',
					},
				'domain_tables' => {
					'domain_table' => 'om_domain',
					},
				),
			},
		PAGES => \%main::pages
	);
	
	$a->run();
}