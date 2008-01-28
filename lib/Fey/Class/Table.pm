package Fey::Class::Table;

use strict;
use warnings;

our @EXPORT = ## no critic ProhibitAutomaticExportation
    qw( has_table has_one transform inflate deflate );
use base 'Exporter';

use Fey::Meta::Class::Table;
use Fey::Object;
use Fey::Validate qw( validate_pos TABLE_TYPE );
use Moose ();


# This re-exporting is a mess. Once MooseX::Exporter is done,
# hopefully it can replace all of this.
sub import
{
    my $caller = Moose::_get_caller();

    return if $caller eq 'main';

    Moose::init_meta( $caller,
                      'Fey::Object',
                      'Fey::Meta::Class::Table',
                    );

    Moose->import( { into => $caller } );

    __PACKAGE__->export_to_level( 1, @_ );

    return;
}

sub unimport ## no critic RequireFinalReturn
{
    my $caller = caller();

    no strict 'refs'; ## no critic ProhibitNoStrict
    foreach my $name (@EXPORT)
    {
        if ( defined &{ $caller . '::' . $name } )
        {
            my $keyword = \&{ $caller . '::' . $name };

            my $pkg_name =
                eval { svref_2object($keyword)->GV()->STASH()->NAME() };

            next if $@;
            next if $pkg_name ne __PACKAGE__;

            delete ${ $caller . '::' }{$name};
        }
    }

    Moose::unimport( { into_level => 1 } );
}

{
    my $spec = ( TABLE_TYPE );
    sub has_table
    {
        my ($table) = validate_pos( @_, $spec );

        my $caller = caller();

        $caller->meta()->has_table($table);
    }
}

sub transform
{
    my @p;

    push @p, pop @_ while ref $_[-1];

    my %p = _combine_hashes(@p);

    my $caller = caller();

    for my $name (@_)
    {
        $caller->meta()->add_transform( $name => %p );
    }
}

sub _combine_hashes
{
    return map { %{ $_ } } @_;
}

sub inflate (&)
{
    return { inflate => $_[0] };
}

sub deflate (&)
{
    return { deflate => $_[0] };
}

{
    my $simple_spec = ( TABLE_TYPE );

    sub has_one
    {
        my %p;
        if ( @_ == 1 )
        {
            ( $p{table} ) = validate_pos( @_, $simple_spec );
        }
        else
        {
            %p = @_;
        }

        my $caller = caller();

        $caller->meta()->add_has_one_relationship(%p);
    }
}


1;
