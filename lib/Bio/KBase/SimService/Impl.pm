package Bio::KBase::SimService::Impl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

=head1 NAME

Sim

=head1 DESCRIPTION

The similarity service exposes the SEED similarity server to the KBase. The
similarity server stores precomputed all-to-all BLAST similarities for a
large database of proteins; this database includes all genomes curated by the
SEED project as well as a variety of third-party protein databases (NCBI
nr, Uniprot/Swissprot, IMG, etc).

While the SEED similarity server does not itself have knowledge of proteins
with KBase identifiers, we use the MD5 signature of the protein sequence
to perform lookups into the similarity server. Similarities returned from
the similarity server are also identified with the MD5 signature, and are
mapped back to KBase identifiers using the information in the KBase Central Store.

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



=head2 sims

  $return = $obj->sims($ids, $options)

=over 4

=item Parameter and return types

=begin html

<pre>
$ids is a reference to a list where each element is a string
$options is an options
$return is a reference to a list where each element is a sim_vec
options is a reference to a hash where the following keys are defined:
	kb_only has a value which is an int
	kb_function2 has a value which is an int
	evalue_cutoff has a value which is a float
	max_sims has a value which is an int
sim_vec is a reference to a list containing 18 items:
	0: (id1) a string
	1: (id2) a string
	2: (iden) a float
	3: (ali_ln) an int
	4: (mismatches) an int
	5: (gaps) an int
	6: (b1) an int
	7: (e1) an int
	8: (b2) an int
	9: (e2) an int
	10: (psc) a float
	11: (bsc) a float
	12: (ln1) an int
	13: (ln2) an int
	14: (tool) a string
	15: (def2) a string
	16: (ali) a string
	17: (function2) a string

</pre>

=end html

=begin text

$ids is a reference to a list where each element is a string
$options is an options
$return is a reference to a list where each element is a sim_vec
options is a reference to a hash where the following keys are defined:
	kb_only has a value which is an int
	kb_function2 has a value which is an int
	evalue_cutoff has a value which is a float
	max_sims has a value which is an int
sim_vec is a reference to a list containing 18 items:
	0: (id1) a string
	1: (id2) a string
	2: (iden) a float
	3: (ali_ln) an int
	4: (mismatches) an int
	5: (gaps) an int
	6: (b1) an int
	7: (e1) an int
	8: (b2) an int
	9: (e2) an int
	10: (psc) a float
	11: (bsc) a float
	12: (ln1) an int
	13: (ln2) an int
	14: (tool) a string
	15: (def2) a string
	16: (ali) a string
	17: (function2) a string


=end text



=item Description

Retrieve precomputed protein similarities given a list of identifiers.

The options parameter allows simple configuration of the call. The following
values in the structure are interpreted:

 kb_only        Only return KBase identifiers (not raw MD5 or other external IDs).
 kb_function2   For KB identifiers, return the function mapped to id2.
 evalue_cutoff  Return similarities with an e-value better than this value.
 max_sims       Return at most this many similarities. The number of values
                may exceed this due to multiple identifiers mapping to the same sequence.

Each similarity returned is encapsulated in a sim_vec tuple. This tuple
contains the similar protein identifiers, as well as the columns as seen in the
blastall -m8 output..

The return is a list of tuples representing the similarity values. The indexes in the
tuple are defined as follows:

  0   id1        query sequence id
  1   id2        subject sequence id
  2   iden       percentage sequence identity
  3   ali_ln     alignment length
  4   mismatches  number of mismatch
  5   gaps       number of gaps
  6   b1         query seq match start
  7   e1         query seq match end
  8   b2         subject seq match start
  9   e2         subject seq match end
 10   psc        match e-value
 11   bsc        bit score
 12   ln1        query sequence length
 13   ln2        subject sequence length
 14   tool       tool used to produce similarities

All following fields may vary by tool:

 15   loc1       query seq locations string (b1-e1,b2-e2,b3-e3)
 16   loc2       subject seq locations string (b1-e1,b2-e2,b3-e3)
 17   dist       tree distance

We also return this column for any lookups when the kb_function2 flag
is enabled.

 18  function2   The function associated with id2 in the KBase.

=back

=cut

