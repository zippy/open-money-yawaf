#! /usr/bin/perl
#-------------------------------------------------------------------------------
# om.cgi
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# This software is released under the LGPL license.
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

use CGI;

my $q = new CGI;

print $q->header();

print << "EOHTML";
<html>
<head>
<title> Down for maintenance</title>
</html>
<body>
The open money pilot project is down for maintenance.
</body>
</html>
EOHTML
