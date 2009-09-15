package Fey::ORM::Role::Iterator;

use strict;
use warnings;

our $VERSION = '0.28';

use List::MoreUtils qw( pairwise );
use Moose::Role;
use Moose::Util::TypeConstraints;

requires qw( _get_next_result reset );

my $arrayref_of_classes =
    subtype
          as 'ArrayRef[ClassName]',
       => where { return 0 unless @{ $_ };
                  return List::MoreUtils::all { $_->isa('Fey::Object::Table') } @{ $_ };
                }
       => message { my @contents = eval { @{$_} } ? @{$_} : $_;
                    "Must be an array reference of Fey::Object::Table subclasses and you passed [@contents]";
                  };

coerce $arrayref_of_classes
    => from 'ClassName'
    => via { return [ $_ ] };

has classes =>
    ( is       => 'ro',
      isa      => $arrayref_of_classes,
      coerce   => 1,
      required => 1,
    );

has index =>
    ( traits   => [ 'Counter' ],
      is       => 'ro',
      isa      => 'Int',
      default  => 0,
      init_arg => undef,
      handles  => { _inc_index   => 'inc',
                    _reset_index => 'reset',
                  },
    );


sub next
{
    my $self = shift;

    my $result = $self->_get_next_result();

    return unless $result;

    $self->_inc_index();

    return wantarray ? @{ $result } : $result->[0];
}

sub next_as_hash
{
    my $self = shift;

    my @result = $self->next();

    return unless @result;

    return
        pairwise { $a->Table()->name() => $b }
        @{ $self->classes() }, @result;
}

sub all
{
    my $self = shift;

    $self->reset() if $self->index();

    return $self->remaining();
}

sub all_as_hashes
{
    my $self = shift;

    $self->reset() if $self->index();

    return $self->remaining_as_hashes();
}

sub remaining
{
    my $self = shift;

    my @result;
    while ( my @r = $self->next() )
    {
        push @result, @r == 1 ? @r : \@r;
    }

    return @result;
}

sub remaining_as_hashes
{
    my $self = shift;

    my @result;
    while ( my %r = $self->next_as_hash() )
    {
        push @result, \%r;
    }

    return @result;
}

no Moose::Role;
no Moose::Util::TypeConstraints;

1;

__END__

=head1 NAME

Fey::ORM::Role::Iterator - A role for things that iterate over Fey::Object::Table objects

=head1 SYNOPSIS

  package My::Iterator;

  use Moose;

  with 'Fey::ORM::Role::Iterator';

=head1 DESCRIPTION

This role provides some common methods used by
C<Fey::Object::Iterator> classes, as well as defining a consistent
interface for iterators.

=head1 REQUIRED METHODS

Classes which consume this role must provide C<_get_next_result()> and
C<reset()> methods.

=head1 PROVIDED ATTRIBUTES

This role provides the following attributes.

=head2 $iterator->classes()

An array reference of class names. Each class must be a subclass of
L<Fey::Object::Table>.

=head2 $iterator->index()

The current iterator index. Also provides C<_inc_index()> and
C<_reset_index()> methods.

=head1 PROVIDED METHODS

This role provides the following methods. These methods are documented
in L<Fey::Object::Iterator::FromSelect>.

=head2 $iterator->next

=head2 $iterator->next_as_hash()

=head2 $iterator->all()

=head2 $iterator->all_as_hashes()

=head2 $iterator->remaining()

=head2 $iterator->remaining_as_hashes()

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
