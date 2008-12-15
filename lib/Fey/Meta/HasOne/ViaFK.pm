package Fey::Meta::HasOne::ViaFK;

use strict;
use warnings;

use List::MoreUtils qw( any );

use Moose;
use MooseX::StrictConstructor;

extends 'Fey::Meta::HasOne';


has 'fk' =>
    ( is         => 'ro',
      isa        => 'Fey::FK',
      lazy_build => 1,
    );


sub _build_fk
{
    my $self = shift;

    $self->_find_one_fk_between_tables( $self->table(), $self->foreign_table(), 0 );
}

sub _build_allows_undef
{
    my $self = shift;

    return any { $_->is_nullable() } @{ $self->fk()->source_columns() }
}

sub _make_subref
{
    my $self = shift;

    my %column_map;
    for my $pair ( @{ $self->fk()->column_pairs() } )
    {
        my ( $from, $to ) = @{ $pair };

        $column_map{ $from->name() } = [ $to->name(), $to->is_nullable() ];
    }

    my $target_table = $self->foreign_table();

    return
        sub { my $self = shift;

              my %new_p;

              for my $from ( keys %column_map )
              {
                  my $target_name = $column_map{$from}[0];

                  $new_p{$target_name} = $self->$from();

                  return unless defined $new_p{$target_name} || $column_map{$from}[1];
              }

              return
                  $self->meta()
                       ->ClassForTable($target_table)
                       ->new(%new_p);
            };
}


no Moose;

__PACKAGE__->meta()->make_immutable();

1;
