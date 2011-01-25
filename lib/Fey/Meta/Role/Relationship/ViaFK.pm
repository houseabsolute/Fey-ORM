package Fey::Meta::Role::Relationship::ViaFK;

use strict;
use warnings;
use namespace::autoclean;

use Moose::Role;

has 'fk' => (
    is        => 'ro',
    isa       => 'Fey::FK',
    lazy      => 1,
    builder   => '_build_fk',
);

sub _build_fk {
    my $self = shift;

    my $is_has_many = ( ref $self ) =~ /HasMany/;
    $self->_find_one_fk_between_tables(
        $self->table(),
        $self->foreign_table(),
        $is_has_many,
    );
}

1;
