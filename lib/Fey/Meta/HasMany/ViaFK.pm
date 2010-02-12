package Fey::Meta::HasMany::ViaFK;

use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '0.31';

use List::AllUtils qw( any );

use Moose;
use MooseX::StrictConstructor;

extends 'Fey::Meta::HasMany';

has 'fk' => (
    is      => 'ro',
    isa     => 'Fey::FK',
    lazy    => 1,
    builder => '_build_fk',
);

has 'order_by' => (
    is  => 'ro',
    isa => 'ArrayRef',
);

sub _build_fk {
    my $self = shift;

    $self->_find_one_fk_between_tables( $self->table(),
        $self->foreign_table(), 1 );
}

sub _make_iterator_maker {
    my $self = shift;

    my $target_table = $self->foreign_table();

    my $select = $self->associated_class()->schema_class()->SQLFactoryClass()
        ->new_select();
    $select->select($target_table)->from($target_table);

    my @ph_names;

    my $ph = Fey::Placeholder->new();
    for my $pair ( @{ $self->fk()->column_pairs() } ) {
        my ( $from, $to ) = @{$pair};

        $select->where( $to, '=', $ph );

        push @ph_names, $from->name();
    }

    $select->order_by( @{ $self->order_by() } )
        if $self->order_by();

    my $bind_params_sub = sub {
        return map { $_[0]->$_() } @ph_names;
    };

    return $self->_make_subref_for_sql(
        $select,
        $bind_params_sub,
    );
}

__PACKAGE__->meta()->make_immutable();

1;

__END__

=head1 NAME

Fey::Meta::HasMany - A parent for has-one metaclasses based on a L<Fey::FK> object

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

=item * order_by

This will be appended to the SQL which is generated to select the
foreign rows. It should be an arrayref which can be passed to C<<
Fey::SQL::Select->order_by() >>.

=item * allows_undef

This defaults to true if any of the columns in the local table are
NULLable, otherwise it defaults to false.

=back

=head1 METHODS

Besides the methods inherited from L<Fey::Meta::HasMany>, it also
provides the following methods:

=head2 $ho->fk()

Corresponds to the value passed to the constructor, or the calculated
default.

=head2 $ho->order_by()

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
