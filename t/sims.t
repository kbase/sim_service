use strict;
use warnings;

use Test::More tests => 15;
use Data::Dumper;

use Bio::KBase::SimService::Client;
my $obj;
my $return;
my @id_keys;

my ($pid, $url) = Server::start('SimService');

#
#  Test 1 - Can a new object be created without parameters? 
#
#$obj = Bio::KBase::SimService::Client->new($url); # create a new object
$obj = Bio::KBase::SimService::Client->new(); # create a new object
ok( defined $obj, "Did an object get defined" );               

#
#  Test 2 - Is the object in the right class?
#
isa_ok( $obj, 'Bio::KBase::SimService::Client', "Is it in the right class" );   

#
#  Test 3 - Can the object do all of the methods
#

can_ok($obj, qw[    
	sims
]);

#
#  Test 4 - Can a new object be created with valid parameter? 
#


#my $sim_server_url = "http://localhost:7055/";
#my $sim_server_url = "http://bio-data-1.mcs.anl.gov/services/idserver";
my $sim_server = Bio::KBase::SimService::Client->new($url);
ok( defined $sim_server, "Did an object get defined" );               
#
#  Test 5 - Is the object in the right class?
#
isa_ok( $sim_server, 'Bio::KBase::SimService::Client', "Is it in the right class" );   

#
#  METHOD: external_ids_to_kbase_ids
#
note("Test   sims");

my $id = "kb|g.0.peg.4";
my $options = {};

#-- Tests 6 and 7 - Too many and too few parameters
eval {$return = $sim_server->sims([$id], $options, 'EXTRA')};
isnt($@, undef, 'Call with too many parameters failed properly');

eval {$return = $sim_server->sims([$id]);  };
isnt($@, undef, 'Call with too few parameters failed properly');

#-- Tests 8 and 9 - Use invalid data.  Expect empty array to be returned
$return = $sim_server->sims(['abcdefghijkl'], $options);
is(ref($return), 'ARRAY', "Use InValid data:  sims returns a list");

is(@$return, 0, "Give no input: Hash is empty -- No warning");

#-- Tests 10 and 11 - Use Valid data.  Expect array with data to be returned
$return = $sim_server->sims([$id], $options);
is(ref($return), 'ARRAY', "Use Valid data: sims returns a list");

isnt(scalar @$return, 0, "Use Valid data: list is not empty");

#-- Test 12 - Are there non KB IDs in the return
my @non_kb = grep { $_->[1] !~ /^kb\|/ } @$return;

isnt(@non_kb, 0, "Use valid data (non kb-only): non KB ids appeared");

#-- Test 13-15 - Repeat tests 10-12 with kb_only option
#   Expect only KB IDs to be returned
$options->{kb_only} = 1;

$return = $sim_server->sims([$id], $options);
is(ref($return), 'ARRAY', "Use Valid data: sims returns a list");

isnt(scalar @$return, 0, "Use Valid data: list is not empty");

@non_kb = grep { $_->[1] !~ /^kb\|/ } @$return;

is(scalar @non_kb, 0, "Use valid data (kb-only): only KB ids appeared");

done_testing();
Server::stop($pid);

package Server;
use Plack::Runner;
use IO::Socket::INET;

sub start {
  my $service = shift;

  #
  # Find an unused port.
  #
  my $port;
  {
     my $sock = IO::Socket::INET->new('LocalPort' => 0);
     $sock->listen;
     $port = $sock->sockport;
     $sock->close();
  }

  #
  # Fork and create service.
  #
  my $child_pid = fork;
  if ($child_pid == 0)
  {
     my $runner = Plack::Runner->new();
     $runner->parse_options("--listen", "0:$port");
     $runner->run("lib/$service.psgi");
     exit;
  }

  #
  # Wait for server to start.
  #
  sleep 5;
  return ($child_pid, "http://localhost:$port");

}


sub stop {

  my($child_pid, $url) = shift;
  kill 1, $child_pid;

}

__DATA__
#
# Tests leftover from another module which may be used to create tests
# for this module.  None of the methods below apply to this module.
#
$test_kbase_id = $return->{$id_keys[0]};  ### ID to test kbase_ids_to_external_ids

#-- Tests 12 and 13 - Use Array with both Valid and invalid data.  
#   Expect hash with data to be returned
$return = $sim_server->external_ids_to_kbase_ids('SEED', [$test_seed_id, 'fig|83333.1.peg.4.?', 'fig|1000565.3.peg.3']);
is(ref($return), 'HASH', "Use Valid data: external_ids_to_kbase_ids returns a hash");

@id_keys = keys(%$return);
#print Dumper($return);
isnt(scalar @id_keys, 0, "Use Valid data: hash is not empty");

