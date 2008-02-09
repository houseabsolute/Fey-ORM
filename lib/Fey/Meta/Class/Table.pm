package Fey::Meta::Class::Table;

use strict;
use warnings;

use Fey::Exceptions qw( param_error );
use Fey::Validate qw( validate SCALAR_TYPE ARRAYREF_TYPE TABLE_TYPE FK_TYPE BOOLEAN_TYPE );

use Fey::Hash::ColumnsKey;
use Fey::Object::Iterator;
use Fey::Object::Iterator::Caching;
use Fey::Meta::Class::Schema;
use List::MoreUtils qw( all );

use Moose;
use MooseX::AttributeHelpers;
use MooseX::ClassAttribute;

extends 'MooseX::StrictConstructor::Meta::Class';

class_has '_TableClassMap' =>
    ( metaclass => 'Collection::Hash',
      is        => 'rw',
      isa       => 'HashRef[Fey::Table]',
      default   => sub { {} },
      lazy      => 1,
      provides  => { get    => 'TableForClass',
                     set    => '_SetTableForClass',
                     exists => '_ClassHasTable',
                   },
    );

has '_object_cache_is_enabled' =>
    ( is      => 'rw',
      isa     => 'Bool',
      lazy    => 1,
      default => 0,
      writer  => '_set_object_cache_is_enabled',
    );

has '_object_cache' =>
    ( is      => 'ro',
      isa     => 'HashRef',
      lazy    => 1,
      default => sub { {} },
      clearer => '_clear_object_cache',
    );

sub ClassForTable
{
    my $class = shift;

    return @_ == 1 ? $class->_ClassForTable(@_) : map { $class->_ClassForTable($_) } @_;
}

sub _ClassForTable
{
    my $class = shift;
    my $table = shift;

    my $map = $class->_TableClassMap();

    for my $class_name ( keys %{ $map } )
    {
        return $class_name
            if $map->{$class_name} && $map->{$class_name}->name() eq $table->name();
    }

    return;
}

sub _search_cache
{
    my $self = shift;
    my $p    = shift;

    my $cache = $self->_object_cache();

    for my $key ( $self->name()->Table()->candidate_keys() )
    {
        my @names = map { $_->name() } @{ $key };
        next unless all { defined $p->{$_} } @names;

        my $cache_key = join "\0", map { $_, $p->{$_} } sort @names;

        return $cache->{$cache_key}
            if exists $cache->{$cache_key};
    }
}

sub _write_to_cache
{
    my $self   = shift;
    my $object = shift;

    my $cache = $self->_object_cache();

    for my $key ( $self->name()->Table()->candidate_keys() )
    {
        my @names = map { $_->name() } @{ $key };

        my $cache_key = join "\0", map { $_, $object->$_() } sort @names;

        $cache->{$cache_key} = $object;
    }
}

sub _has_table
{
    my $self  = shift;
    my $table = shift;

    my $caller = $self->name();

    param_error 'Cannot call has_table() more than once per class'
        if $caller->can('_HasTable') && $caller->_HasTable();

    param_error 'Cannot associate the same table with multiple classes'
        if __PACKAGE__->ClassForTable($table);

    param_error 'A table object passed to has_table() must have a schema'
        unless $table->has_schema();

    my $class = Fey::Meta::Class::Schema->ClassForSchema( $table->schema() );

    param_error 'You must load your schema class before calling has_table()'
        unless $class
        && $class->can('meta')
        && $class->can('_HasSchema')
        && $class->_HasSchema();

    param_error 'A table object passed to has_table() must have at least one key'
        unless $table->primary_key();

    __PACKAGE__->_SetTableForClass( $self->name() => $table );

    $self->_make_class_attributes();

    $caller->_SetTable($table);

    $self->_make_column_attributes();
}

sub _make_column_attributes
{
    my $self = shift;

    my $table = $self->name()->Table();

    for my $column ( $table->columns() )
    {
        my $name = $column->name();

        next if $self->has_method($name);

        my %attr_p = ( is        => 'rw',
                       writer    => q{_set_} . $name,
                       lazy      => 1,
                       default => sub { $_[0]->_get_column_value($name) },
                     );

        $attr_p{isa}       = $self->_type_for_column($column);
        $attr_p{clearer}   = q{_clear_} . $name;
        $attr_p{predicate} = q{has_} . $name;

        $self->add_attribute( $name, %attr_p );
    }
}

