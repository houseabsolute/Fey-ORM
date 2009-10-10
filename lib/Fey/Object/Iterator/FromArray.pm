package Fey::Object::Iterator::FromArray;

use strict;
use warnings;

our $VERSION = '0.29';

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

with 'Fey::ORM::Role::Iterator';

my $iterable_arrayref =
    subtype
           as 'ArrayRef[ArrayRef[Object|Undef]]'
        => message { 'You must provide an array reference of which each '
                     . ' element is in turn an array reference. The inner '
                     . ' references should contain objects or undef.' };

coerce $iterable_arrayref
    => from 'ArrayRef[Object|Undef]',
    => via { [ map { [ $_ ] } @{$_} ] };

has '_objects' =>
    ( is       => 'ro',
      isa      => $iterable_arrayref,
      coerce   => 1,
      required => 1,
      init_arg => 'objects',
    );

sub _get_next_result
{
    my $self = shift;

    return $self->_objects()->[ $self->index() ];
}

sub reset
{
    my $self = shift;

    $self->_reset_index();
}

no Moose;
no Moose::Util::TypeConstraints;

__PACKAGE__->meta()->make_immutable();

1;

__END__

=head1 NAME

Fey::Object::Iterator::FromArray - An iterator which iterates over an array of objects

=head1 SYNOPSIS

  use Fey::Object::Iterator::FromArray;

  my $iter =
      Fey::Object::Iterator::Caching->new
          ( classes => 'MyApp::User',
            objects => \@users,
          );

  my $iter2 =
      Fey::Object::Iterator::Caching->new
          ( classes => [ 'MyApp::User', 'MyApp::Group' ],
            objects => [ [ $user1, $group1 ], [ $user2, $group1 ] ],
          );

  print $iter->index(); # 0

  while ( my $user = $iter->next() )
  {
      print $iter->index(); # 1, 2, 3, ...
      print $user->username();
  }

  # will return cached objects now
  $iter->reset();

=head1 DESCRIPTION

This class provides an object which does the
C<Fey::ORM::Role::Iterator> role, but gets its data from an array
reference. This lets you provide a single API that accepts data from
L<Fey::ORM>-created iterators, or existing data sets.

=head1 METHODS

This class provides the following methods:

=head2 $iterator->new()

The constructor requires two parameters, C<classes> and
C<objects>. The C<classes> parameter can be a single class name, or an
array reference of names.

The C<objects> parameter should be an array reference. That reference
can contain a list of objects, or an a list of array references, each
of which contains objects.

In either case, the objects must be subclasses of
L<Fey::Object::Table>.

=head2 $iterator->reset()

Resets the iterator so that the next call to C<< $iterator->next() >>
returns the first object(s).

=head1 ROLES

This class does the L<Fey::ORM::Role::Iterator> role.

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=head1 BUGS

See L<Fey::ORM> for details.

=head1 COPYRIGHT & LICENSE

Copyright 2009 Dave Rolsky, All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. The full text of the license
can be found in the LICENSE file included with this module.

=cut
