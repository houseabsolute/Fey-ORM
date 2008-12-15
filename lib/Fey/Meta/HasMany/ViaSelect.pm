package Fey::Meta::HasMany::ViaSelect;

use strict;
use warnings;

use Moose;
use MooseX::StrictConstructor;

extends 'Fey::Meta::HasMany';


has 'select' =>
    ( is       => 'ro',
      isa      => 'Fey::SQL::Select',
      required => 1,
    );

has 'bind_params' =>
    ( is  => 'ro',
      isa => 'CodeRef',
    );

sub _make_iterator_maker
{
    my $self = shift;

    return
        $self->_make_subref_for_sql( $self->select(),
                                     $self->bind_params(),
                                   );
}


no Moose;

__PACKAGE__->meta()->make_immutable();

1;
