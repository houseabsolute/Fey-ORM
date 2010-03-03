package Fey::Meta::HasOne::ViaFK;

use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '0.32';

use List::AllUtils qw( any );

use Moose;
use MooseX::StrictConstructor;

extends 'Fey::Meta::HasOne';

has 'fk' => (
    is      => 'ro',
    isa     => 'Fey::FK',
    lazy    => 1,
    builder => '_build_fk',
);

sub _build_fk {
    my $self = shift;

    $self->_find_one_fk_between_tables( $self->table(),
        $self->foreign_table(), 0 );
}

sub _build_allows_undef {
    my $self = shift;

    return any { $_->is_nullable() } @{ $self->fk()->source_columns() };
}

sub _make_subref {
    my $self = shift;

    my %column_map;
    for my $pair ( @{ $self->fk()->column_pairs() } ) {
        my ( $from, $to ) = @{$pair};

        $column_map{ $from->name() } = [ $to->name(), $to->is_nullable() ];
    }

    my $target_table = $self->foreign_table();

    return sub {
        my $self = shift;

        my %new_p;

        for my $from ( keys %column_map ) {
            my $target_name = $column_map{$from}[0];

            $new_p{$target_name} = $self->$from();

            return
                unless defined $new_p{$target_name} || $column_map{$from}[1];
        }

        return $self->meta()->ClassForTable($target_table)->new(%new_p);
    };
}

__PACKAGE__->meta()->make_immutable();

1;

__END__

=head1 NAME

Fey::Meta::HasOne::ViaFK - A parent for has-one metaclasses based on a L<Fey::FK> object

=head1 DESCRIPTION

This class implements a has-one relationship for a class, based on a
provided (or deduced) L<Fey::FK> object.

=head1 CONSTRUCTOR OPTIONS

This class accepts the following constructor options:

=over 4

=item * fk

If you don't provide this, the class looks for foreign keys between
C<< $self->table() >> and and C<< $self->foreign_table() >>. If it
finds exactly one, it uses that one.

=item * allows_undef

This defaults to true if any of the columns in the local table are
NULLable, otherwise it defaults to false.

=back

=head1 METHODS

Besides the methods inherited from L<Fey::Meta::HasOne>, it also
provides the following methods:

=head2 $ho->fk()

Corresponds to the value passed to the constructor, or the calculated
default.

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
