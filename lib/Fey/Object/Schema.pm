package Fey::Object::Schema;

use strict;
use warnings;

use MooseX::StrictConstructor;

extends 'Moose::Object';


sub EnableObjectCache
{
    my $class = shift;

    $_->EnableObjectCache() for $class->_TableClasses();
}

sub DisableObjectCache
{
    my $class = shift;

    $_->DisableObjectCache() for $class->_TableClasses();
}

sub ClearObjectCache
{
    my $class = shift;

    $_->ClearObjectCache() for $class->_TableClasses();
}

sub _TableClasses
{
    my $class = shift;

    my $schema = $class->Schema();

    return Fey::Meta::Class::Table->ClassForTable( $schema->tables() );
}

1;

__END__

=head1 NAME

Fey::Object::Schema - Base class for schema-based objects

=head1 SYNOPSIS

  package MyApp::Schema;

  use Fey::ORM::Schema;

  has_schema(...);

=head1 DESCRIPTION

This class is a the base class for all schema-based objects.

=head1 METHODS

This class provides the following methods:

=head2 $class->EnableObjectCache()

Enables the object class for all of the table classes associated with
this class's schema.

=head2 $class->DisableObjectCache()

Disables the object class for all of the table classes associated with
this class's schema.

=head2 $class->ClearObjectCache()

Clears the object class for all of the table classes associated with
this class's schema.

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
