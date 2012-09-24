package SimImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

=head1 NAME

Sim

=head1 DESCRIPTION



=cut

#BEGIN_HEADER
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Request::Common;

use Bio::KBase::CDMI::CDMI;
#END_HEADER

sub new
{
    my($class, @args) = @_;
    my $self = {
    };
    bless $self, $class;
    #BEGIN_CONSTRUCTOR
    $self->{cdmi} = Bio::KBase::CDMI::CDMI->new();

    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
}

=head1 METHODS



=head2 get_sims

  $return = $obj->get_sims($ids, $options)

=over 4

=item Parameter and return types

=begin html

<pre>
$ids is a reference to a list where each element is a string
$options is an options
$return is a reference to a list where each element is a sim
options is a reference to a hash where the following keys are defined:
	kb_only has a value which is an int
sim is a reference to a hash where the following keys are defined:
	id1 has a value which is a string
	id2 has a value which is a string
	bit_score has a value which is a float
	p_score has a value which is a float

</pre>

=end html

=begin text

$ids is a reference to a list where each element is a string
$options is an options
$return is a reference to a list where each element is a sim
options is a reference to a hash where the following keys are defined:
	kb_only has a value which is an int
sim is a reference to a hash where the following keys are defined:
	id1 has a value which is a string
	id2 has a value which is a string
	bit_score has a value which is a float
	p_score has a value which is a float


=end text



=item Description

Retrieve similarities for a set of identifiers.

=back

=cut

sub get_sims
{
    my $self = shift;
    my($ids, $options) = @_;

    my @_bad_arguments;
    (ref($ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"ids\" (value was \"$ids\")");
    (ref($options) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"options\" (value was \"$options\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_sims:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_sims');
    }

    my $ctx = $SimServer::CallContext;
    my($return);
    #BEGIN get_sims
    
    my $ua = LWP::UserAgent->new();
    my $server_url = "http://sim-server.nmpdr.org/simserver/perl/sims.pl";

    #
    # Walk through the input ids and attempt to translate anything we can
    # to a MD5 identifier. 
    # 
    # If we have a kb identifier, do a CDMI lookup on the
    # Produces relationship to find the identifier on the 
    # ProteinSequence entity
    #

    my %map;
    my @qry;
    for my $id (@$ids)
    {
	if ($id =~ /^kb\|/)
	{
	    my @res = $self->{cdmi}->GetAll('Produces',
	    				    'Produces(from_link) = ?',
					    [$id],
					    'Produces(from_link) Produces(to_link)');
	    for my $ret (@res)
	    {
		my($xid, $md5) = @$ret;
		my $md5id = "gnl|md5|$md5";
		$map{$md5id} = $xid;
		push(@qry, $md5id);
	    }
	}
	else
	{
	    push(@qry, $id);
	}
    }
    #print Dumper(\@qry, \%map);

    my @params = map { [id => $_] } @qry;

    # $params will become:
    #   id=firstidfromlist&id=secondidfromlist 
    #

    if ($options->{kb_only})
    {
	push(@params, [select => 'raw']);
    }
    my $params = join("&", map { join("=", @$_) } @params);

    my $req_url = "$server_url?$params";

    my $resp = $ua->get($req_url);
    if (!$resp->is_success)
    {
	die "Request failed: " . $resp->status_line . "\n" . $resp->content;
    }

    $return = [];

    for my $line (split(/\n/, $resp->content))
    {
        my @items = split(/\t/, $line);
	my($id1, $id2, $bsc, $psc) = @items[0, 1, 10, 11];

	#
	# We need to map our translated names back to the original identifiers.
	# We also need to see if any of the md5 identifiers in id2 map to KBase 
	# identifiers, and expand them to the corresponding kbase identifiers.
	#

	$id1 = $map{$id1} if exists $map{$id1};

	if (!$options->{kb_only})
	{
	    push(@$return, { 
		id1 => $id1,
		id2 => $id2,
		bit_score => $bsc,
		p_score => $psc,
	    });
	}
	if ($id2 =~ /^gnl\|md5\|(.*)/)
	{
	    my @res = $self->{cdmi}->GetAll('IsProteinFor',
					"IsProteinFor(from_link) = ?",
					[$1],
					'IsProteinFor(from_link) IsProteinFor(to_link)');
            for my $ret (@res)
            {
                my($xid, $kb) = @$ret;
		push(@$return, { 
		    id1 => $id1,
		    id2 => $kb,
		    bit_score => $bsc,
		    p_score => $psc,
		});
            }
	}
    }

    #END get_sims
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_sims:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_sims');
    }
    return($return);
}




=head2 version 

  $return = $obj->version()

=over 4

=item Parameter and return types

=begin html

<pre>
$return is a string
</pre>

=end html

=begin text

$return is a string

=end text

=item Description

Return the module version. This is a Semantic Versioning number.

=back

=cut

sub version {
    return $VERSION;
}

=head1 TYPES



=head2 sim

=over 4



=item Description

Each similarity returned is encapsulated in a sim data object.


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id1 has a value which is a string
id2 has a value which is a string
bit_score has a value which is a float
p_score has a value which is a float

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id1 has a value which is a string
id2 has a value which is a string
bit_score has a value which is a float
p_score has a value which is a float


=end text

=back



=head2 options

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
kb_only has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
kb_only has a value which is an int


=end text

=back



=cut

1;