sub _make_class_attributes
{
    my $self = shift;

    my $caller = $self->name();

    MooseX::ClassAttribute::process_class_attribute
        ( $caller,
          'Table',
          ( is        => 'rw',
            isa       => 'Fey::Table',
            writer    => '_SetTable',
            predicate => '_HasTable',
          ),
        );

    MooseX::ClassAttribute::process_class_attribute
        ( $caller,
          '_Inflators',
          ( metaclass => 'Collection::Hash',
            is        => 'rw',
            isa       => 'HashRef[CodeRef]',
            default   => sub { {} },
            lazy      => 1,
            provides  => { set    => '_SetInflator',
                           exists => 'HasInflator',
                         },
          ),
        );

    MooseX::ClassAttribute::process_class_attribute
        ( $caller,
          '_Deflators',
          ( metaclass => 'Collection::Hash',
            is        => 'rw',
            isa       => 'HashRef[CodeRef]',
            default   => sub { {} },
            lazy      => 1,
            provides  => { set    => '_SetDeflator',
                           exists => 'HasDeflator',
                         },
          ),
        );

    MooseX::ClassAttribute::process_class_attribute
        ( $caller,
          'SchemaClass',
          ( is      => 'ro',
            isa     => 'ClassName',
            lazy    => 1,
            default => sub { Fey::Meta::Class::Schema->ClassForSchema( $_[0]->Table()->schema() ) },
          ),
        );

    MooseX::ClassAttribute::process_class_attribute
        ( $caller,
          '_SelectSQLCache',
          ( is      => 'ro',
            isa     => 'Fey::Hash::ColumnsKey',
            lazy    => 1,
            default => sub { Fey::Hash::ColumnsKey->new() },
          ),
        );

    MooseX::ClassAttribute::process_class_attribute
        ( $caller,
          '_SelectByPKSQL',
          ( is        => 'ro',
            isa       => 'Fey::SQL::Select',
            lazy      => 1,
            default   => sub { return $caller->_MakeSelectByPKSQL() },
          ),
        );

    MooseX::ClassAttribute::process_class_attribute
        ( $caller,
          '_CountSQL',
          ( is        => 'ro',
            isa       => 'Fey::SQL::Select',
            lazy      => 1,
            default   => sub { return $caller->_MakeCountSQL() },
          ),
        );
}

# XXX - can this be overridden or customized? should it account for
# per-column/policy-level transforms?
{
    my %FeyToMoose = ( text     => 'Str',
                       blob     => 'Str',
                       integer  => 'Int',
                       float    => 'Num',
                       datetime => 'Str',
                       date     => 'Str',
                       time     => 'Str',
                       boolean  => 'Bool',
                       other    => 'Value',
                     );

    sub _type_for_column
    {
        my $self   = shift;
        my $column = shift;

        my $type = $FeyToMoose{ $column->generic_type() };

        $type .= q{ | Undef}
            if $column->is_nullable();

        return $type;
    }
}

sub _add_transform
{
    my $self = shift;
    my $name = shift;
    my %p    = @_;

    my $attr = $self->get_attribute($name);

    param_error "No such attribute $name"
        unless $attr;

    if ( my $inflate_sub = $p{inflate} )
    {
        my $raw_reader = $name . q{_raw};

        param_error "Cannot provide more than one inflator for a column ($name)"
            if $self->has_method($raw_reader);

        $self->add_method( $raw_reader => $attr->get_read_method_ref() );

        my $cache_name      = q{_inflated_} . $name;
        my $cache_set       = q{_set_inflated_} . $name;
        my $cache_predicate = q{_has} . $cache_name;
        my $cache_clear     = q{_clear_} . $cache_name;

        $self->add_attribute( $cache_name,
                              is        => 'rw',
                              writer    => $cache_set,
                              predicate => $cache_predicate,
                              clearer   => $cache_clear,
                              init_arg  => "\0$cache_name",
                            );

        my $inflator =
            sub { my $orig = shift;
                  my $self = shift;

                  return $self->$cache_name()
                      if $self->$cache_predicate();

                  my $val = $self->$orig();

                  my $inflated = $self->$inflate_sub($val);

                  $self->$cache_set($inflated);

                  return $inflated;
                };

        $self->add_around_method_modifier( $name => $inflator );

        my $clear_inflator =
            sub { my $orig = shift;
                  my $self = shift;

                  $self->$cache_clear();

                  $self->$orig();
                };

        $self->add_around_method_modifier( $attr->clearer(), $clear_inflator );

        $self->name()->_SetInflator( $name => $inflate_sub );
    }

    if ( $p{deflate} )
    {
        param_error "Cannot provide more than one deflator for a column ($name)"
            if $self->name()->HasDeflator($name);

        $self->name()->_SetDeflator( $name => $p{deflate} );
    }
}

