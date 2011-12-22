#-------------------------------------------------------------------------------
# PAGE.pm
# Copyright (C) 2004-2006 Harris-Braun Enterprises, LLC, All Rights Reserved  
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package PAGE;

use strict;
use Carp;

sub new {
	my $class = shift;	
	my $self = {@_};
	
	bless $self, $class;
	$self->{'default_method'} = 'show';
	$self->_initialize();

	return $self;
}

sub _initialize
{
	my $self = shift;
}

sub param {
	my $self = shift;
	my (@data) = (@_);

	my $rp = $self;

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

sub setup {
	my $self = shift;
	my $page_name = shift;
	my $app = shift;
	
	$self->page_name($page_name);
	
	my $q = $app->query();
	my $url = $q->url(-relative=>1);
	my $aurl = $q->url(-absolute=>1);
	my $path = '';
	$path = $1 if $aurl =~ /(.*\/)/;
	$self->addTemplatePairs(
		'_url' => $url,
		'_url_full' => $q->url(),
		'_path' => $path,
		'r' => $q->param('r'),
	);
	my $p = $self->{'params'};

	$self->_checkPassThrus($p,$q);

	my $title = $self->{'title'};
	$self->addTemplatePairs('_title' => $title) if $title ne '';
	if (exists $self->{'expires'}) {
		$app->header_add('-expires',$self->{'expires'});
	}
	if (exists $self->{'no-cache'}) {
		$q->cache(1);
	}
	
	$self->param('app' => $app);

	my $m = $q->param('m');
	
	if (not defined $m) {
		$m = $self->{'default_method'};
	}
	else {
		croak("invalid method '$m' for page ".$self->page_name())
			unless $m eq $self->{'default_method'} || exists $self->{'methods'}->{$m};
	}
	$self->param('m' => $m);
}

sub getBody
{
	my $self = shift;
	my $m = $self->param('m');
	return $self->$m();
}

sub show {
	my $self = shift;
	my $tmpl_override = shift;
	
	my $page_name = $self->page_name();
	
	my $pn = $page_name;
	my $module = $self->{__CURRENT_MODULE};
	if ($module ne '') {
		$pn = "$module/$page_name";
	}
	$self->addTemplatePairs('p' => $pn);
	$self->addTemplatePairs('p_'.$pn => 1);
	
	$self->addTemplatePairs('section_'.$self->{'section'} => 1) if exists $self->{'section'};

	
	my $app = $self->param('app');
	my $tmpl_path = $app->tmpl_path();
	my @lang_tmpl_paths;
	my $localize = $app->param('localize');
	if ($localize ne '') {
		my $lang_dir_name = $app->L10N_dir();
		my $lang = $app->getLanguage();
		#if the default language isn't the user's language, then we need to setup the
		#correct paths for the template processor
		if ($lang ne '' && $lang ne $localize) {
			my $p;
			if ($module ne '') {
				$p = $app->module_directory()."/$module/tmpl/";
				$p .= "$lang_dir_name/$lang/";
				push (@lang_tmpl_paths,$p) if -e $p;
			}
			$p = $tmpl_path;
			$p .= "$lang_dir_name/$lang/";
			push (@lang_tmpl_paths,$p) if -e $p;
		}
	}
	
	my $q = $app->query();
	
	my $tmpl_file_name;
	if ($tmpl_override ne '') {
		$tmpl_file_name = $tmpl_override;
	}
	else {
		$tmpl_file_name = (exists $self->{'tmpl_file_name'})?$self->{'tmpl_file_name'}:$page_name.'.html';
	}
	
	my @extra_params;
	my $epH;
	
	if (exists 	$self->{'tmpl_params'}) {
		$epH = $self->{'tmpl_params'};
	}
	else {
		$epH = {};
	}
	$epH->{'die_on_bad_params'} = 0 unless exists $epH->{'die_on_bad_params'};
	$epH->{'global_vars'} = 0 unless exists $epH->{'global_vars'};
	if (exists $epH->{'path'}) {
		push (@{$epH->{'path'}},$tmpl_path);
	}
	else{
		$epH->{'path'} = [ $tmpl_path ];
	}
	unshift (@{$epH->{'path'}},@lang_tmpl_paths) if @lang_tmpl_paths;

	while (my($k,$v) = each (%$epH)) {
		push @extra_params,$k,$v;
	}
	
	require HTML::Template;
	my $tmpl = HTML::Template->new_file($tmpl_file_name, @extra_params);

	my $pairs = $self->param('tmpl_pairs');

	$tmpl->param(%$pairs);  #set all the template pairs
	
	return $tmpl->output;
	
}

sub page_name {
	my $self = shift;
	my ($page_name) = @_;

	# First use?  Create new __PAGE_NAME!
	$self->{__PAGE_NAME} = undef unless (exists($self->{__PAGE_NAME}));

	# If data is provided, set it!
	if (defined($page_name)) {
		$self->{__PAGE_NAME} = $page_name;
	}

	# If we've gotten this far, return the value!
	return $self->{__PAGE_NAME};
}

#-------

sub addTemplatePairs {
	my $self = shift;
	my $pairs = $self->param('tmpl_pairs');
	$pairs = {} if $pairs == undef;
	while (@_) {
		my $key = shift;
		my $v = shift;
		$pairs->{$key} = $v;
	}
	$self->param('tmpl_pairs' => $pairs);
}

sub addFlagsToTemplatPairs {
	my $self = shift;
	my $pairs = $self->param('tmpl_pairs');
	$pairs = {} if $pairs == undef;
	foreach (@_) {
		$pairs->{$_} = 1;
	}
	$self->param('tmpl_pairs' => $pairs);
}

sub setTemplatePairsFromQuery {
	my $self = shift;
	my $pairs = $self->param('tmpl_pairs');
	my $q = $self->query();

	$pairs = {} if $pairs == undef;
	foreach (@_) {
		$pairs->{$_} = $q->param($_);
	}
	$self->param('tmpl_pairs' => $pairs);
}

sub setTemplatePairsFromHash {
	my $self = shift;
	my $hashP = shift;
	my $pairs = $self->param('tmpl_pairs');

	$pairs = {} if $pairs == undef;
	foreach (keys %$hashP) {
		my $v = $hashP->{$_};
		$pairs->{$_} = $v;
	}
	$self->param('tmpl_pairs' => $pairs);
}


sub deleteTemplatePairs {
	my $self = shift;
	my $pairs = $self->param('tmpl_pairs');
	if ($pairs != undef) {
		foreach (@_) {
			delete $pairs->{$_};
		}
		$self->param('tmpl_pairs' => $pairs);
	}
}

sub deleteAllTemplatePairs {
	my $self = shift;
	$self->param('tmpl_pairs' => undef);
}

sub getTemplatePairValue {
	my $self = shift;
	my $key = shift;
	my $pairs = $self->param('tmpl_pairs');
	if ($pairs != undef) {
		return $pairs->{$key};
	}
	return undef;
}


#------------------------------------------

sub specErrorDie {
	my $self = shift;
	my $page_name = shift;
	my $err = shift;
	die "Page '".$page_name."' spec error: ".$err;
}

sub _checkPassThrus {
	my $self = shift;
	my $p = shift;
	my $q = shift;
	
	if (exists $p->{'querryPassThruValues'}) {
		foreach (@{$p->{'querryPassThruValues'}}) {
			$self->addTemplatePairs($_ => $q->param($_));
		}
	}
}

1;