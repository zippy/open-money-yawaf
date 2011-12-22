#-------------------------------------------------------------------------------
# sendmail.pm
# ©2001 Eric Harris-Braun
#-------------------------------------------------------------------------------

use strict;
package sendmail;

use Exporter;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(sendmail);

use Net::SMTP;

sub sendmail {
    my $message = shift;
    my $host = shift;
    my $sender= shift;
    my @recipients = @_;

	my $smtp = Net::SMTP->new($host);
#	my $o;

	if (defined $smtp) {
		$smtp->mail($sender,Hello => $host);
#		$o .= $smtp->message();
		foreach (@recipients) {
			$smtp->to($_);
#			$o .= $smtp->message();
		}
		$smtp->data($message);
#		$o .= $smtp->message();
		$smtp->quit();
#		$o .= $smtp->message();
		return 1;
	}
	return 0;
}

1;