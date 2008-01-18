package Fey::Hash::ColumnsKey;

use strict;
use warnings;


sub new
{
    my $class = shift;

    return bless {}, $class;
}

sub get
{
    my $self     = shift;
    my $key_cols = shift;

    my $key = join "\0", map { $_->name() } @{ $key_cols };

    return $self->{$key};
}

sub store
{
    my $self     = shift;
    my $key_cols = shift;
    my $sql      = shift;

    my $key = join "\0", map { $_->name() } @{ $key_cols };

    return $self->{$key} = $sql;
}


1;

