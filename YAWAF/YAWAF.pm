#-------------------------------------------------------------------------------
# YAWAF.pm
# Copyright (C) 2004-2006 Harris-Braun Enterprises, LLC
# based on CGI::Application Copyright (C) 2000-2003 Jesse Erlbaum <jesse -at- erlbaum.net>
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
#-------------------------------------------------------------------------------

package YAWAF;
use strict;
use Carp;

$YAWAF::VERSION = '0.1';

###################################
####  INSTANCE SCRIPT METHODS  ####
###################################

sub new {
	my $class = shift;
	my @args = @_;

	if (ref($class)) {
		# No copy constructor yet!
		$class = ref($class);
	}

	# Create our object!
	my $self = {};
	bless($self, $class);

	# Process optional new() parameters
	my $rprops;
	if (ref($args[0]) eq 'HASH') {
		my $rthash = %{$args[0]};
		$rprops = $self->_cap_hash($args[0]);
	} else {
		$rprops = $self->_cap_hash({ @args });
	}

	# Set module_dir()
	if (exists($rprops->{MODULE_DIR})) {
		$self->module_dir($rprops->{MODULE_DIR});
	}

	# Set L10N_dir()
	if (exists($rprops->{L10N_DIR})) {
		$self->L10N_dir($rprops->{L10N_DIR});
	}

	# Set tmpl_path()
	if (exists($rprops->{TMPL_PATH})) {
		$self->tmpl_path($rprops->{TMPL_PATH});
	}

	# Set CGI query object
	if (exists($rprops->{QUERY})) {
		$self->query($rprops->{QUERY});
	}

	# Set PAGES table
	if (exists($rprops->{PAGES})) {
		$self->pages($rprops->{PAGES});
	}

	# Set up init param() values
	if (exists($rprops->{PARAMS})) {
		croak("PARAMS is not a hash ref") unless (ref($rprops->{PARAMS}) eq 'HASH');
		my $rparams = $rprops->{PARAMS};
		while (my ($k, $v) = each(%$rparams)) {
			$self->param($k, $v);
		}
	}

	# Call yawaf_init() method, which may be implemented in the sub-class.
	# Pass all constructor args forward.  This will allow flexible usage 
	# down the line.
	$self->yawaf_init($rprops);

	# Call setup() method, which should be implemented in the sub-class!
	$self->setup();

	return $self;
}


sub run {
	my $self = shift;

	my $page_name = $self->yawaf_get_page_name();

	my $page = $self->yawaf_get_page($page_name);

	my $body = $self->yawaf_get_body($page);

    # Make sure that $body is not undefined (supress 'uninitialized value' warnings)
    $body = "" unless defined $body;

    # Support scalar-ref for body return
    my $bodyref = (ref($body) eq 'SCALAR') ? $body : \$body;

	# Set up HTTP headers
	if (exists $page->{'charset'}) {
		$self->header_add(-charset=>$page->{'charset'})
	}
	if (exists $page->{'MIME_type'}) {
		$self->header_add(-type=>$page->{'MIME_type'})
	}
	if (exists $self->{__COOKIES}) {
		$self->header_type('header');
		$self->header_props(-cookie=>$self->{__COOKIES});
	}
	my $headers = $self->_send_headers();

	# Build up total output
	my $output  = $headers.$$bodyref;


	# Send output to browser (unless we're in serious debug mode!)
	unless ($ENV{CGI_APP_RETURN_ONLY}) {
		
		if ($self->param('do_ssi_processing') ne '') {
			$output = $self->ssiProcess($output);
	    }

		print $output;
	}

	# clean up operations
	$self->teardown();

	return $output;
}

