package Fey::Object::Policy;

use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '0.47';

use Fey::ORM::Types qw( ArrayRef CodeRef HashRef );
use List::Util qw( first );

use Moose;
use MooseX::StrictConstructor;
use MooseX::SemiAffordanceAccessor;

has '_transforms' => (
    traits   => ['Array'],
    is       => 'ro',
    isa      => ArrayRef [HashRef],
    default  => sub { [] },
    init_arg => undef,
    handles  => {
        add_transform => 'push',
        transforms    => 'elements',
    },
);

has 'has_one_namer' => (
    is       => 'rw',
    isa      => CodeRef,
    default  => \&_dumb_namer,
    required => 1,
);

has 'has_many_namer' => (
    is       => 'rw',
    isa      => CodeRef,
    default  => \&_dumb_namer,
    required => 1,
);

sub transform_for_column {
    my $self   = shift;
    my $column = shift;

    return first { $_->{matching}->($column) } $self->transforms();
}

sub _dumb_namer {
    return sub { lc $_[0]->name() };
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: An object representing a specific policy

__END__

=pod

=head1 DESCRIPTION

This class provides the non-sugar half of L<Fey::ORM::Policy>. It's
probably not interesting unless you're interested in the guts of how
L<Fey::ORM> works.

=head1 METHODS

This class accepts the following methods:

=head2 $policy->add_transform( matching => sub { ... }, inflate => sub { ... }, deflate => sub { ... } )

Stores a transform as declared in L<Fey::ORM::Policy>

=head2 $policy->transform_for_column($column)

Given a L<Fey::Column>, returns the first transform (as a hash
reference) for which the C<matching> sub returns true.

=head2 $policy->transforms()

Returns all of the transforms for the policy.

=head2 $policy->has_one_namer()

Returns the naming sub for C<has_one()> methods. Defaults to:

  sub { lc $_[0]->name() }

=head2 $policy->set_has_one_namer($sub)

Sets the naming sub for C<has_one()> methods.

=head2 $policy->has_many_namer()

Returns the naming sub for C<has_many()> methods. Defaults to:

  sub { lc $_[0]->name() }

=head2 $policy->set_has_many_namer($sub)

Sets the naming sub for C<has_many()> methods.

=cut
