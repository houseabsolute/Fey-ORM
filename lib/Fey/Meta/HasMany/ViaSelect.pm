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

__END__

=head1 NAME

Fey::Meta::HasMany::ViaSelect - A parent for has-one metaclasses based on a C<Fey::SQL::Select> object

=head1 DESCRIPTION

This class implements a has-one relationship for a class, based on a
provided (or deduced) C<Fey::SQL::Select> object.

=head1 CONSTRUCTOR OPTIONS

This class accepts the following constructor options:

=over 4

=item * select

The C<Fey::SQL::Select> object which defines the relationship between
the tables.

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

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=head1 BUGS

See L<Fey::ORM> for details.

=head1 COPYRIGHT & LICENSE

Copyright 2006-2009 Dave Rolsky, All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. The full text of the license
can be found in the LICENSE file included with this module.

=cut
