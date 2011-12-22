#-------------------------------------------------------------------------------
# PAGE::Wiki.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# This software is released under the LGPL license.
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package PAGE::Wiki;

use strict;

use base 'PAGE::Edit';
use sendmail;

sub _initialize
{
	my $self = shift;
	$self->SUPER::_initialize;

	$self->{'methods'}->{'preview'} = 1;	
	$self->{'methods'}->{'updateall'} = 1;	
	$self->{'methods'}->{'render'} = 1;
	$self->{'default_method'} = 'render';
}

sub updateall
{
	my $self = shift;
	my $sql = $self->param('sql');
	my $app = $self->param('app');
	my $p = $self->{'params'};
	my $table = $p->{'table'};
	my $returnPage = $p->{'canUpdateAll'};
	return $app->yawaf_get_page('noPrivs')->getBody()
		if $returnPage eq '';
	my $recordsP = $sql->GetRecords($table,'',['id','filename']);
	my $recordP;
	foreach $recordP (@$recordsP) {
		$self->deleteAllTemplatePairs();
		my $html = $self->render(1,$recordP->{'id'});
		my $file = $p->{'staticDir'}.'/'.$recordP->{'filename'};
		&writeFile($file,$html);
	}
	$app->query->delete_all;
	return $app->yawaf_get_page($returnPage)->getBody();
}

sub preview
{
	my $self = shift;
	my $sql = $self->param('sql');
	my $app = $self->param('app');
	my $q = $app->query();
	my $p = $self->{'params'};
	my $table = $p->{'table'};
	
	my $fields = $p->{'render_fields'};
	my $fields_wiki = $p->{'render_fields_wiki'};
	
	my $id = $self->_getID($q);
	my @f = @$fields;
	push @f,@$fields_wiki;
	my %record;
	my $passthru;
	foreach (@f) {
		my $v = $q->param($_);
		if (defined $v) {
			$record{$_} = $v;
		}
	}
	$q->param('m','submit');
	foreach ($q->param) {
		$passthru .= $q->hidden($_,$q->param($_))."\n";
	}
	$self->addTemplatePairs('_passthrufields',$passthru);
	$self->addTemplatePairs('is_preview',1);
	$self->addTemplatePairs('id',$id);

	my $output = $self->_render($table,$sql,$q,$p,$id,\%record,$fields,$fields_wiki,defined $p->{'staticDir'});
	return $output;
}

sub render
{
	my $self = shift;
	my $static_links = shift;
	my $id_override = shift;
	
	my $sql = $self->param('sql');
	my $app = $self->param('app');
	my $q = $app->query();
	my $p = $self->{'params'};
	my $table = $p->{'table'};
	
	my $fields = $p->{'render_fields'};
	my $fields_wiki = $p->{'render_fields_wiki'};
	
	my $id = ($id_override != 0)?$id_override:$self->_getID($q);
	my $recordP;
	my $where;
	my @f = @$fields;
	push @f,@$fields_wiki;
	if ($id != 0) {
		$where = 'id='.$id;
		$self->addTemplatePairs('id',$id);
	}
	else {
		my $n = $q->param('name');
		$n = 'Home' if $n eq '';
		my $name_name = $p->{'name_of_name_field'};
		$where = "$name_name=".$sql->Quote($n); 
		push @f,'id';
	}
	$recordP = $sql->GetRecord($table,$where,@f);

	return $self->_render($table,$sql,$q,$p,$id,$recordP,$fields,$fields_wiki,$static_links);
}

