package Fey::Meta::Class::Schema;

use strict;
use warnings;

use Fey::Exceptions qw( param_error );
use Fey::Validate qw( validate TABLE_TYPE FK_TYPE BOOLEAN_TYPE );

use Fey::DBIManager;
use Moose;
use MooseX::AttributeHelpers;
use MooseX::ClassAttribute;

extends 'MooseX::StrictConstructor::Meta::Class';

class_has '_SchemaClassMap' =>
    ( metaclass => 'Collection::Hash',
      is        => 'rw',
      isa       => 'HashRef[Fey::Schema]',
      default   => sub { {} },
      lazy      => 1,
      provides  => { get    => 'SchemaForClass',
                     set    => '_SetSchemaForClass',
                     exists => '_ClassHasSchema',
                   },
    );

sub ClassForSchema
{
    my $class  = shift;
    my $schema = shift;

    my $map = $class->_SchemaClassMap();

    for my $class_name ( keys %{ $map } )
    {
        return $class_name
            if $map->{$class_name}->name() eq $schema->name();
    }

    return;
}

sub _has_schema
{
    my $self   = shift;
    my $schema = shift;

    my $caller = $self->name();

    param_error 'Cannot call has_schema() more than once per class'
        if $caller->can('_HasSchema') && $caller->_HasSchema();

    param_error 'Cannot associate the same schema with multiple classes'
        if __PACKAGE__->ClassForSchema($schema);

    __PACKAGE__->_SetSchemaForClass( $self->name() => $schema );

    $self->_make_class_attributes();

    $caller->_SetSchema($schema);
}

sub _make_class_attributes
{
    my $self = shift;

    MooseX::ClassAttribute::process_class_attribute
        ( $self->name(),
          'Schema' =>
          ( is        => 'rw',
            isa       => 'Fey::Schema',
            writer    => '_SetSchema',
            predicate => '_HasSchema',
          )
        );

    MooseX::ClassAttribute::process_class_attribute
        ( $self->name(),
          'DBIManager' =>
          ( is        => 'rw',
            isa       => 'Fey::DBIManager',
            writer    => 'SetDBIManager',
            lazy      => 1,
            default   => sub { Fey::DBIManager->new() },
          )
        );

    MooseX::ClassAttribute::process_class_attribute
        ( $self->name(),
          'SQLFactoryClass' =>
          ( is        => 'rw',
            isa       => 'ClassName',
            writer    => 'SetSQLFactoryClass',
            lazy      => 1,
            default   => 'Fey::SQL',
          )
        );
}

no Moose;
__PACKAGE__->meta()->make_immutable();

1;

__END__

=head1 NAME

Fey::Meta::Class::Schema - A metaclass for schema classes

=head1 SYNOPSIS

  package MyApp::Schema;

  use Fey::ORM::Schema;

  print __PACKAGE__->meta()->ClassForSchema($schema);

=head1 DESCRIPTION

This is the metaclass for schema classes. When you use
L<Fey::ORM::Schema> in your class, it uses this class to do all the
heavy lifting.

=head1 METHODS

This class provides the following methods:

=head2 Fey::Meta::Class::Schema->ClassForSchema($schema)

Given a C<Fey::Schema> object, this method returns the name of the
class which "has" that schema, if any.

=head2 Fey::Meta::Class::Schema->SchemaForClass($class)

Given a class, this method returns the C<Fey::Schema> object
associated with that class, if any.

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