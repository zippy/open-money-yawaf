#-------------------------------------------------------------------------------
# L10N.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package L10N;

use strict;
use base 'PAGE';

sub _initialize
{
	my $self = shift;

	$self->SUPER::_initialize;
	
	$self->{'methods'}->{'edit'} = 1;
	$self->{'methods'}->{'submit'} = 1;
}

sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;

	my $q = $app->query();

	my $lang = $app->getLanguage();
	$self->{'lang'} = $lang;
	
	$self->addTemplatePairs('lang' => $lang);
	$self->SUPER::setup($page_name,$app);
}

sub show
{
	my $self = shift;
	my $app = $self->param('app');

	$self->addTemplatePairs('m_show' => 1);
	
	my $dir = $app->tmpl_path();
	my $module;
	my @files;
	
	my %loc;
	my $lang_dir = $app->L10N_dir();
	$self->_getFiles($dir,\@files,\%loc,$lang_dir);
	my $module_dir = $app->module_directory();
    if (-e $module_dir) {
    	$dir = "$module_dir/";
		opendir( DIR, $dir )
			or die "Can't open $dir: $!";
		
		my @modules;
		while (my $f = readdir( DIR ) ) {
			next if $f =~ /^\./;
			next if !-d $dir.$f;
			push @modules,$f;
		}
		closedir( DIR );
		foreach (@modules) {
			$self->_getFiles("$module_dir/$_/tmpl/",\@files,\%loc,$lang_dir,$_);
		}
    }
	foreach (@files) {
		$_->{'notlocalized'} = 1 if !exists($loc{$_->{'name'}});
		$_->{'notcompleted'} = 1 if $loc{$_->{'name'}}==2;
	}
	$self->addTemplatePairs('templates' => \@files);

	return $self->SUPER::show();
}

sub _getFiles
{
	my $self = shift;
	my $dir = shift;
    my $files = shift;
    my $localized = shift;
    my $lang_dir_name = shift;
    my $module = shift;
    
    if (opendir( DIR, $dir )) {
		my $app = $self->param('app');
		my $module_dir = $app->module_directory();
		while (my $f = readdir( DIR ) ) {
			next if $f =~ /^\./;
			next if -d $dir.$f;
			next if $f !~ /\.html$/;  #for now!!
			my $of = $f;
			$f = "$module/$f" if $module ne '';
			push @$files, {'name' => $f};
#			die -e $dir.$lang_dir_name.'/'.$self->{'lang'}.'/'.$of;
			my $localized_file = $dir.$lang_dir_name.'/'.$self->{'lang'}.'/'.$of;

			#find out which files have been localized and which ones have been only
			#partially localized indecated by phrases in the source template that are 
			#missing in the lexicon.
			if (-e $localized_file) {
				$localized->{$f} = 1;
				my %lex;
				_loadLexicon($localized_file,\%lex);

				my $src_tmpl;
				if ($module ne '') {
					$src_tmpl = "$module_dir/$module/tmpl/$of";
				}
				else {
					$src_tmpl = $dir.$f;
				}
				my $body;
				if (open (FILE,$src_tmpl)) {
					read(FILE, $body, -s $src_tmpl);
					close(FILE);
				}
				my %phrases;
				_getPhrases($body,\%phrases);
				foreach (keys(%phrases)) {
					$localized->{$f} = 2 if ($lex{$_} eq '');
				}
			}
		}
		closedir( DIR );
	}
}



