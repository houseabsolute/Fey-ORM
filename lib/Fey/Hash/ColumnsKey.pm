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

__END__

=head1 NAME

Fey::Hash::ColumnsKey - A hash where the keys are sets of Fey::Column objects

=head1 SYNOPSIS

  my $hash = Fey::Hash::ColumnsKey->new();

  $hash->store( [ $col1, $col2 ] => $sql );

=head1 DESCRIPTION

This class is a helper for C<Fey::Meta::Class::Table>. It is used to
cache SQL statements with a set of columns as the key. You should
never need to use it directly.

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
