package Fey::Meta::Attribute::FromSelect;

use strict;
use warnings;

use Moose;
use Moose::Util::TypeConstraints;

extends 'Moose::Meta::Attribute';

before '_process_options' => sub
{
    my $class   = shift;
    my $name    = shift;
    my $options = shift;

    $options->{lazy} = 1;

    $options->{default} =
        $class->_make_default_from_select
            ( delete $options->{select},
              delete $options->{bind_params},
              $options->{isa},
            );
};

sub _make_default_from_select
{
    my $class    = shift;
    my $select   = shift;
    my $bind_sub = shift;
    my $type     = shift;

    die 'The select parameter must be a Fey::SQL::Select object'
        unless blessed $select && $select->isa('Fey::SQL::Select');

    my $wantarray = 0;
    $wantarray = 1
        if defined $type
           && find_type_constraint($type)->is_a_type_of('ArrayRef');

    return
        sub { my $self = shift;

              my $dbh =
                  $self->_dbh($select);

              my @select_p =
                  ( $select->sql($dbh), {},
                    $bind_sub ? $self->$bind_sub() : ()
                  );

              my $col = $dbh->selectcol_arrayref(@select_p)
                  or return;

              return $wantarray ? $col : $col->[0];
            };
}

no Moose;
no Moose::Util::TypeConstraints;

package # hide from PAUSE
    Moose::Meta::Attribute::Custom::FromSelect;
sub register_implementation { 'Fey::Meta::Attribute::FromSelect' }

1;

__END__

=head1 NAME

Fey::Meta::Attribute::FromSelect - an attribute metaclass for SELECT-based attributes

=head1 SYNOPSIS

  package MyApp::Song;

  has 'average_rating' =>
      ( metaclass   => 'FromSelect',
        is          => 'ro',
        isa         => 'Float',
        select      => $select,
        bind_params => sub { $_[0]->song_id() },
      );

=head1 DESCRIPTION

This attribute metaclass allows you to set an attribute's default
based on a C<SELECT> query and optional bound parameters. This is a
fairly common need when writing ORM-based classes.

=head1 OPTIONS

This metaclass accepts two additional parameters in addition to the
normal Moose attribute options.

=over 4

=item * select

This must be a C<Fey::SQL::Select> object (or subclass). It is required.

=item * bind_params

This must be a subroutine reference, which when called will return an
array of bind parameters for the query. This subref will be called as
a method on the object which has the attribute. This is an optional
parameter.

=back

Note that this metaclass overrides any value you provide for "default"
with a subroutine that executes the query and gets the value it
returns.

=head1 ArrayRef TYPES

By default, the C<SELECT> is expected to return just a single row with
one column. However, if you set the type of the attribute to ArrayRef
(or a subtype), then the select can return multiple rows, still with a
single column.

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
