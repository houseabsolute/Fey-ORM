package Fey::Meta::Class::Schema;

use strict;
use warnings;

use Fey::Exceptions qw( param_error );
use Fey::Validate qw( validate validate_pos TABLE_TYPE SCHEMA_TYPE FK_TYPE BOOLEAN_TYPE );

use Fey::DBIManager;
use Moose;
use MooseX::AttributeHelpers;
use MooseX::ClassAttribute;
use MooseX::SemiAffordanceAccessor;

extends 'Moose::Meta::Class';

class_has '_SchemaClassMap' =>
    ( metaclass => 'Collection::Hash',
      is        => 'ro',
      isa       => 'HashRef[Fey::Schema]',
      default   => sub { {} },
      lazy      => 1,
      provides  => { get    => 'SchemaForClass',
                     set    => '_SetSchemaForClass',
                     exists => '_ClassHasSchema',
                   },
    );

has 'schema' =>
    ( is        => 'rw',
      isa       => 'Fey::Schema',
      writer    => '_set_schema',
      predicate => '_has_schema',
    );

has 'dbi_manager' =>
    ( is        => 'rw',
      isa       => 'Fey::DBIManager',
      lazy      => 1,
      default   => sub { Fey::DBIManager->new() },
    );

has 'sql_factory_class' =>
    ( is        => 'rw',
      isa       => 'ClassName',
      lazy      => 1,
      default   => 'Fey::SQL',
    );


{
    my @spec = ( SCHEMA_TYPE );
    sub ClassForSchema
    {
        my $class    = shift;
        my ($schema) = validate_pos( @_, @spec );

        my $map = $class->_SchemaClassMap();

        for my $class_name ( keys %{ $map } )
        {
            return $class_name
                if $map->{$class_name}->name() eq $schema->name();
        }

        return;
    }
}

sub _associate_schema
{
    my $self   = shift;
    my $schema = shift;

    my $caller = $self->name();

    param_error 'Cannot call has_schema() more than once per class'
        if $self->_has_schema();

    param_error 'Cannot associate the same schema with multiple classes'
        if __PACKAGE__->ClassForSchema($schema);

    __PACKAGE__->_SetSchemaForClass( $self->name() => $schema );

    $self->_set_schema($schema);
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

=head2 $meta->table()

Returns the C<Fey::Schema> for the metaclass's class.

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