sub sims
{
    my $self = shift;
    my($ids, $options) = @_;

    my @_bad_arguments;
    (ref($ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"ids\" (value was \"$ids\")");
    (ref($options) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"options\" (value was \"$options\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to sims:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'sims');
    }

    my $ctx = $Bio::KBase::SimService::Service::CallContext;
    my($return);
    #BEGIN sims
    
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
    if ($options->{evalue_cutoff})
    {
	push(@params, [maxP => $options->{evalue_cutoff}]);
    }
    if ($options->{max_sims})
    {
	push(@params, [maxN => $options->{max_sims}]);
    }
    my $params = join("&", map { join("=", @$_) } @params);

    my $req_url = "$server_url?$params";

    my $resp = $ua->get($req_url);
    if (!$resp->is_success)
    {
	die "Request failed: " . $resp->status_line . "\n" . $resp->content;
    }

    $return = [];

    my $items = "IsProteinFor";
    my $ret_fields = "IsProteinFor(from_link) IsProteinFor(to_link)";
    if ($options->{kb_function2})
    {
	$items .= " Feature";
	$ret_fields .= " Feature(function)";
    }
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
	    push(@$return, [@items]);
	    # push(@$return, { 
	    # 	id1 => $id1,
	    # 	id2 => $id2,
	    # 	bit_score => $bsc,
	    # 	p_score => $psc,
	    # });
	}
	if ($id2 =~ /^gnl\|md5\|(.*)/)
	{
	    my @res = $self->{cdmi}->GetAll($items,
					    "IsProteinFor(from_link) = ?",
					    [$1],
					    $ret_fields);
            for my $ret (@res)
            {
                my($xid, $kb, $fn) = @$ret;
		my $tup = [$id1, $kb, @items[2..$#items]];
		if ($options->{kb_function2})
		{
		    $tup->[17] = $fn;
		}
		push(@$return, $tup);

		# push(@$return, { 
		#     id1 => $id1,
		#     id2 => $kb,
		#     bit_score => $bsc,
		#     p_score => $psc,
		# });
            }
	}
    }
    #END sims
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to sims:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'sims');
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



=head2 sim_vec

=over 4



=item Description

Each similarity returned is encapsulated in a sim_vec tuple. This tuple
contains the similar protein identifiers, as well as the columns as seen in the
blastall -m8 output..

The columns in the tuple are defined as follows:

  0   id1        query sequence id
  1   id2        subject sequence id
  2   iden       percentage sequence identity
  3   ali_ln     alignment length
  4   mismatches  number of mismatch
  5   gaps       number of gaps
  6   b1         query seq match start
  7   e1         query seq match end
  8   b2         subject seq match start
  9   e2         subject seq match end
 10   psc        match e-value
 11   bsc        bit score
 12   ln1        query sequence length
 13   ln2        subject sequence length
 14   tool       tool used to produce similarities

All following fields may vary by tool:

 15   loc1       query seq locations string (b1-e1,b2-e2,b3-e3)
 16   loc2       subject seq locations string (b1-e1,b2-e2,b3-e3)
 17   dist       tree distance

We also return this column for any lookups when the kb_function2 flag
is enabled:

 18  function2   The function associated with id2 in the KBase.


=item Definition

=begin html

<pre>
a reference to a list containing 18 items:
0: (id1) a string
1: (id2) a string
2: (iden) a float
3: (ali_ln) an int
4: (mismatches) an int
5: (gaps) an int
6: (b1) an int
7: (e1) an int
8: (b2) an int
9: (e2) an int
10: (psc) a float
11: (bsc) a float
12: (ln1) an int
13: (ln2) an int
14: (tool) a string
15: (def2) a string
16: (ali) a string
17: (function2) a string

</pre>

=end html

=begin text

a reference to a list containing 18 items:
0: (id1) a string
1: (id2) a string
2: (iden) a float
3: (ali_ln) an int
4: (mismatches) an int
5: (gaps) an int
6: (b1) an int
7: (e1) an int
8: (b2) an int
9: (e2) an int
10: (psc) a float
11: (bsc) a float
12: (ln1) an int
13: (ln2) an int
14: (tool) a string
15: (def2) a string
16: (ali) a string
17: (function2) a string


=end text

=back



=head2 options

=over 4



=item Description

Option specification. The following options are available for the sims call:

  kb_only        Only return KBase identifiers (not raw MD5 or other external IDs).
  kb_function2   For KB identifiers, return the function mapped to id2.
  evalue_cutoff  Return similarities with an e-value better than this value.
  max_sims       Return at most this many similarities. The number of values
                 may exceed this due to multiple identifiers mapping to the same sequence.


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
kb_only has a value which is an int
kb_function2 has a value which is an int
evalue_cutoff has a value which is a float
max_sims has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
kb_only has a value which is an int
kb_function2 has a value which is an int
evalue_cutoff has a value which is a float
max_sims has a value which is an int


=end text

=back



=cut

1;
