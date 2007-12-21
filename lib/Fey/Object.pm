package Fey::Object;

use strict;
use warnings;

use Fey::Placeholder;
use Fey::SQL;

use Moose;

extends 'Moose::Object';

no Moose;


sub _get_column_value
{
    my $self = shift;

    my $sql = $self->_RowSQL();

    my $sth = $self
}

sub _MakeRowSQL
{
    my $class = ref $_[0] || $_[0];

    my $table = $class->Table();
    my @pk = $table->primary_key();
    my %pk = map { $_->name() => 1 } @pk;

    my @non_pk = grep { ! $pk{ $_->name() } } $table->columns();

    my $sql = Fey::SQL::Select->new();
    $sql->select(@non_pk);
    $sql->from($table);
    $sql->where( $_ => Fey::Placeholder->new() ) for @pk;

    return $sql;
}

# XXX - old bits from Fey::Class::Table
sub _select_columns
{
    my $self = shift;

    my $sth = $self->_select_columns_sth();

    $sth->finish() if $sth->{Active};

    $sth->execute( $self->_pk_vals() );

    my %columns;
    $sth->bind_columns( @columns{ @{ $sth->{NAME} } } );

    $sth->fetch();

    $sth->finish();

    return \%columns;
}


1;
