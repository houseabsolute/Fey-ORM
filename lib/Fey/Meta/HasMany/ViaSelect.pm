package Fey::Meta::HasMany::ViaSelect;

use strict;
use warnings;
use namespace::autoclean;

use Moose;
use MooseX::StrictConstructor;

with 'Fey::Meta::Role::Relationship::HasMany';

has 'select' => (
    is       => 'ro',
    does     => 'Fey::Role::SQL::ReturnsData',
    required => 1,
);

has 'bind_params' => (
    is  => 'ro',
    isa => 'CodeRef',
);

sub _make_iterator_maker {
    my $self = shift;

    return $self->_make_subref_for_sql(
        $self->select(),
        $self->bind_params(),
    );
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: A parent for has-one metaclasses based on a query object

__END__

=pod

=head1 DESCRIPTION

This class implements a has-one relationship for a class, based on a
provided (or deduced) query object.

=head1 CONSTRUCTOR OPTIONS

This class accepts the following constructor options:

=over 4

=item * select

An object which does the L<Fey::Role::SQL::ReturnsData> role. This query
defines the relationship between the tables.

=item * bind_params

An optional subroutine reference which will be called when the SQL is
executed. It is called as a method on the object of this object's
associated class.

=item * allows_undef

This defaults to true.

=back

=head1 METHODS

Besides the methods inherited from L<Fey::Meta::HasMany>, it also
provides the following methods:

=head2 $ho->select()

Corresponds to the value passed to the constructor.

=head2 $ho->bind_params()

Corresponds to the value passed to the constructor.

=cut
