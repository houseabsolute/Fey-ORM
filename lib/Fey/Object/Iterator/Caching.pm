package Fey::Object::Iterator::Caching;

use strict;
use warnings;

use Moose;
use MooseX::AttributeHelpers;
use MooseX::StrictConstructor;

extends 'Fey::Object::Iterator';

has _cached_results =>
    ( metaclass => 'Collection::Array',
      is        => 'ro',
      isa       => 'ArrayRef[ArrayRef]',
      lazy      => 1,
      default   => sub { [] },
      provides  => { push => '_cache_result',
                     get  => '_get_cached_result',
                   },
    );


sub next
{
    my $self = shift;

    my $result = $self->_get_cached_result( $self->index() );

    unless ($result)
    {
        $result = $self->_get_next_result();

        return unless $result;

        $self->_cache_result($result);
    }

    $self->_inc_index();

    return wantarray ? @{ $result } : $result->[0];
}

sub reset
{
    my $self = shift;

    $self->_reset_index();
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__

=head1 NAME

Fey::Object::Iterator::Caching - A caching subclass of Fey::Object::Iterator

=head1 SYNOPSIS

  use Fey::Object::Iterator::Caching;

  my $iter =
      Fey::Object::Iterator::Caching->new
          ( classes     => 'MyApp::User',
            handle      => $sth,
            bind_params => \@bind,
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

This class implements a caching subclass of
C<Fey::Objcet::Iterator>. This means that it caches objects it creates
internally. When C<< $iterator->reset() >> is called it will re-use
those objects before fetching more data from the DBMS.

=head1 METHODS

This class provides the following methods:


=head2 $iterator->next()

This returns the next set of objects. If it has a cached set of
objects for the appropriate index, it returns them instead of fetching
more data from the DBMS. Otherwise it is identical to calling
C<next()> on a C<Fey::Object::Iterator> object.

=head2 $iterator->reset()

Resets the iterator so that the next call to C<< $iterator->next() >>
returns the first objects. Internally, this I<does not> reset the
C<DBI> statement handle, it simply makes the iterator use cached
objects.

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=head1 BUGS

See L<Fey::ORM> for details.

=head1 COPYRIGHT & LICENSE

Copyright 2006-2008 Dave Rolsky, All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. The full text of the license
can be found in the LICENSE file included with this module.

=cut
