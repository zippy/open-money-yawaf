package Session;

use strict;
use SQL;
use Digest::MD5  qw(md5 md5_hex md5_base64);

$Session::index = 0;

sub new {
	my $class = shift;
	my $sql = shift;
	my $session_id = shift;
	my $user_id = shift;
	my $session_timeout = shift;  #default value is thus 0 which means "never"
	my $session_table = shift;
	
	my $self = {};
	bless $self, $class;
	my $time = time;

	$session_table =  'sessions' if ($session_table eq '');
	
	$self->{'_table_name'} = $session_table;

	$self->{'sql'} = $sql;
	if ($session_id eq '') {
        $session_id = md5_hex($user_id.time.$Session::index++);
		$self->{'id'} = $session_id;
		$sql->InsertRecord($session_table,{
			'id' => $session_id,
			'user_id' => $user_id,
			'time' => $time
			},0);
	}
	else {
		
		#exipire old sessions 
		$sql->DeleteRecords($session_table,'time < '.($time-$session_timeout)) if $session_timeout > 0;

		my $where = 'id='.$sql->Quote($session_id);
		my $recordP = $sql->GetRecord($session_table,$where,'user_id');
		if ($recordP != undef) {
			$sql->UpdateRecords($session_table,{'time' => $time},$where);
			$self->{'id'} = $session_id;
			$self->{'user_id'} = $recordP->{'user_id'};
		}
		else {
			return undef;
		}
	}
	
	return $self;
}

sub setUserId {
	my $self = shift;
	my $user_id = shift;
	
	$self->{'user_id'} = $user_id;
	my $sql = $self->{'sql'};
	$sql->UpdateRecords($self->{'_table_name'},{'user_id' => $user_id},'id='.$sql->Quote($self->{'id'}));
}

sub delete {
	my $self = shift;
	my $sql = $self->{'sql'};
	$sql->DeleteRecords($self->{'_table_name'},'id='.$sql->Quote($self->{'id'}));
}

1;
