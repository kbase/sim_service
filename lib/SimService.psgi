use Bio::KBase::SimService::Impl;

use Bio::KBase::SimService::Service;



my @dispatch;

{
    my $obj = Bio::KBase::SimService::Impl->new;
    push(@dispatch, 'Sim' => $obj);
}


my $server = Bio::KBase::SimService::Service->new(instance_dispatch => { @dispatch },
				allow_get => 0,
			       );

my $handler = sub { $server->handle_input(@_) };

$handler;
