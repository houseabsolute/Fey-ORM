package Fey::Meta::Attribute::FromColumn;

use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '0.31';

use Moose;

extends 'Moose::Meta::Attribute';

has 'column' => (
    is       => 'ro',
    isa      => 'Fey::Column',
    required => 1,
);

# The parent class's constructor is not a Moose::Object-based
# constructor, so we don't want to inline one that is.
__PACKAGE__->meta()->make_immutable( inline_constructor => 0 );

1;

__END__

=head1 NAME

Fey::Meta::Attribute::FromColumn - an attribute metaclass for column-based attributes

=head1 SYNOPSIS

  package MyApp::Song;

  has_table( $schema->table('Song') );

  for my $attr ( grep { $_->can('column') } $self->meta()->get_all_attributes )
  {
      ...
  }

=head1 DESCRIPTION

This attribute metaclass is used when L<Fey::ORM::Table> creates
attributes for the class's associated table.

=head1 METHODS

This class adds a single method to those provided by
C<Moose::Meta::Attribute>:

=head2 $attr->column()

Returns the L<Fey::Column> object associated with this attribute.

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
