package Fey::Meta::HasMany::ViaFK;

use strict;
use warnings;

use List::MoreUtils qw( any );

use Moose;
use MooseX::StrictConstructor;

extends 'Fey::Meta::HasMany';


has 'fk' =>
    ( is         => 'ro',
      isa        => 'Fey::FK',
      lazy_build => 1,
    );

has 'order_by' =>
    ( is  => 'ro',
      isa => 'ArrayRef',
    );


sub _build_fk
{
    my $self = shift;

    $self->_find_one_fk_between_tables( $self->table(), $self->foreign_table(), 1 );
}

sub _make_iterator_maker
{
    my $self = shift;

    my $target_table = $self->foreign_table();

    my $select =
        $self->associated_class()->schema_class()->SQLFactoryClass()->new_select();
    $select->select($target_table)
           ->from($target_table);

    my @ph_names;

    my $ph = Fey::Placeholder->new();
    for my $pair ( @{ $self->fk()->column_pairs() } )
    {
        my ( $from, $to ) = @{ $pair };

        $select->where( $to, '=', $ph );

        push @ph_names, $from->name();
    }

    $select->order_by( @{ $self->order_by() } )
        if $self->order_by();

    my $bind_params_sub =
        sub { return map { $_[0]->$_() } @ph_names };

    return
        $self->_make_subref_for_sql( $select,
                                     $bind_params_sub,
                                   );
}


no Moose;

__PACKAGE__->meta()->make_immutable();

1;
