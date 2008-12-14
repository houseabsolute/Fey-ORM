package Fey::Meta::FK;

use strict;
use warnings;

use Fey::Exceptions qw( param_error );

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

subtype 'Fey.ORM.Type.TableWithSchema'
    => as 'Fey::Table'
    => where { $_[0]->has_schema() }
    => message { 'A table used for has-one or -many relationships must have a schema' };


sub _find_one_fk
{
    my $class = shift;
    my $from  = shift;
    my $to    = shift;
    my $func  = shift;

    my @fk = $from->schema()->foreign_keys_between_tables( $from, $to );

    return $fk[0] if @fk == 1;

    if ( @fk == 0 )
    {
        param_error
            'There are no foreign keys between the table for this class, '
            . $from->name()
            . " and the table you passed to $func(), "
            . $to->name() . '.';
    }
    elsif ( @fk > 1 )
    {
        param_error
            'There is more than one foreign key between the table for this class, '
            . $from->name()
            . " and the table you passed to $func(), "
            . $to->name()
            . '. You must specify one explicitly.';
    }
}

# We may need to invert the meaning of source & target since source &
# target for an FK object are sort of arbitrary. The source should be
# "our" table, and the target the foreign table.
sub _invert_fk_if_necessary
{
    my $self         = shift;
    my $fk           = shift;
    my $target_table = shift;
    my $is_has_many  = shift;

    # Self-referential keys are a special case, and that case differs
    # for has_one vs has_many.
    if ( $fk->is_self_referential() )
    {
        if ($is_has_many)
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
