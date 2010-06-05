package Fey::Hash::ColumnsKey;

use strict;
use warnings;

sub new {
    my $class = shift;

    return bless {}, $class;
}

sub get {
    my $self     = shift;
    my $key_cols = shift;

    my $key = join "\0", map { $_->name() } @{$key_cols};

    return $self->{$key};
}

sub store {
    my $self     = shift;
    my $key_cols = shift;
    my $sql      = shift;

    my $key = join "\0", map { $_->name() } @{$key_cols};

    return $self->{$key} = $sql;
}

1;

# ABSTRACT: A hash where the keys are sets of Fey::Column objects

__END__

=pod

=head1 SYNOPSIS

  my $hash = Fey::Hash::ColumnsKey->new();

  $hash->store( [ $col1, $col2 ] => $sql );

=head1 DESCRIPTION

This class is a helper for L<Fey::Meta::Class::Table>. It is used to
cache SQL statements with a set of columns as the key. You should
never need to use it directly.

=cut
