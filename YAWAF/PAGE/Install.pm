#-------------------------------------------------------------------------------
# PAGE::Install.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved  
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package PAGE::Install;

use strict;

use base 'PAGE::Form';

sub submit
{
	my $self = shift;

	my $app = $self->param('app');
	my $q = $app->query();

	my @fields = @{$self->{'params'}->{'fields'}};

	my %fields;
	my $undef_if_null_fields = $self->{'params'}->{'undef_fields'};

	my @names;
	my @vals;
	foreach (@fields) {
		my $v = $q->param($_);
		if ($v eq '' && $undef_if_null_fields->{$_}) {
			$v = 'undef';
		}
		else {
			$v = "'$v'";
		}
		push @vals,$v;
		push @names,'$main::'.$_;
	}
	my $names = join(',',@names);
	my $vals = join(',',@vals);

	my $configData = <<"EOF";
#-------------------------------------------------------------------------------
# config.pl
# Copyright (c) 2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

#NOTE: This file is auto-generated by the installer.

($names) = 
($vals);
1;
EOF
	my $sql = [$q->param('db_host'),$q->param('db_user'),$q->param('db_password'),$q->param('db_database')];
	my $err_log;
	
#	$sql = YAWAF::SQL->new($host,$user,$password,$database);
	if (!(-w '.')) {
		$err_log = "This directory appears not to be writable, which is necessary to create the config file.\n";
	} else {
			if ((my $err = &createTables('db.sql',$sql)) ne '') {
   				$err_log .= "error creating mysql tables:  $err\n"; 
			} 
			else {
				if (opendir( YAWAF_MODS, 'YAWAFmodules')) {
    				while (my $f = readdir( YAWAF_MODS ) ) {
    						next unless ( (-d "YAWAFmodules/$f") && ($f !~ /^\./) );
    						my $sql_file = "YAWAFmodules/$f/$f.sql";
    						if ( -e $sql_file && (my $err = &createTables($sql_file,$sql)) ne '' ) {
	   							$err_log .= "error creating mysql tables:  $err\n"; 
	   						}
    				}
   					closedir( YAWAF_MODS );
				} 
				else {
					$err_log .= "Can't open YAWAFmodules\n";
				}
				if ( ($err_log eq '') && ((my $err = &writeFile('config.pl',$configData)) ne '') ) {
					$err_log .= "unable to write config.pl:  $err\n";	    					
				}
			}
	}

	if ($err_log ne '') {
		$self->addTemplatePairs('install_error' => $err_log);
	}
	else {
		$self->addTemplatePairs('install_successful' => 1);
	}

	return $self->show();
}

sub createTables
{
	my $file_name = shift;
	my $sql = shift;
	my ($host,$user,$password,$database) = @$sql;
	return `/usr/bin/mysql -h $host -u $user --password='$password' $database < $file_name 2>&1 1>/dev/null`;
}

sub writeFile
{
	my $file_name = shift;
	my $data = shift;
	my $open_string = "> ";
	open(DATA, $open_string.$file_name) or return $!;
	print DATA $data;
	close(DATA);
	return '';
}

1;