sub _render
{
	my $self = shift;
	my $table = shift;
	my $sql = shift;
	my $q = shift;
	my $p = shift;
	my $id = shift;
	my $recordP = shift;
	my $fields = shift;
	my $fields_wiki = shift;
	my $static_links = shift;
	
	my $sql = $self->param('sql');

	if (defined($recordP)) {
		if ($id == 0) {
			$id = $recordP->{'id'};
		}
		foreach (@$fields) {
			$self->addTemplatePairs($_ => $recordP->{$_});
		}
		foreach (@$fields_wiki) {
			$self->addTemplatePairs($_ => $self->renderField($recordP->{$_}));
		}
		$self->addTemplatePairs('id' => $id);
		if ($static_links) {
			my $filename = $q->param('filename');
			if ($filename eq '' && $id != 0) {
				my $recordP = $sql->GetRecord($table,'id='.$id,'filename');
				if (defined $recordP) {
					$filename = $recordP->{'filename'};
				}
			}
			if ($filename ne '') {
				$filename =~ s/\..*//;  #get rid of suffix
				if ($filename =~ m#(.*)/#) { #if the file is in a directory, add directory to the template pairs
					$self->addTemplatePairs("dir_".$1 => 1);
				}
				$self->addTemplatePairs($filename => 1);
			}
		}
		my $rq = $p->{'render_querries'};
		if (defined $rq) {
			my $rp = (ref ($rq) eq 'HASH')?[$rq]:$rq;
			foreach my $qp (@$rp) {
				my $rP = $sql->doSQLsearch($qp,$q,undef,undef,undef,"$table.id = $id");
				if (exists $qp->{'singleRecordQuery'}) {
					my $hP = $rP->[0];
					foreach (keys %$hP) {
						$self->addTemplatePairs($_ => $hP->{$_});
					}
				}
				else {
					$self->addTemplatePairs(
						$qp->{'name'} => $rP,
						'_count' => scalar @$rP
					);
				}
			}
		}
	}
	my $output = PAGE::show($self,$p->{'render_tmpl'}.'.html');
	my $h = $q->param('__hilite');
	if ($h ne '') {
		$output =~ s#($h)#<span class=hilite>$1</span>#gi;
	}
	if ($static_links) {
		my $pn = $self->page_name;
		my $nn = $p->{'name_of_name_field'};
		while ($output =~ /\?p=$pn&m=render&$nn=(.*?)"/) {
			my $name = $1;
			my $recordP = $sql->GetRecord($table,"$nn='$name'",'filename');
			$output =~ s/\?p=$pn&m=render&$nn=$name/\/$recordP->{'filename'}/g;
		}
	}
	return $output;
}