{
    my $spec = { name  => SCALAR_TYPE( default => undef ),
                 table => TABLE_TYPE,
                 cache => BOOLEAN_TYPE( default => 1 ),
                 fk    => FK_TYPE( default => undef ),
               };

    sub _add_has_one_relationship
    {
        my $self = shift;
        my %p    = validate( @_, $spec );

        param_error 'A table object passed to has_one() must have a schema'
            unless $p{table}->has_schema();

        param_error 'You must call has_table() before calling has_one().'
            unless $self->name()->can('_HasTable') && $self->name()->_HasTable();

        $p{fk} ||= $self->_find_one_fk( $p{table}, 'has_one' );

        $self->_make_has_one(%p);
    }
}

sub _find_one_fk
{
    my $self = shift;
    my $to   = shift;
    my $func = shift;

    my $from = $self->name()->Table();

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
    elsif ( @fk == 2 )
    {
        param_error
            'There is more than one foreign key between the table for this class, '
            . $from->name()
            . " and the table you passed to $func(), "
            . $to->name()
            . '. You must specify one explicitly.';
    }
}

sub _make_has_one
{
    my $self = shift;
    my %p    = @_;

    my $name = $p{name} || lc $p{table}->name();

    my $default_sub = $self->_make_has_one_default_sub(%p);

    if ( $p{cache} )
    {
        my $can_be_undef = grep { $_->is_nullable() } @{ $p{fk}->source_columns() };

        # It'd be nice to set isa to the actual foreign class, but we may
        # not be able to map a table to a class yet, since that depends on
        # the related class being loaded. It doesn't really matter, since
        # this accessor is read-only, so there's really no typing issue to
        # deal with.
        my $type = 'Fey::Object';
        $type = "Maybe[$type]" if $can_be_undef;

        $self->add_attribute
            ( $name,
              is      => 'ro',
              isa     => $type,
              lazy    => 1,
              default => $default_sub,
            );
    }
    else
    {
        $self->add_method( $name => $default_sub );
    }
}

sub _make_has_one_default_sub
{
    my $self = shift;
    my %p    = @_;

    my $target_table = $p{table};

    # We may need to invert the meaning of source & target since
    # source & target for an FK object are sort of arbitrary. The
    # source should be "our" table, and the target the foreign table.
    my $invert = 0;

    my $fk = $p{fk};

    if ( $fk->is_self_referential() )
    {
        # A self-referential key is a special case. If the target
        # columns are _not_ a key, then we need to invert source &
        # target so we do our select by a key. This doesn't address a
        # pathological case where neither source nor target column
        # sets make up a key. That shouldn't happen, though ;)
        $invert = 1
            unless $fk->target_table()->has_candidate_key( @{ $fk->target_columns() } );
    }
    else
    {
        $invert = 1
            if $p{fk}->target_table()->name() eq $target_table->name();
    }

    my %column_map;
    for my $pair ( $p{fk}->column_pairs() )
    {
        my ( $from, $to ) = $invert ? @{ $pair }[ 1, 0 ] : @{ $pair };

        $column_map{ $from->name() } = [ $to->name(), $to->is_nullable() ];
    }

    return
        sub { my $self = shift;

              my %new_p;

              for my $from ( keys %column_map )
              {
                  my $target_name = $column_map{$from}[0];

                  $new_p{$target_name} = $self->$from();

                  return unless defined $new_p{$target_name} || $column_map{$from}[1];
              }

              return
                  $self->meta()
                      ->ClassForTable($target_table)
                      ->new(%new_p);
            };
}

