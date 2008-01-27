package Fey::Meta::Class::Table;

use strict;
use warnings;

use Fey::Exceptions qw( param_error );
use Fey::Validate qw( validate TABLE_TYPE FK_TYPE BOOLEAN_TYPE );

use Fey::Hash::ColumnsKey;
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

has 'object_cache_is_enabled' =>
    ( is      => 'rw',
      isa     => 'Bool',
      lazy    => 1,
      default => 0,
      writer  => 'set_object_cache_is_enabled',
    );

has '_object_cache' =>
    ( is      => 'ro',
      isa     => 'HashRef',
      lazy    => 1,
      default => sub { {} },
      clearer => 'clear_object_cache',
    );

sub ClassForTable
{
    my $class = shift;
    my $table = shift;

    my $map = $class->_TableClassMap();

    for my $class_name ( keys %{ $map } )
    {
        return $class_name
            if $map->{$class_name}->name() eq $table->name();
    }

    return;
}

sub search_cache
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

sub write_to_cache
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

sub has_table
{
    my $self  = shift;
    my $table = shift;

    my $caller = $self->name();

    param_error 'Cannot call has_table() more than once per class'
        if $caller->can('HasTable') && $caller->HasTable();

    param_error 'Cannot associate the same table with multiple classes'
        if __PACKAGE__->ClassForTable($table);

    param_error 'A table object passed to has_table() must have a schema'
        unless $table->has_schema();

    my $class = Fey::Meta::Class::Schema->ClassForSchema( $table->schema() );

    param_error 'You must load your schema class before calling has_table()'
        unless $class
        && $class->can('meta')
        && $class->can('HasSchema')
        && $class->HasSchema();

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
            predicate => 'HasTable',
          ),
        );

    MooseX::ClassAttribute::process_class_attribute
        ( $caller,
          'Inflators',
          ( metaclass => 'Collection::Hash',
            is        => 'rw',
            isa       => 'HashRef[CodeRef]',
            default   => sub { {} },
            lazy      => 1,
            provides  => { get    => 'GetInflator',
                           set    => 'SetInflator',
                           exists => 'HasInflator',
                         },
          ),
        );

    MooseX::ClassAttribute::process_class_attribute
        ( $caller,
          'Deflators',
          ( metaclass => 'Collection::Hash',
            is        => 'rw',
            isa       => 'HashRef[CodeRef]',
            default   => sub { {} },
            lazy      => 1,
            provides  => { get    => 'GetDeflator',
                           set    => 'SetDeflator',
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

sub add_transform
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

        $self->name()->SetInflator( $name => $inflate_sub );
    }

    if ( $p{deflate} )
    {
        param_error "Cannot provide more than one deflator for a column ($name)"
            if $self->name()->HasDeflator($name);

        $self->name()->SetDeflator( $name => $p{deflate} );
    }
}

{
    my $spec = { table => TABLE_TYPE,
                 cache => BOOLEAN_TYPE( default => 1 ),
                 fk    => FK_TYPE( default => undef ),
               };

    sub add_has_one_relationship
    {
        my $self = shift;
        my %p    = validate( @_, $spec );

        param_error 'A table object passed to has_one() must have a schema'
            unless $p{table}->has_schema();

        param_error 'You must call has_table() before calling has_one().'
            unless $self->name()->HasTable();

        $p{fk} ||= $self->_find_one_fk( $p{table}, 'has_one' );

        $self->_make_has_one_attribute(%p);
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
            'There is more than one foreign keys between the table for this class, '
            . $from->name()
            . " and the table you passed to $func(), "
            . $to->name()
            . '. You must specify one explicitly.';
    }
}

sub _make_has_one_attribute
{
    my $self = shift;
    my %p    = @_;

    # XXX - names should be settable via a Fey::Class::Policy
    my $name = $p{name} || lc $p{table}->name();

    my $default_sub = _make_has_one_default_sub(%p);

    if ( $p{cache} )
    {
        # It'd be nice to set isa to the actual foreign class, but we may
        # not be able to map a table to a class yet, since that depends on
        # the related class being loaded. It doesn't really matter, since
        # this accessor is read-only, so there's really no typing issue to
        # deal with.
        $self->add_attribute
            ( $name,
              is      => 'ro',
              isa     => 'Fey::Object',
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
    my %p = @_;

    my $table = $p{table};
    my @column_names = map { $_->name() } $p{fk}->source_columns();

    return
        sub { my $self = shift;

              return
                  Fey::Meta::Class
                      ->ClassForTable($table)
                      ->new( map { $_ => $self->$_() }
                             @column_names );
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