sub renderField
{
	my $self = shift;
	my $source = shift;
	return $source if $source eq '';
	my @parsed_fragments;
	foreach my $src (split(/(~~np.*?np~~)/s,$source)) {
		if ($src =~ /~~np(.*?)np~~/s) {
			push @parsed_fragments,$1;
		}
		else {
			$src =~ s/\r\n/\n/g;
			$src =~ s/\r/\n/g;
		
			while ($src =~ s/^:(:*)/\1&nbsp;&nbsp;&nbsp;&nbsp;/mg) {};  #tabs 
			my $page_name = $self->page_name;
			$src =~ s/\(\((.*?)\|(.*?)\)\)/<a href="?p=$page_name&m=render&name=$1">$2<\/a>/g;
			$src =~ s/\(\((.*?)\)\)/<a href="?p=$page_name&m=render&name=$1">$1<\/a>/g;
			$src =~ s/\{\{(.*?)\|(.*?)\}\}/<a href="$1">$2<\/a>/g;
			$src =~ s/\{\{(.*?)\}\}/<a href="$1">$1<\/a>/g;
			$src =~ s#\[\[(.*?)\]\]#<img src="$1" class="wiki_img" />#g;
			$src =~ s#\[((right)|(left))*\[(.*?)\]\]#<img src="$4" align="\1" class="wiki_img" />#gi;

			#convert any underscores inside tags to ~&~ for replacing later so that the bold wiki markup
			# doesn't clobber it.
			while ($src =~ s#(<[^>]*)_([^>]*>)#\1~%~\2#gm) {};

			$src =~ s/~~(.*?):(.*?)~~/<font color="$1">$2<\/font>/g;
			$src =~ s/_(.*?)_/<span class="wiki_italic">$1<\/span>/mg;
			$src =~ s/\*(.*?)\*/<span class="wiki_bold">$1<\/span>/g;
			$src =~ s/__(.*?)__/<span class="wiki_bolditalic">$1<\/span>/g;
			$src =~ s/^!!!!(.*?)$/<span class="wiki_head4">$1<\/span>/mg;
			$src =~ s/^!!!(.*?)$/<span class="wiki_head3">$1<\/span>/mg;
			$src =~ s/^!!(.*?)$/<span class="wiki_head2">$1<\/span>/mg;
			$src =~ s/^!(.*?)$/<span class="wiki_head1">$1<\/span>/mg;
			$src =~ s/^([^+#].*)$/$1<br>/mg;
			$src =~ s/^$/<br>/mg;
			$src =~ s/^----<br>\n/<hr>/mg;
			$src =~ s#([^"])(https*://[^<\s]+)#$1<a href="$2">$2</a>#mg;
			$src =~ s#~%~#_#gm;
			
			#tables
			while ($src =~ /\|\|(.*?)\|\|/s) {
				my $rows = $1;
				my @rows = split /^/,$rows;
				$rows  = '';
				foreach (@rows) {
					my @cols = split(/\|/);
					my $cells;
					foreach (@cols) {
						$rows .= '<td>'.$_.'</td>';
					}
					$rows .= '<tr>'.$cells.'</tr>';
				}
				$src =~ s#\|\|(.*?)\|\|#<table class="wiki_table">$rows</table>#s;
			}
		
			my @s;
			my $sl;
			foreach my $l (split /^/,$src) {
				my $t;
				if ($l =~ s/^(#|\+)//) {
					$t = ($1 eq '#')?'o':'u';
				}
				if ($sl ne '' && ($t eq '' or $sl ne $t)) {
					push @s,'</'.$sl.'l>';
					$sl = '';
				}
				if ($t ne '') {
					if ($sl eq '') {
						$sl = $t;
						push @s,'<'.$t.'l>';
					}
					$l = "<li>$l</li>";
				}
				push @s,$l;
			}
			push @s,'</'.$sl.'l>' if $sl ne '';
			
			foreach my $l (@s) {
				if ($l =~ /^ (.+?)<br>$/) {   #lines that start with a space are <tt>
					$l = $1;
					$l =~ s/</\&lt;/g;
					$l =~ s/>/\&gt;/g;
					$l = "<tt>$l</tt><br>";
				}
			}	
			push @parsed_fragments,join '',@s;
		}
	}
	return join '',@parsed_fragments;
}

sub beforeUpdate
{
	my $self = shift;
	my $id = shift;
	my $pairsP = shift;
	
	$pairsP->{'modified'} ='NOW()';
	return 1;
}

sub doStaticSave
{
	my $self = shift;
	my $id = shift;
	my $pairsP = shift;
	my $q = shift;
	my $sql = shift;
	
	my $p = $self->{'params'};
	if ($p->{'staticDir'} ne '') {
		my $recordP = $sql->GetRecord($p->{'table'},'id='.$id,'filename');
		if (defined $recordP) {
			my $html = $self->render(1,$id);
			my $file = $p->{'staticDir'}.'/'.$recordP->{'filename'};
			&writeFile($file,$html);
		}
	}
}

sub afterCreate
{
	my $self = shift;
	my $id = shift;
	my $pairsP = shift;
	my $q = shift;
	my $sql = shift;
	$self->doStaticSave($id,$pairsP,$q,$sql);
}

sub afterUpdate
{
	my $self = shift;
	my $id = shift;
	my $pairsP = shift;
	my $q = shift;
	my $sql = shift;
	
	$self->doStaticSave($id,$pairsP,$q,$sql);
	
	return if $q->param('_skipnotify') ne '';
	my @notify = $q->param('notify');
	if (@notify) {
		grep($_="id = $_",@notify);
		my $sql = $self->param('sql');
		my $recordsP = $sql->GetRecords($self->param('app')->param('account_table'),join(' or ',@notify),['email']);
		my @recipients;
		foreach (@$recordsP) {
			push @recipients,$_->{'email'};
		}
		
		my $who = $self->param('app')->param('user_info')->{'fname'};
		
		my $notes = $pairsP->{'notes'};
		if ($notes ne '') {
			$notes =~ s/'(.*)'/$1/s;
			$notes =~ s/\\'/'/g;			
			$notes = "\n\nNotes: $notes" ;
		}
		my $p = $self->{'params'};
		my $page_name = $self->page_name();
		my $message = << "EOM";
Subject: $pairsP->{$p->{'name_of_name_field'}} page updated by $who

Visit page: http://$ENV{'HTTP_HOST'}$ENV{'SCRIPT_NAME'}?p=$page_name&id=$id$notes
EOM
		my $result  = &sendmail($message,$p->{'mailhost'},$p->{'mailfrom'},@recipients);
	}
}

sub writeFile
{
	my $file_name = shift;
	my $data = shift;
	my $open_string = "> ";
	open(DATA, $open_string.$file_name) ||
		die("Sorry, I couldn't open file '$file_name' to save data. Are you sure the directory exists? (System Error is: $!)\n");
	print DATA $data;
	close(DATA);
}
1;
