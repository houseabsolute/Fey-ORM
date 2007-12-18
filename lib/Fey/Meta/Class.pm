package Fey::Meta::Class;

use strict;
use warnings;

use Fey::Exceptions qw( param_error );
use Fey::Validate qw( validate TABLE_TYPE FK_TYPE BOOLEAN_TYPE );

use Moose;
use MooseX::AttributeHelpers;
use MooseX::ClassAttribute;

extends 'MooseX::StrictConstructor::Meta::Class';

has 'table' =>
    ( is        => 'rw',
      isa       => 'Fey::Table',
      writer    => '_set_table',
      predicate => 'has_table',
    );

has 'inflators' =>
    ( metaclass => 'Collection::Hash',
      is        => 'rw',
      isa       => 'HashRef[CodeRef]',
      default   => sub { {} },
      lazy      => 1,
      provides  => { get    => 'get_inflator',
                     set    => 'set_inflator',
                     exists => 'has_inflator',
                   },
    );

has 'deflators' =>
    ( metaclass => 'Collection::Hash',
      is        => 'rw',
      isa       => 'HashRef[CodeRef]',
      default   => sub { {} },
      lazy      => 1,
      provides  => { get    => 'get_deflator',
                     set    => 'set_deflator',
                     exists => 'has_deflator',
                   },
    );

# XXX - how to do this?
sub _make_class_attributes
{
    my $caller = shift;
    my $table  = shift;

    MooseX::ClassAttribute::process_class_attribute
        ( $caller,
          '_RowSQL' =>
          ( is        => 'rw',
            isa       => 'Fey::SQL',
            lazy      => 1,
            default   => sub { return $_[0]->_MakeRowSQL() },
          )
        );

    MooseX::ClassAttribute::process_class_attribute
        ( $caller,
          '_Manager' =>
          ( is  => 'rw',
            isa => 'Fey::DBIManager',
          )
        );
}

sub set_table
{
    my $self  = shift;
    my $table = shift;

    param_error 'Cannot call set_table() more than once per class'
        if $self->has_table();

    param_error 'A table object passed to has_table() must have a schema'
        unless $table->has_schema();

    param_error 'A table object passed to has_table() must have at least one key'
        unless $table->primary_key();

    $self->_set_table($table);

    #_make_class_attributes( $caller, $table );

    $self->_make_column_attributes($table);
}

sub _make_column_attributes
{
    my $self = shift;

    my $table = $self->table();

    my %pk = map { $_->name() => 1 } $table->primary_key();

    for my $column ( $table->columns() )
    {
        my $name = $column->name();

        next if $self->has_method($name);

        my %default_or_required =
            ( $pk{$name}
              ? ( required => 1 )
              : ( lazy    => 1,
                  default => sub { $_[0]->_get_column_value($name) } )
            );

        $self->_process_attribute
            ( $name,
              is  => 'ro',
              isa => $self->_type_for_column($column),
              %default_or_required,
            );
    }
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

        $self->_process_attribute( $cache_name,
                                   is        => 'rw',
                                   writer    => $cache_set,
                                   predicate => $cache_predicate,
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

        $self->set_inflator( $name => $inflate_sub );
    }

    if ( $p{deflate} )
    {
        param_error "Cannot provide more than one deflator for a column ($name)"
            if $self->has_deflator($name);

        $self->set_deflator( $name => $p{deflate} );
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
            unless $self->has_table();

        $p{fk} ||= $self->_find_one_fk( $p{table}, 'has_one' );

        $self->_make_has_one_attribute(%p);
    }
}

sub _find_one_fk
{
    my $self = shift;
    my $to   = shift;
    my $func = shift;

    my $from = $self->table();

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
        $self->_process_attribute
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
                      ->TableToClass($table)
                      ->new( map { $_ => $self->$_() }
                             @column_names );
            };
}


no Moose;

__PACKAGE__->meta()->make_immutable();

1;
