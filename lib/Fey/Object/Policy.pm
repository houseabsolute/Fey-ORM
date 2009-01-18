package Fey::Object::Policy;

use strict;
use warnings;

use List::Util qw( first );
use Moose;
use MooseX::AttributeHelpers;
use MooseX::StrictConstructor;
use MooseX::SemiAffordanceAccessor;

has '_transforms' =>
    ( metaclass => 'Collection::Array',
      is        => 'ro',
      isa       => 'ArrayRef[HashRef]',
      default   => sub { [] },
      init_arg  => undef,
      provides  => { push     => 'add_transform',
                     elements => 'transforms',
                   },
    );

has 'has_one_namer' =>
    ( is        => 'rw',
      isa       => 'CodeRef',
      predicate => 'has_has_one_namer',
    );

has 'has_many_namer' =>
    ( is        => 'rw',
      isa       => 'CodeRef',
      predicate => 'has_has_many_namer',
    );


sub transform_for_column
{
    my $self   = shift;
    my $column = shift;

    return first { $_->{matching}->($column) } $self->transforms();
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
