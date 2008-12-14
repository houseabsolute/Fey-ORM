package Fey::Meta::Util;

use strict;
use warnings;

use Fey::Exceptions qw( param_error );

# Just using this cause Moose is already using it
use Sub::Exporter;

my @exports = qw( find_fk_between_tables );

Sub::Exporter::setup_exporter
    ( { exports => \@exports,
      },
    );


sub find_fk_between_tables
{
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

    return _invert_fk_if_necessary( $fk[0], $target_table, $is_has_many );
}

# We may need to invert the meaning of source & target since source &
# target for an FK object are sort of arbitrary. The source should be
# "our" table, and the target the foreign table.
sub _invert_fk_if_necessary
{
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

1;
