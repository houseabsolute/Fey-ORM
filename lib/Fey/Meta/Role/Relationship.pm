package Fey::Meta::Role::Relationship;

use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '0.48';

use Fey::ORM::Types qw( Bool CodeRef Str TableWithSchema );

use Moose::Role;

has associated_class => (
    is       => 'rw',
    isa      => 'Fey::Meta::Class::Table',
    writer   => '_set_associated_class',
    clearer  => '_clear_associated_class',
    weak_ref => 1,
    init_arg => undef,
);

has name => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_name',
);

has namer => (
    is       => 'ro',
    isa      => CodeRef,
    required => 1,
);

has table => (
    is       => 'ro',
    isa      => TableWithSchema,
    required => 1,
);

has foreign_table => (
    is       => 'ro',
    isa      => TableWithSchema,
    required => 1,
);

has is_cached => (
    is      => 'ro',
    isa     => Bool,
    lazy    => 1,
    builder => '_build_is_cached',
);

sub _build_name {
    my $self = shift;

    return $self->namer()->( $self->foreign_table(), $self );
}

1;

# ABSTRACT: A shared role for all foreign HasX metaclasses

__END__

=pod

=head1 DESCRIPTION

This role provides shared functionality for has-one and has-many
metaclasses. See the relevant classes for documentation.

=head1 CONSTRUCTOR OPTIONS

This role adds the following constructor options:

=over 4

=item * name

The name of the relationship. This will be used as the name for any
attribute or method created by this metaclass.

This defaults to C<< lc $self->foreign_table()->name() >>.

=item * table

The (source) table of the foreign key.

=item * foreign_table

The foreign table for the foreign key

=item * is_cached

Determines whether the relationship's value is cached. This is
implemented in different ways for has-one vs has-many relationships.

=back

=cut
