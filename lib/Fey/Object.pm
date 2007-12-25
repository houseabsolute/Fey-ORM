package Fey::Object;

use strict;
use warnings;

use Fey::Placeholder;
use Fey::SQL;
use Fey::Table;

use MooseX::StrictConstructor;

extends 'Moose::Object';


sub _get_column_values
{
    my $self = shift;

    my $sql = $self->_RowSQL();

#    my $dbh =
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

sub _make_row_sql
{
    my $self = shift;

    my $table = $self->table();

    my @pk = $table->primary_key();
    my %pk = map { $_->name() => 1 } @pk;

    my @non_pk = grep { ! $pk{ $_->name() } } $table->columns();

    my $sql = Fey::SQL::Select->new();
    $sql->select(@non_pk);
    $sql->from($table);
    $sql->where( $_ => Fey::Placeholder->new() ) for @pk;

    return $sql;
}

no Moose;
__PACKAGE__->meta()->make_immutable();

1;