{
    my $spec = { name     => SCALAR_TYPE( default => undef ),
                 table    => TABLE_TYPE,
                 cache    => BOOLEAN_TYPE( default => 0 ),
                 fk       => FK_TYPE( default => undef ),
                 order_by => ARRAYREF_TYPE( default => undef ),
               };

    sub _add_has_many_relationship
    {
        my $self = shift;
        my %p    = validate( @_, $spec );

        param_error 'A table object passed to has_many() must have a schema'
            unless $p{table}->has_schema();

        param_error 'You must call has_table() before calling has_many().'
            unless $self->name()->can('_HasTable') && $self->name()->_HasTable();

        $p{fk} ||= $self->_find_one_fk( $p{table}, 'has_many' );

        $self->_make_has_many(%p);
    }
}

sub _make_has_many
{
    my $self = shift;
    my %p    = @_;

    my $name = $p{name} || lc $p{table}->name();

    my $iterator_class = $p{cache} ? 'Fey::Object::Iterator::Caching' : 'Fey::Object::Iterator';

    my $default_sub = $self->_make_has_many_default_sub( %p, iterator_class => $iterator_class );

    if ( $p{cache} )
    {
        my $attr_name = q{_} . $name;

        $self->add_attribute
            ( $attr_name,
              is      => 'ro',
              isa     => $iterator_class,
              lazy    => 1,
              default => $default_sub,
            );

        my $method = sub { my $iterator = $_[0]->$attr_name();
                           $iterator->reset();
                           return $iterator; };

        $self->add_method( $name => $method );

    }
    else
    {
        $self->add_method( $name => $default_sub );
    }
}

sub _make_has_many_default_sub
{
    my $self = shift;
    my %p    = @_;

    my $target_table = $p{table};

    # This is just like has_one, except the logic is inverted when
    # determining whether or not to invert the FK.
    my $invert = 0;

    my $fk = $p{fk};

    if ( $fk->is_self_referential() )
    {
        $invert = 1
            unless $fk->source_table()->has_candidate_key( @{ $fk->source_columns() } );
    }
    else
    {
        $invert = 1
            if $p{fk}->source_table()->name() eq $target_table->name();
    }

    my %column_map;
    for my $pair ( $p{fk}->column_pairs() )
    {
        my ( $from, $to ) = $invert ? @{ $pair }[ 1, 0 ] : @{ $pair };

        $column_map{ $from->name() } = [ $to, $to->is_nullable() ];
    }

    my $iterator = $p{iterator_class};
    my $order_by = $p{order_by};

    return
        sub { my $self = shift;

              my $class = $self->meta()->ClassForTable($target_table);

              my $select = $self->SchemaClass()->SQLFactoryClass()->new_select();
              $select->select($target_table)
                     ->from($target_table);

              my $ph = Fey::Placeholder->new();

              my @bind;
              for my $from ( keys %column_map )
              {
                  my $bind = $self->$from();

                  return unless defined $bind || $column_map{$from}[1];

                  push @bind, $bind;

                  $select->where( $column_map{$from}[0], '=', $ph );
              }

              $select->order_by( @{ $order_by } )
                  if $order_by;

              my $dbh = $self->_dbh($select);

              my $sth = $dbh->prepare( $select->sql($dbh) );

              return $iterator->new( classes     => $class,
                                     handle      => $sth,
                                     bind_params => \@bind,
                                   );
            };
}

use Fey::Meta::Method::Constructor;

sub make_immutable
{
    my $self = shift;

    $self->SUPER::make_immutable
      ( constructor_class => 'Fey::Meta::Method::Constructor',
      );
}


no Moose;
__PACKAGE__->meta()->make_immutable();

1;

__END__

=head1 NAME

Fey::Meta::Class::Table - A metaclass for table classes

=head1 SYNOPSIS

  package MyApp::User;

  use Fey::ORM::Table;

  print __PACKAGE__->meta()->ClassForTable($table);

=head1 DESCRIPTION

This is the metaclass for table classes. When you use
L<Fey::ORM::Table> in your class, it uses this class to do all the
heavy lifting.

=head1 METHODS

This class provides the following methods:

=head2 Fey::Meta::Class::Table->ClassForTable( $table1, $table2 )

Given one or more C<Fey::Table> objects, this method returns the name
of the class which "has" that table, if any.

=head2 Fey::Meta::Class::Table->TableForClass($class)

Given a class, this method returns the C<Fey::Table> object associated
with that class, if any.

=head2 $meta->make_immutable()

This class overrides C<< Moose::Meta::Class->make_immutable() >> in
order to do its own optimizations for immutability.

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