#-- Tests 14 Is the return value scalar.  
foreach (@id_keys)
{
#	print "$_\t$return->{$_}\n";
	is(ref($return->{$_}), '', "Is the return value scalar for $_?");
	last;
}

#
#  METHOD: kbase_ids_to_external_ids
#
note("Test  kbase_ids_to_external_ids");

#-- Tests 15 and 16 - Too many and too few parameters
eval {$return = $sim_server->kbase_ids_to_external_ids('SEED',['kb|g.3.peg.2394.?']);  };
isnt($@, undef, 'Call with too many parameters failed properly');

eval {$return = $sim_server->kbase_ids_to_external_ids();  };
isnt($@, undef, 'Call with too few parameters failed properly');

#-- Tests 17 and 18 - Use invalid data.  Expect empty hash to be returned
$return = $sim_server->kbase_ids_to_external_ids(['kb|g.3.peg.2394.?']);
is(ref($return), 'HASH', "Use InValid data: external_ids_to_kbase_ids returns a hash");

is(keys(%$return), 0, "Give no input: Hash is empty -- No warning");

#-- Tests 19 and 20 - Use Valid data.  Expect hash with data to be returned
$return = $sim_server->kbase_ids_to_external_ids([$test_kbase_id]);
is(ref($return), 'HASH', "Use Valid data: external_ids_to_kbase_ids returns a hash");

@id_keys = keys(%$return);
is(scalar @id_keys, 1, "Use Valid data: hash has one element");

#-- Tests 21-23 
#   21 is the return an array
#   22 and 23 are the two items in the array the external_db and external_id  
foreach (@id_keys)
{
	is(ref($return->{$_}), 'ARRAY', "Is the return value scalar for $_?");
	is($return->{$_}->[0], 'SEED', "Is the external_db SEED");
	is($return->{$_}->[1], $test_seed_id, "Is the external_id $test_seed_id");

}

#-- Tests 24 and 25 - Use Array with both Valid and invalid data.  
 #  Expect hash with data to be returned
$return = $sim_server->kbase_ids_to_external_ids([$test_kbase_id,$test_kbase_id, '3']);
#print Dumper($return);

is(ref($return), 'HASH', "Use Valid data: external_ids_to_kbase_ids returns a hash");

@id_keys = keys(%$return);
is(scalar @id_keys, 1, "Use Valid data: hash is not empty");

#
#  METHOD: register_ids
#
note("Test  register_ids");

#-- Tests 26 and 27 - Too many and too few parameters
eval {$return = $sim_server->register_ids('SEED','SEED','SEED','SEED');  };
isnt($@, undef, 'Call with too many parameters failed properly');

eval {$return = $sim_server->register_ids('SEED','SEED');  };
isnt($@, undef, 'Call with too few parameters failed properly');

#-- Tests 28 and 29 -  Test with a valid ID from above
#   Expect a return KBase that was found above (no double registration)
#   Expect one key to the hash and its value is known
$return = $sim_server->register_ids('TEST','SEED',[$test_seed_id]);
is(ref($return), 'HASH', "Register_ids returns a hash");

@id_keys = keys(%$return);
is(scalar @id_keys, 1, "Use Valid data: hash has one element");

#-- Tests  30 and 31
#   Are the return values correct?

is($id_keys[0], $test_seed_id, 'Is the key the ID that was registered');
is($return->{$id_keys[0]}, $test_kbase_id, "Is the value the associated KBASE ID");

#-- Tests 32 and 33 -  Test with a valid ID from above but the database is wrong
#   Expect a new KBase ID

$return = $sim_server->register_ids('TEST','seed',[$test_seed_id]);
is(ref($return), 'HASH', "Register_ids returns a hash");

@id_keys = keys(%$return);
is(scalar @id_keys, 1, "Use Valid data: hash has one element");

#-- Tests  34-35
#   Test what was returned.  Needs to be new registration ID, not the one above
foreach (@id_keys)
{
#       print "KEY=$_ VALUE=$return->{$_} \n";
	is($_, $test_seed_id, 'Is the key the ID that was registered');
	isnt($return->{$_}, $test_kbase_id, "Is the value IS NOT the associated KBASE ID");
}

#- Tests with bogus test data -
#  Expect new registration ID

$return = $sim_server->register_ids('TEST','SEED',['XXXXX']);
@id_keys = keys(%$return);

#-- Tests  36-40 - With new bogus data, get back what we asked for