sub ssiProcess
{
	my $self = shift;
	my $output = shift;
	
	while ($output =~ s/<!-- *#include virtual="([^"]*)" *-->/$self->getInclude($1)/e) {};
	
	return $output;
}

sub getInclude
{
	my $self = shift;
	my $file = shift;
#	return $ENV{'HTTP_HOST'} if $file eq '/ww-cgi/inc_domain.cgi';
#	return $conf_longnamehtml_map{$G_workshop} if $file eq '/ww-cgi/inc_name.cgi';
#	return $conf_shortnamehtml_map{$G_workshop} if $file eq '/ww-cgi/inc_shortname.cgi';

#	if ($file =~ /\.cgi$/) {
#		$file = "$scripts_base/$file";
#		my $f = `$file`;
#		$f =~ s/(.*?)\n\n//s;
#		return $f;
#	}	

	my $file_name = $self->param('do_ssi_processing').$file;
	my $size = -s $file_name;
	my $buffer;
	if ($size > 0) {
		open(READ, $file_name) || &die("Sorry, I couldn't open file '$file_name' for ssi processing. ($!)");
		read(READ, $buffer, $size);
		close(READ);
	}
	return $self->ssiProcess($buffer);
}




############################
####  OVERRIDE METHODS  ####
############################

sub yawaf_get_query {
	my $self = shift;

	# Include CGI.pm and related modules
	require CGI;

	# Get the query object
	my $q = CGI->new();

	return $q;
}

sub yawaf_get_page_name {
	my $self = shift;
	my $q = $self->query();

	my $page_name;

	my $page_param = $self->page_param() || croak("No page_param() specified");

	# Support call-back instead of CGI mode param
	if (ref($page_param) eq 'CODE') {
		# Get run mode from subref
		$page_name = $page_param->($self);
	} else {
		# Get run mode from CGI param
		$page_name = $q->param($page_param);
	}

	# If $page_name undefined, use default (start) page
	my $def_page = $self->start_page();
	$def_page = '' unless defined $def_page;
	$page_name = $def_page unless (defined($page_name) && length($page_name));
	return $page_name;
}

sub yawaf_get_page
{
	my $self = shift;
	my $full_page_name = shift;
	
	my ($page_name,$module) = $self->yawaf_setup_module($full_page_name);
	my $page = $self->yawaf_setup_page($page_name,$module);
	return $page;
}

sub yawaf_setup_module
{
	my $self = shift;
	my $page_name = shift;
	my $q = $self->query();

	my $module;
	if ($page_name =~ m#([^/]+)/(.*)#) {
		$module = $1;
		$page_name = $2;
		$module =~ s/[^a-z0-9._-]//gi;  #sanitze module name
		my $module_path=$self->module_directory()."/$module";
		-d $module_path || croak("Module path $module_path doesn't exist");
		-e "$module_path/$module.pm" || croak("$module.pm doesn't exist for $module");
		-d "$module_path/tmpl" || croak("tmpl directory doesn't exist for $module");
		unshift (@INC,"$module_path/");
		require "$module.pm";
		$q->{__MODULE_NAME} = $module;
	}
	return ($page_name,$module);
}

sub yawaf_setup_page
{
	my $self = shift;
	my $page_name = shift;
	my $module_name = shift;
	
	my $page;
	my $module_dir;
	if ($module_name ne '') {
		$module_dir = $self->module_directory();
		$page = ("$module_dir"."::$module_name")->get_page($page_name);
		shift @INC;
		if (defined $page) {
			my $t;
			if (exists $page->{'tmpl_params'}) {
				$t = $page->{'tmpl_params'};
			}
			else {
				$t = {};
				$page->{'tmpl_params'} = $t;
			}
			$t->{'path'} = ["$module_dir/$module_name/tmpl"];
			$page->{__CURRENT_MODULE} = $module_name;
		}
	}
	else {
		my %pages = ($self->pages());
	
		$page = $pages{$page_name};
	}

	croak ("'$page_name' not found in page list") unless defined $page;
	
	$page->setup($page_name,$self);
	if (exists $page->{__REDIRECT_PAGE}) {
		$page = $page->{__REDIRECT_PAGE};
	}
	# Set get_current_page() for access by user later
	$self->{__CURRENT_PAGE} = $page;

	my $globals = $self->param('global_template_values');
	if (defined $globals) {
		$page->addTemplatePairs(@$globals);
	}
	if ($module_dir ne '' && -e "$module_dir/$module_name/$module_name.css") {
		my $path = $page->getTemplatePairValue('_path');
		$page->addTemplatePairs('_head',
		 qq#<link href="$path$module_dir/$module_name/$module_name.css" rel="stylesheet" type="text/css">#
	 );
	}
	if (exists $page->{'head'}) {
		my $head = $page->getTemplatePairValue('_head');
		$page->addTemplatePairs('_head',$head.$page->{'head'});
	}

	return $page;
}

sub yawaf_get_body
{
	my $self = shift;
	my $page = shift;

	my $body =  $page->getBody();
	my $localize = $self->param('localize');
	if ($localize ne '') {
		$body = $self->yawaf_localize($localize,$body);
	}
	return $body;
	
}

sub yawaf_localize
{
	my $self = shift;
	my $default_language = shift;
	my $body = shift;
	
	$body =~ s/({{)|(}})//g;
	return $body;

# this is here as the start of localizing stuff that wasn't localize by the static 
# template localizing code I then added later -ehb
my $page;

	my $lang = $self->getLanguage();
	if ($lang eq '' || $lang eq $default_language) {
		$body =~ s/({{)|(}})//g;
	}
	else {
		my $page_name = $page->page_name();
		my $lang_file = $page_name.'_'.$lang.'.pl';
		my $path;
		if ($page->{__CURRENT_MODULE} ne '') {
			$path = $self->module_directory()."/$page->{__CURRENT_MODULE}/tmpl/";
		}
		else {
			$path = $self->tmpl_path();
		}
		$lang_file = $path.$lang_file;
		die $lang_file;
		if (-e $lang_file) {
			require $lang_file;
			while ($body =~ /{{(.*?)}}/) {
				my $t = $YAWAF::Lexicon{$1};
				$t = $1 if $t eq '';
				$body =~ s/{{$1}}/$t/;
			}
		}
		else {
			$body =~ s/({{)|(}})//g;
		}
	}
}


sub yawaf_init {
	my $self = shift;
	my @args = (@_);

	# Nothing to init, yet!
}


sub setup {
	my $self = shift;

	# Nothing to setup, yet!

#	$self->start_page('home');
#	$self->pages(
#		'start' => 'dump_html',
#	);
}


sub teardown {
	my $self = shift;

	# Nothing to shut down, yet!
}




######################################
####  APPLICATION MODULE METHODS  ####
######################################

sub header_add {
	my $self = shift;
    return $self->_header_props_update(\@_,add=>1);
}

sub header_props {
	my $self = shift;
    return $self->_header_props_update(\@_,add=>0);
}

# used by header_props and header_add to update the headers
sub _header_props_update {
    my $self     = shift;
    my $data_ref = shift;
    my %in       = @_;

    my @data = @$data_ref;

	# First use?  Create new __HEADER_PROPS!
	$self->{__HEADER_PROPS} = {} unless (exists($self->{__HEADER_PROPS}));

	my $props;

	# If data is provided, set it!
	if (scalar(@data)) {
		warn("header_props called while header_type set to 'none', headers will NOT be sent!") if $self->header_type eq 'none';
		# Is it a hash, or hash-ref?
		if (ref($data[0]) eq 'HASH') {
			# Make a copy
			%$props = %{$data[0]};
		} elsif ((scalar(@data) % 2) == 0) {
			# It appears to be a possible hash (even # of elements)
			%$props = @data;
		} else {
            my $meth = $in{add} ? 'add' : 'props';
			croak("Odd number of elements passed to header_$meth().  Not a valid hash")
		}

        # merge in new headers, appending new values passed as array refs
        if ($in{add}) {
            for my $key_set_to_aref (grep { ref $props->{$_} eq 'ARRAY'} keys %$props) {
                my $existing_val = $self->{__HEADER_PROPS}->{$key_set_to_aref};
                next unless defined $existing_val;
                my @existing_val_array = (ref $existing_val eq 'ARRAY') ? @$existing_val : ($existing_val);
                $props->{$key_set_to_aref}  = [ @existing_val_array, @{ $props->{$key_set_to_aref} } ];
            }
            $self->{__HEADER_PROPS} = { %{ $self->{__HEADER_PROPS} }, %$props };
        }
        # Set new headers, clobbering existing values
        else {
            $self->{__HEADER_PROPS} = $props;
        }

	}

	# If we've gotten this far, return the value!
	return (%{ $self->{__HEADER_PROPS}});
}

sub param {
	my $self = shift;
	my (@data) = (@_);

	# First use?  Create new __PARAMS!
	$self->{__PARAMS} = {} unless (exists($self->{__PARAMS}));

	my $rp = $self->{__PARAMS};

	# If data is provided, set it!
	if (scalar(@data)) {
		# Is it a hash, or hash-ref?
		if (ref($data[0]) eq 'HASH') {
			# Make a copy, which augments the existing contents (if any)
			%$rp = (%$rp, %{$data[0]});
		} elsif ((scalar(@data) % 2) == 0) {
			# It appears to be a possible hash (even # of elements)
			%$rp = (%$rp, @data);
		} elsif (scalar(@data) > 1) {
			croak("Odd number of elements passed to param().  Not a valid hash");
		}
	} else {
		# Return the list of param keys if no param is specified.
		return (keys(%$rp));
	}

	# If exactly one parameter was sent to param(), return the value
	if (scalar(@data) <= 2) {
		my $param = $data[0];
		return $rp->{$param};
	}
	return;  # Otherwise, return undef
}


sub delete {
        my $self = shift;
        my ($param) = @_;
        #return undef it it isn't defined
        return undef if(!defined($param));
                                                                                                                                                             
        #simply delete this param from $self->{__PARAMS}
        delete $self->{__PARAMS}->{$param};
}
                                                                                                                                                             

sub query {
	my $self = shift;
	my ($query) = @_;

	# We're only allowed to set a new query object if one does not yet exist!
	unless (exists($self->{__QUERY_OBJ})) {
		my $new_query_obj;

		# If data is provided, set it!  Otherwise, create a new one.
		if (defined($query)) {
			$new_query_obj = $query;
		} else {
			$new_query_obj = $self->yawaf_get_query();
		}

		$self->{__QUERY_OBJ} = $new_query_obj;
	}

	return $self->{__QUERY_OBJ};
}


sub pages {
	my $self = shift;
	my (@data) = (@_);

	# First use?  Create new __PAGES!
	$self->{__PAGES} = {} unless (exists($self->{__PAGES}));

	my $rr_m = $self->{__PAGES};

	# If data is provided, set it!
	if (scalar(@data)) {
		# Is it a hash, hash-ref, or array-ref?
		if (ref($data[0]) eq 'HASH') {
			# Make a copy, which augments the existing contents (if any)
			%$rr_m = (%$rr_m, %{$data[0]});
		} elsif (ref($data[0]) eq 'ARRAY') {
			# Convert array-ref into hash table
			foreach my $rm (@{$data[0]}) {
				$rr_m->{$rm} = $rm;
			}
		} elsif ((scalar(@data) % 2) == 0) {
			# It appears to be a possible hash (even # of elements)
			%$rr_m = (%$rr_m, @data);
		} else {
			croak("Odd number of elements passed to pages().  Not a valid hash");
		}
	}

	# If we've gotten this far, return the value!
	return (%$rr_m);
}


sub module_directory {
	my $self = shift;
	return $self->_scalar_param('MODULE_DIR','YAWAFmodules',undef,@_);
}
sub L10N_dir {
	my $self = shift;
	return $self->_scalar_param('L10N_DIR','lang',undef,@_);
}
sub page_param {
	my $self = shift;
	return $self->_scalar_param('PAGE_PARAM','p',undef,@_);
}
sub start_page {
	my $self = shift;
	return $self->_scalar_param('START_PAGE','home',undef,@_);
}
sub tmpl_path {
	my $self = shift;
	return $self->_scalar_param('TMPL_PATH','',undef,@_);
}
sub header_type {
	my $self = shift;
	return $self->_scalar_param('HEADER_TYPE','header',
		sub {
			my @allowed_header_types = qw(header redirect none);
			my $header_type = lc(shift);
			croak("Invalid header_type '$header_type'")
				unless(grep { $_ eq $header_type } @allowed_header_types);
			return $header_type;
		}
		,@_);
}

sub _scalar_param {
	my $self = shift;
	my $param_name = '__'.shift;
	my $default_value = shift;
	my $set_func = shift;
	my ($param_value) = @_;

	# First use?  Create new $param_name!
	$self->{$param_name} = $default_value unless (exists($self->{$param_name}));

	# If data is provided, set it!
	if (defined($param_value)) {
		if (defined $set_func) {
			$param_value = &$set_func($param_value);
		}
		$self->{$param_name} = $param_value;
	}

	# If we've gotten this far, return the value!
	return $self->{$param_name};
}

sub get_current_page {
	my $self = shift;

	# It's OK if we return undef if this method is called too early
	return $self->{__CURRENT_PAGE};
}


sub add_cookie 
{
	my $self = shift;
	my $cookie = shift;
	
	my $cookies = $self->{__COOKIES};
	if (! defined $cookies) {
		$cookies = [];
		$self->{__COOKIES} = $cookies;
	}
	push(@$cookies,$cookie);
}

sub getLanguage
{
	my $self = shift;
	return $self->param('localize');
}



###########################
####  PRIVATE METHODS  ####
###########################


sub _send_headers {
	my $self = shift;
	my $q = $self->query();

        my $header_type = $self->header_type();

	if ($header_type eq 'redirect') {
		return $q->redirect($self->header_props());
	} elsif ($header_type eq 'header' ) {
		return $q->header($self->header_props());
	}

        # croak() if we have an unknown header type
        croak ("Invalid header_type '$header_type'") unless ($header_type eq "none");

        # Do nothing if header type eq "none".
        return "";
}


# Make all hash keys CAPITAL
sub _cap_hash {
	my $self = shift;
	my $rhash = shift;
	my %hash = map {
		my $k = $_;
		my $v = $rhash->{$k};
		$k =~ tr/a-z/A-Z/;
		$k => $v;
	} keys(%{$rhash});
	return \%hash;
}



1;


=pod

=head1 NAME

YAWAF - 
Yet another framework for building reusable web-applications


=head1 SYNOPSIS

  # In "WebApp.pm"...
  package WebApp;
  use base 'YAWAF';
  use PAGE;

  sub setup {
	my $self = shift;
	$self->start_page('mode1');
	$self->page_param('rm');
	$self->pages(
		'home' => PAGE->new(),
		'other' => PAGE::cool->new( ... ),
		'another' => PAGE::cool->new( ... )
	);
  }
  1;

  ### In "PAGE/cool.pm"...
  package PAGE::cool;
  use base 'PAGE';

  sub _initialize
  {
    my $self = shift;
    $self->{'methods'} = {'show' => 1,'method1'=>1,'method2'=>1};
  }
  
  sub method1
  {
    my $self = shift;
  	return "cool results of method1";
  }

  sub method2
  {
    my $self = shift;
 	return $self->show() if ( ..boring..);
  	return "cool results of method2";
  }

  ### In "webapp.cgi"...
  use WebApp;
  my $webapp = WebApp->new();
  $webapp->run();


=head1 USAGE EXAMPLE

YAWAF is based on, and uses some of same machinery as CGI::Application
but, where CGI::Application uses the notion of a "run mode" which maps to
a method of the CGI::Application that is called to display the various 
pages of your website, YAWAF instead adds another abstraction into the 
mix, the PAGE module.  This module takes over the role of actually
generating the html for any given page, which means that you can much
more easily define page types that are reusable across applications.

CGI::Application provides an object oriented framwork for developing your
Web app, but the way it is structured makes you think of the web site
you develop from a functional point of view, with each run mode being 
the function that implements a page (or group of pages) on your web site.

YAWAF lets you keep your OO thinking as you develop your site too.  Each
web page is an object, with methods that can be called on it.

=head1 LICENSE

YAWAF : Yet another framework for building reusable web-applications
Copyright (C) 2004 Harris-Braun Enterprises, LLC, <eric -at- harris-braun.com>
based on CGI::Application
Copyright (C) 2000-2003 Jesse Erlbaum <jesse -at- erlbaum.net>

This module is free software; you can redistribute it and/or modify it
under the terms of either:

a) the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version,

or

b) the "Artistic License" which comes with this module.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
the GNU General Public License or the Artistic License for more details.

You should have received a copy of the Artistic License with this
module, in the file ARTISTIC.  If not, I'll be glad to provide one.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
USA


=cut