sub edit
{
	my $self = shift;
	my $app = $self->param('app');
	my $q = $app->query();
	
	$self->addTemplatePairs('m_edit' => 1);
	my $tmpl = $q->param('t');
	$self->addTemplatePairs('t' => $tmpl);
	
	my ($src_dir,$src_file,$dest_dir) = $self->_getTmplDirs($tmpl,$app);

	my $src_tmpl = $src_dir.$src_file;
	my $size = -s $src_tmpl;
	if (-e $src_tmpl && $size) {
		my $body;
		if (open (FILE,$src_tmpl)) {
			read(FILE, $body, $size);
			close(FILE);
		}
		
		my $copy = $body;
		my @fields;
		my %lex;
		my %phrases;
		
		_loadLexicon($dest_dir.$src_file,\%lex);
		_getPhrases($body,\%phrases);
		foreach my $phrase (keys(%phrases)) {
			my $len = length($phrase);
			push @fields,{
				'phrase' => $phrase,
				'field' =>  ($len < 80)?
					$q->textfield(-name=>'___'.$phrase,
								  -size => 80,
								  -value => $lex{$phrase}):
					$q->textarea(-name=>'___'.$phrase,
								  -rows => 5,
								  -cols => 78,
								  -value => $lex{$phrase})

			};
		}
	
		$self->addTemplatePairs('fields' => \@fields);
		

#		$copy =~ s#<(/*)tmpl(.*?)>#&lt;$1tmpl$2&gt;#g;
		$copy =~ s#<(/*)tmpl(.*?)>##g;
		$self->addTemplatePairs('tmpl' => $copy);		
	}
	else {
		return "Whoa! template doesn't exist";
	}
		
	return $self->SUPER::show();	
}

sub submit
{
	my $self = shift;
	my $app = $self->param('app');
	my $q = $app->query();
	my @names = grep(s/^___//,$q->param);
	my %lex;
	foreach (@names) {
		my $v = $q->param('___'.$_);
		$lex{$_} = $v if $v ne '';
	}


	my $tmpl = $q->param('t');
	my ($src_dir,$src_file,$dest_dir) = $self->_getTmplDirs($tmpl,$app,1);
	
	&_saveLexicon("$src_dir$src_file","$dest_dir$src_file",\%lex);
	
	my $page_name = $q->param('r');
	if ($page_name ne '') {
		$q->delete_all();
		my $page = $app->yawaf_get_page($page_name);
		return $page->getBody();
	}
	
	return $self->show();	
}

sub _getTmplDirs
{
	my $self = shift;
	my $tmpl = shift;
	my $app = shift;
	my $create = shift;
	
	my $src_dir;
	my $src_file;
	if ($tmpl =~ m#(.*)/(.*)#) {
		my $module_dir = $app->module_directory();
		$src_dir = "$module_dir/$1/tmpl/";
		$src_file = $2;
	}
	else {
		$src_dir = $app->tmpl_path();
		$src_file = $tmpl;
	}
	my $lang_dir = $app->L10N_dir();
	my $dir = "$src_dir$lang_dir/";
	mkdir $dir if !-e $dir && $create;
	my $lang = $app->getLanguage();
	$dir .= "$lang/";
	mkdir $dir if !-e $dir && $create;
	
	return ($src_dir,$src_file,$dir);
}

sub _saveLexicon
{
	my $src_file = shift;
	my $dst_file = shift;
	my $lex = shift;
	
#	die "src_file>$src_file dst_file>$dst_file";
	my $body;
	if (open (FILE,$src_file)) {
		read(FILE, $body, -s $src_file);
		close(FILE);
		while ($body =~ /{{(.*?)}}/) {
			my $phrase = $1;
			my $k = $1;
			if (exists $lex->{$k}) {
				$k = $lex->{$k};
			}
			$phrase =~ s/([\$\^\/\(\)[*.?])/\\$1/g;
			$body =~ s/{{$phrase}}/$k/;
		}
	}
	if (open (OUTFILE,">$dst_file.lex")) {
		while (my($key, $value) = each %$lex) {
			print OUTFILE '{{'.$key.'}}{{'.$value."}}\n";
		}
		close OUTFILE;
	}
	if (open (OUTFILE,">$dst_file")) {
		print OUTFILE $body;
		close OUTFILE;
	}
}

sub _loadLexicon
{
	my $file = shift;
	my $lex = shift;
	my $body;
	my %lex;
	if (open (FILE,"$file.lex")) {
		while (<FILE>) {
			/{{(.*)}}{{(.*)}}/;
			$lex->{$1} = $2;
		}
		close(FILE);
	}
}

sub _getPhrases
{
	my $body = shift;
	my $phraseHash = shift;
	while ($body =~ /{{(.*?)}}/) {
		my $phrase = $1;
		#only put up a field for the first instance of a text string
		if (!exists $phraseHash->{$phrase}) {
			$phraseHash->{$phrase} = 1;
		}
		$phrase =~ s/([\$\^\/\(\)[*.?])/\\$1/g;
		$body =~ s/{{$phrase}}//;
	}
}

1;