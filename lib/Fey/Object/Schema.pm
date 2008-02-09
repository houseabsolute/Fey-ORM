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