foreach (@id_keys)
{
#        print "KEY=$_ VALUE=$return->{$_} \n";
	my $return = $sim_server->kbase_ids_to_external_ids([$return->{$_}]);
	is(ref($return), 'HASH', "Use Valid data: external_ids_to_kbase_ids returns a hash");
	my @id_keys = keys(%$return);
	is(scalar @id_keys, 1, "Use Valid data: hash has one element");

	foreach (@id_keys)
	{
		is(ref($return->{$_}), 'ARRAY', "Is the return value scalar for $_?");
		is($return->{$_}->[0], 'SEED', "Is the external_db SEED");
		is($return->{$_}->[1], 'XXXXX', "Is the external_id XXXXX");
	}
}


#
#  METHOD: allocate_id_range
#
note("Test allocate_id_range");

#-- Tests 41 and 42 - Too many and too few parameters
eval {$return = $sim_server->allocate_id_range('SEED','SEED','SEED');  };
isnt($@, '', 'Call with too many parameters failed properly');

eval {$return = $sim_server->allocate_id_range('SEED');  };
isnt($@, '', 'Call with too few parameters failed properly');

#-- Tests 43-44 invalid and valid numberic parameter
eval {$return = $sim_server->allocate_id_range('SEED','XX');  };
isnt($@, '', 'Second parameter needs to be a number');

eval {$return = $sim_server->allocate_id_range('SEED',3);  };
is($@, '', 'Second parameter needs to be a number');

#-- Tests 45
$return = $sim_server->allocate_id_range('TEST',2);
is(ref($return), '', "Register_ids returns a scalar");

my $return_test = $return;
$return_test    =~ s/\d+//g;

#-- Tests 46 - Must be a number
is($return_test, '', 'The return was a number');
$return_test = $return + 1;
my $test_hash = { 'external_id1'=> $return, 'external_id2'=> $return_test };

#
#  METHOD: register_allocated_ids
#
note("Test register_allocated_ids");

#-- Tests 47 and 48 - Too many and too few parameters
eval {$return = $sim_server->register_allocated_ids('SEED','SEED','SEED','SEED');  };
isnt($@, undef, 'Call with too many parameters failed properly');

eval {$return = $sim_server->register_allocated_ids('SEED','SEED');  };
isnt($@, undef, 'Call with too few parameters failed properly');

$return = $sim_server->register_allocated_ids('TEST','SEED', $test_hash); 

#-- Tests 49-52 - Test the data just added
$return = $sim_server->kbase_ids_to_external_ids(["TEST.$return_test"]);

@id_keys = keys(%$return);
is(scalar @id_keys, 1, "Return one key");

foreach (@id_keys)
{
        is(ref($return->{$_}), 'ARRAY', "Is the return value scalar for $_?");
        is($return->{$_}->[0], 'SEED', "Is the external_db SEED");
        is($return->{$_}->[1], 'external_id2', "Is the external_id external_id2");

}

#
#  Now what happens when we try to register more than the two allocated IDs
#    put in numbers that I have made up
#
$test_hash =  { 'external_id6' => 11111, 'external_id7' => 22222,  'external_id8' => 33333, 'external_id9' => 44444 };
$return = $sim_server->register_allocated_ids('TEST','SEED', $test_hash); 

#-- Tests 53 - Test data that is invalid
$return = $sim_server->kbase_ids_to_external_ids(["TEST.1111"]);
@id_keys = keys(%$return);
is(scalar @id_keys, 0, "Return zero keys if asking for invalid 1111");

#-- Tests 54-55 - Test the data just added
$return = $sim_server->kbase_ids_to_external_ids(["TEST.44444"]);
@id_keys = keys(%$return);
is(scalar @id_keys, 1, "Return one key if asking for 44444");
foreach (@id_keys)
{
        is($return->{$_}->[1], 'external_id9', "Is the external_id external_id9 - This was allocated");
}

my $foo = 'NAN';

$test_hash =  { 'external_id' => $foo };
$return = $sim_server->register_allocated_ids('TEST','SEED', $test_hash); 

#-- Tests 56-57 - Test the data just added
$return = $sim_server->kbase_ids_to_external_ids(["TEST.$foo"]);
@id_keys = keys(%$return);
is(scalar @id_keys, 1, "Return one key when asking for NAN");
foreach (@id_keys)
{
        is($return->{$_}->[1], 'external_id', "Used TEST.$foo and returned external_id (non-numeric test)");
}

#-- Tests 59-59 - Test the data just added
$foo = new String::Random;
my $foo2 = $foo->randregex('\d\d\d\d\d\d\d\d\d'); 

$test_hash =  { 'external_id' => $foo2 };
$return = $sim_server->register_allocated_ids('TEST','SEED', $test_hash); 
$return = $sim_server->kbase_ids_to_external_ids(["TEST.$foo2"]);
@id_keys = keys(%$return);
is(scalar @id_keys, 1, "Return one key when asking for large random number");
foreach (@id_keys)
{
        is($return->{$_}->[1], 'external_id', "Used TEST.$foo2 and returned external_id (large random number test)");
}
