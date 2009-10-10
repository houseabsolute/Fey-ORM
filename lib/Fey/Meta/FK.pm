package Fey::Meta::FK;

use strict;
use warnings;

our $VERSION = '0.29';

use Fey::Exceptions qw( param_error );

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

subtype 'Fey.ORM.Type.TableWithSchema'
    => as 'Fey::Table'
    => where { $_[0]->has_schema() }
    => message { 'A table used for has-one or -many relationships must have a schema' };

has associated_class =>
    ( is       => 'rw',
      isa      => 'Fey::Meta::Class::Table',
      writer   => '_set_associated_class',
      clearer  => '_clear_associated_class',
      weak_ref => 1,
      init_arg => undef,
    );

has name =>
    ( is      => 'ro',
      isa     => 'Str',
      lazy    => 1,
      builder => '_build_name',
    );

has namer =>
    ( is       => 'ro',
      isa      => 'CodeRef',
      required => 1,
    );

has table =>
    ( is       => 'ro',
      isa      => 'Fey.ORM.Type.TableWithSchema',
      required => 1,
    );

has foreign_table =>
    ( is       => 'ro',
      isa      => 'Fey.ORM.Type.TableWithSchema',
      required => 1,
    );

has is_cached =>
    ( is      => 'ro',
      isa     => 'Bool',
      lazy    => 1,
      builder => '_build_is_cached',
    );


sub _build_name
{
    my $self = shift;

    return $self->namer()->( $self->foreign_table(), $self );
}

sub _find_one_fk_between_tables
{
    my $self         = shift;
    my $source_table = shift;
    my $target_table = shift;
    my $is_has_many  = shift;

    my @fk = $source_table->schema()->foreign_keys_between_tables( $source_table, $target_table );

    my $desc = $is_has_many ? 'has_many' : 'has_one';

    if ( @fk == 0 )
    {
        param_error
            'There are no foreign keys between the table for this class, '
            . $source_table->name()
            . " and the table you passed to $desc(), "
            . $target_table->name() . '.';
    }
    elsif ( @fk > 1 )
    {
        param_error
            'There is more than one foreign key between the table for this class, '
            . $source_table->name()
            . " and the table you passed to $desc(), "
            . $target_table->name()
            . '. You must specify one explicitly.';
    }

    return $self->_invert_fk_if_necessary( $fk[0], $target_table, $is_has_many );
}

# We may need to invert the meaning of source & target since source &
# target for an FK object are sort of arbitrary. The source should be
# "our" table, and the target the foreign table.
sub _invert_fk_if_necessary
{
    my $self         = shift;
    my $fk           = shift;
    my $target_table = shift;
    my $has_many     = shift;

    # Self-referential keys are a special case, and that case differs
    # for has_one vs has_many.
    if ( $fk->is_self_referential() )
    {
        if ($has_many)
        {
            return $fk
                unless $fk->target_table()->has_candidate_key( @{ $fk->target_columns() } );
        }
        else
        {
            # A self-referential key is a special case. If the target
            # columns are _not_ a key, then we need to invert source &
            # target so we do our select by a key. This doesn't
            # address a pathological case where neither source nor
            # target column sets make up a key. That shouldn't happen,
            # though ;)
            return $fk
                if $fk->target_table()->has_candidate_key( @{ $fk->target_columns() } );
        }
    }
    else
    {
        return $fk
            if $fk->target_table()->name() eq $target_table->name();
    }

    return Fey::FK->new( source_columns => $fk->target_columns(),
                         target_columns => $fk->source_columns(),
                       );
}


no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__

=head1 NAME

Fey::Meta::FK - A parent for foreign key-based metaclasses

=head1 DESCRIPTION

This class exists to provide a common parent for has-one and has-many
metaclasses. See the relevant classes for documentation.

=head1 CONSTRUCTOR OPTIONS

This class accepts the following constructor options:

=over 4

=item * name

The name of the relationship. This will be used as the name for any
attribute or method created by this metaclass.

This defaults to C<< lc $self->foreign_table()->name() >>.

=item * table

The (source) table of the foreign key.

=item * foreign_table

The foreign table for the foreign key

=item * is_cached

Determines whether the relationship's value is cached. This is
implemented in different ways for has-one vs has-many relationships.

=back

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
