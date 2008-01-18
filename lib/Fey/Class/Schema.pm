package Fey::Class::Schema;

use strict;
use warnings;

our @EXPORT = ## no critic ProhibitAutomaticExportation
    qw( has_schema );
use base 'Exporter';

use Fey::Meta::Class::Schema;
use Fey::Validate qw( validate_pos SCHEMA_TYPE );
use Moose ();


sub import
{
    my $caller = Moose::_get_caller();

    return if $caller eq 'main';

    Moose::init_meta( $caller,
                      'Moose::Object',
                      'Fey::Meta::Class::Schema',
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
    my $spec = ( SCHEMA_TYPE );
    sub has_schema
    {
        my ($schema) = validate_pos( @_, $spec );

        my $caller = caller();

        $caller->meta()->has_schema($schema);
    }
}


1;

__END__
