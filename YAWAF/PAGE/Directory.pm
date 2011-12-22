#-------------------------------------------------------------------------------
# PAGE::Directory.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
#-------------------------------------------------------------------------------

package PAGE::Directory;

use strict;

use base 'PAGE';

sub _initialize
{
	my $self = shift;
	$self->SUPER::_initialize;
	
	$self->{'methods'}->{'deleteFile'} = 1;
	$self->{'methods'}->{'uploadFile'} = 1;
}

sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;
	my $p = $self->{'params'};
	$self->specErrorDie($page_name,'params undefined') if not defined($p);

	$self->SUPER::setup($page_name,$app);
}

sub show {
	my $self = shift;
	my $tmpl_override = shift;
	my $p = $self->{'params'};

	my $dir = $p->{'directory'};
	$dir .= '/' if $dir !~ m#/$#;
	
	my @files;

    opendir( DIR, $dir )
        or die "Can't open $dir: $!";
    
    while (my $f = readdir( DIR ) ) {
    	next if $f =~ /^\./;
    	next if -d $dir.$f;
    	push @files, {'name' => $f};
    }
    closedir( DIR );

	$self->addTemplatePairs(
		$p->{'name'} => \@files
	);
	$self->SUPER::show($tmpl_override);
}

sub deleteFile
{
	my $self = shift;
	my $app = $self->param('app');
	my $q = $app->query();
	my $p = $self->{'params'};
	my $file_name = $q->param('file_name');
	$file_name =~ s#^.*/##; #remove any leading path info so people don't cheat
	$file_name = "$p->{'directory'}/$file_name";
	unlink $file_name;
	return $self->show();
}

sub uploadFile
{
	my $self = shift;
	my $app = $self->param('app');
	my $q = $app->query();
	my $p = $self->{'params'};
	
	my $file_name = $q->param('file_name');
	my $fh = $q->upload('file_name');
	if (!$fh && $q->cgi_error) {
		die $q->header(-status=>$q->cgi_error);
	}
	#$type = $query->uploadInfo($filename)->{'Content-Type'};
	#unless ($type eq 'text/html') {
	#	die "HTML FILES ONLY!";
	#}
	if ($fh) {
		$file_name =~ s#^.*/##; #remove any leading path info
		open (OUTFILE,">$p->{'directory'}/$file_name");
		my $bytesread;
		my $buffer;
		while ($bytesread=read($fh,$buffer,1024)) {
			print OUTFILE $buffer;
		}
	}
	return $self->show();
}

1;