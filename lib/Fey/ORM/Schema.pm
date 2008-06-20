package Fey::ORM::Schema;

use strict;
use warnings;

our @EXPORT = ## no critic ProhibitAutomaticExportation
    qw( has_schema );
use base 'Exporter';

use Fey::Meta::Class::Schema;
use Fey::Object::Schema;
use Fey::Validate qw( validate_pos SCHEMA_TYPE );
use Moose ();


sub import
{
    my $caller = Moose::_get_caller();

    return if $caller eq 'main';

    Moose::init_meta( $caller,
                      'Fey::Object::Schema',
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

        $caller->meta()->_associate_schema($schema);
    }
}

1;

__END__

=head1 NAME

Fey::ORM::Schema - Provides sugar for schema-based classes

=head1 SYNOPSIS

  package MyApp::Schema;

  use Fey::ORM::Schema;

  has_schema ...;

  no Fey::ORM::Schema;

=head1 DESCRIPTION

Use this class to associate your class with a schema. It exports a
number of sugar functions to allow you to define things in a
declarative manner.

=head1 EXPORTED FUNCTIONS

This package exports the following functions:

=head2 has_schema($schema)

Given a C<Fey::Schema> object, this method associates that schema with
the calling class.

Calling this function generates several methods and attributes in the
calling class:

=head3 CallingClass->Schema()

Returns the C<Fey::Schema> object associated with the class.

=head3 CallingClass->DBIManager()

Returns the C<Fey::Schema> object associated with the class.

=head3 CallingClass->SetDBIManager($manager)

Set the C<Fey::DBIManager> object associated with the class. If you
don't set one explicitly, then the first call to C<<
CallingClass->DBIManager() >> will simply create one by calling C<<
Fey::DBIManager->new() >>.

=head3 CallingClass->SQLFactoryClass()

Returns the SQL factory class associated with the class. This defaults
to C<Fey::SQL>.

=head3 CallingClass->SetSQLFactoryClass()

Set the SQL factory class associated with the class.

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=head1 BUGS

See L<Fey::ORM> for details.

=head1 COPYRIGHT & LICENSE

Copyright 2006-2008 Dave Rolsky, All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. The full text of the license
can be found in the LICENSE file included with this module.

=cut
