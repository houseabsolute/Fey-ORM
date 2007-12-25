package Fey::Meta::Class::Schema;

use strict;
use warnings;

use Fey::Exceptions qw( param_error );
use Fey::Validate qw( validate TABLE_TYPE FK_TYPE BOOLEAN_TYPE );

use Moose;
use MooseX::AttributeHelpers;
use MooseX::ClassAttribute;

extends 'MooseX::StrictConstructor::Meta::Class';

has 'dbi_manager' =>
    ( is        => 'rw',
      isa       => 'Fey::DBIManager',
      predicate => 'has_dbi_manager',
    );

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

sub set_schema
{
    my $self   = shift;
    my $schema = shift;

    my $caller = $self->name();

    param_error 'Cannot call has_schema() more than once per class'
        if $caller->can('HasSchema') && $caller->HasSchema();

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
            predicate => 'HasSchema',
          )
        );

    MooseX::ClassAttribute::process_class_attribute
        ( $self->name(),
          'DBIManager' =>
          ( is        => 'rw',
            isa       => 'Fey::DBIManager',
            predicate => 'HasDBIManager',
          )
        );
}

no Moose;
__PACKAGE__->meta()->make_immutable();

1;
