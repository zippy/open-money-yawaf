#-------------------------------------------------------------------------------
# Installer.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved  
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package Installer;

use strict;
use Carp;

use Field::Text;
use PAGE::Install;


sub new {
	my $class = shift;	
	my $self = {@_};
	
	bless $self, $class;
	
	my $a = YAWAF->new(
		TMPL_PATH => 'tmpl/',
		PARAMS => {
			'localize' => 'en', #default language is 'en'
		},
		PAGES => {
			'install' => PAGE::Install->new(
				'title' => 'Installer',
				'params' => {
					'fields' => ['site_name','db_host','db_user','db_password','db_database','admin_email','default_domain','smtp_host','system_from'],
					'undef_fields' => {'admin_email'=>1,'default_domain'=>1},
					'fieldspec' => {
						'site_name' => Field::Text->new(
							'name' => 'site_name',
							'validation' => ['required'],
							'size' => 55,
							'maxlength' => 100,
							),
						'db_host' => Field::Text->new(
							'name' => 'db_host',
							'validation' => ['required'],
							'size' => 55,
							'maxlength' => 100,
							'default' => 'localhost'
							),
						'db_user' => Field::Text->new(
							'name' => 'db_user',
							'validation' => ['required'],
							'size' => 55,
							'maxlength' => 100,
							),
						'db_password' => Field::Text->new(
							'name' => 'db_password',
							'validation' => ['required'],
							'size' => 55,
							'maxlength' => 100,
							),
						'db_database' => Field::Text->new(
							'name' => 'db_database',
							'validation' => ['required'],
							'size' => 55,
							'maxlength' => 100,
							),
						'admin_email' => Field::Text->new(
							'name' => 'admin_email',
							'validation' => ['email'],
							'size' => 55,
							'maxlength' => 100,
							),
						'default_domain' => Field::Text->new(
							'name' => 'default_domain',
							'size' => 20,
							'maxlength' => 20,
							),
						'smtp_host' => Field::Text->new(
							'name' => 'smtp_host',
							'validation' => ['required'],
							'size' => 55,
							'maxlength' => 100,
							'default' => 'localhost'
							),
						'system_from' => Field::Text->new(
							'name' => 'system_from',
							'validation' => ['email','required'],
							'size' => 55,
							'maxlength' => 100,
							'default' => 'no-reply@'.$ENV{'HTTP_HOST'}
							),
					},
				},
			),
		}
	);
	$a->start_page('install');
	$self->{'app'} = $a;
	$self->_initialize();

	return $self;
}

sub _initialize
{
	my $self = shift;
}

1;