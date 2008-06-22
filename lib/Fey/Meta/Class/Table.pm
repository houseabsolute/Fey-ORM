package Fey::Meta::Class::Table;

use strict;
use warnings;

use Fey::Exceptions qw( param_error );
use Fey::Validate qw( validate SCALAR_TYPE ARRAYREF_TYPE BOOLEAN_TYPE
                      TABLE_TYPE FK_TYPE SELECT_TYPE
                      CODEREF_TYPE
                    );

use Fey::Hash::ColumnsKey;
use Fey::Object::Iterator;
use Fey::Object::Iterator::Caching;
use Fey::Meta::Attribute::FromSelect;
use Fey::Meta::Class::Schema;
use List::MoreUtils qw( all );

use Moose qw( extends has );
use MooseX::AttributeHelpers;
use MooseX::ClassAttribute;

extends 'MooseX::StrictConstructor::Meta::Class';

class_has '_ClassToTableMap' =>
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

has 'table' =>
    ( is        => 'rw',
      isa       => 'Fey::Table',
      writer    => '_set_table',
      predicate => '_has_table',
    );

has 'inflators' =>
    ( metaclass => 'Collection::Hash',
      is        => 'rw',
      isa       => 'HashRef[CodeRef]',
      default   => sub { {} },
      lazy      => 1,
      provides  => { set    => '_add_inflator',
                     exists => 'has_inflator',
                   },
    );

has 'deflators' =>
    ( metaclass => 'Collection::Hash',
      is        => 'rw',
      isa       => 'HashRef[CodeRef]',
      default   => sub { {} },
      lazy      => 1,
      provides  => { set    => '_add_deflator',
                     get    => 'deflator_for',
                     exists => 'has_deflator',
                   },
    );

has 'schema_class',
    ( is      => 'ro',
      isa     => 'ClassName',
      lazy    => 1,
      default => sub { Fey::Meta::Class::Schema
                           ->ClassForSchema( $_[0]->table()->schema() ) },
    );

has '_select_sql_cache',
    ( is      => 'ro',
      isa     => 'Fey::Hash::ColumnsKey',
      lazy    => 1,
      default => sub { Fey::Hash::ColumnsKey->new() },
    );

has '_select_by_pk_sql',
    ( is        => 'ro',
      isa       => 'Fey::SQL::Select',
      lazy      => 1,
      default   => sub { return $_[0]->name()->_MakeSelectByPKSQL() },
    );

has '_count_sql',
    ( is         => 'ro',
      isa        => 'Fey::SQL::Select',
      lazy_build => 1,
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

    my $map = $class->_ClassToTableMap();

    for my $class_name ( keys %{ $map } )
    {
        my $potential_table = $map->{$class_name};

        return $class_name
            if $potential_table->name()           eq $table->name()
            && $potential_table->schema()->name() eq $table->schema()->name();
    }

    return;
}

sub _search_cache
{
    my $self = shift;
    my $p    = shift;

    my $cache = $self->_object_cache();

    for my $key ( $self->table()->candidate_keys() )
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

    for my $key ( $self->table()->candidate_keys() )
    {
        my @names = map { $_->name() } @{ $key };

        my @pieces = map { $_, $object->$_() } sort @names;

        next unless all { defined } @pieces;

        my $cache_key = join "\0", @pieces;

        $cache->{$cache_key} = $object;
    }
}

sub _associate_table
{
    my $self  = shift;
    my $table = shift;

    my $caller = $self->name();

    param_error 'Cannot call has_table() more than once per class'
        if $self->_has_table();

    param_error 'Cannot associate the same table with multiple classes'
        if $self->ClassForTable($table);

    param_error 'A table object passed to has_table() must have a schema'
        unless $table->has_schema();

    my $class = Fey::Meta::Class::Schema->ClassForSchema( $table->schema() );

    param_error 'You must load your schema class before calling has_table()'
        unless $class
        && $class->can('meta')
        && $class->meta()->_has_schema();

    param_error 'A table object passed to has_table() must have at least one key'
        unless $table->primary_key();

    $self->_SetTableForClass( $self->name() => $table );

    $self->_set_table($table);

    $self->_make_column_attributes();
}

sub _make_column_attributes
{
    my $self = shift;

    my $table = $self->table();

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

    param_error "The column $name does not exist as an attribute"
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
                              init_arg  => undef,
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

        $self->_add_inflator( $name => $inflate_sub );
    }

    if ( $p{deflate} )
    {
        param_error "Cannot provide more than one deflator for a column ($name)"
            if $self->has_deflator($name);

        $self->_add_deflator( $name => $p{deflate} );
    }
}

{
    my $spec = { name        => SCALAR_TYPE( default => undef ),
                 table       => TABLE_TYPE,
                 cache       => BOOLEAN_TYPE( default => 1 ),
                 fk          => FK_TYPE( default => undef ),
                 select      => SELECT_TYPE( default => undef ),
                 bind_params => CODEREF_TYPE( default => sub {} ),
                 handles     => { default => undef },
                 undef       => BOOLEAN_TYPE( default => undef ),
               };

    sub _add_has_one_relationship
    {
        my $self = shift;
        my %p    = validate( @_, $spec );

        param_error 'A table object passed to has_one() must have a schema'
            unless $p{table}->has_schema();

        param_error 'You must call has_table() before calling has_one().'
            unless $self->_has_table();

        $self->_make_has_one(%p);
    }
}

sub _make_has_one
{
    my $self = shift;
    my %p    = @_;

    my $name = $p{name} || lc $p{table}->name();

    my $default_sub;
    if ( $p{select} )
    {
        $default_sub = $self->_make_has_one_default_sub_via_sql(%p);
    }
    else
    {

        $p{fk} ||= $self->_find_one_fk( $p{table}, 'has_one' );

        $p{fk} = $self->_invert_fk_if_necessary( $p{fk}, $p{table} );

        $default_sub = $self->_make_has_one_default_sub_via_fk(%p);
    }

    if ( $p{cache} )
    {
        # If given a select SQL for the has_one relationship we assume
        # it can always be undef, since we don't know the content of
        # the SQL.
        my $can_be_undef = $p{undef};

        unless ( defined $can_be_undef )
        {
            $can_be_undef = $p{select} || grep { $_->is_nullable() } @{ $p{fk}->source_columns() };
        }

        # It'd be nice to set isa to the actual foreign class, but we may
        # not be able to map a table to a class yet, since that depends on
        # the related class being loaded. It doesn't really matter, since
        # this accessor is read-only, so there's really no typing issue to
        # deal with.
        my $type = 'Fey::Object::Table';
        $type = "Maybe[$type]" if $can_be_undef;

        my %attr_p = ( is      => 'rw',
                       isa     => $type,
                       lazy    => 1,
                       default => $default_sub,
                       writer  => q{_set_} . $name,
                       clearer => q{_clear_} . $name,
                     );

        $attr_p{handles} = $p{handles}
            if $p{handles};

        $self->add_attribute( $name, %attr_p );
    }
    else
    {
        $self->add_method( $name => $default_sub );
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
    elsif ( @fk > 1 )
    {
        param_error
            'There is more than one foreign key between the table for this class, '
            . $from->name()
            . " and the table you passed to $func(), "
            . $to->name()
            . '. You must specify one explicitly.';
    }
}

# We may need to invert the meaning of source & target since source &
# target for an FK object are sort of arbitrary. The source should be
# "our" table, and the target the foreign table.
sub _invert_fk_if_necessary
{
    my $self         = shift;
    my $fk           = shift;
    my $target_table = shift;
    my $has_many     = shift;

    # Self-referential keys are a special case, and that case differs
    # for has_one vs has_many.
    if ( $fk->is_self_referential() )
    {
        if ($has_many)
        {
            return $fk
                unless $fk->target_table()->has_candidate_key( @{ $fk->target_columns() } );
        }
        else
        {
            # A self-referential key is a special case. If the target
            # columns are _not_ a key, then we need to invert source &
            # target so we do our select by a key. This doesn't
            # address a pathological case where neither source nor
            # target column sets make up a key. That shouldn't happen,
            # though ;)
            return $fk
                if $fk->target_table()->has_candidate_key( @{ $fk->target_columns() } );
        }
    }
    else
    {
        return $fk
            if $fk->target_table()->name() eq $target_table->name();
    }

    return Fey::FK->new( source_columns => $fk->target_columns(),
                         target_columns => $fk->source_columns(),
                       );
}

sub _make_has_one_default_sub_via_sql
{
    my $self = shift;
    my %p    = @_;

    my $target_table = $p{table};

    my $select = $p{select};
    my $bind   = $p{bind_params};

    # XXX - this is really similar to
    # Fey::Object::Table->_get_column_values() and needs some serious
    # cleanup.
    return
        sub { my $self = shift;

              my $dbh = $self->_dbh($select);

              my $sth = $dbh->prepare( $select->sql($dbh) );

              $sth->execute( $self->$bind() );

              my %col_values;
              $sth->bind_columns( \( @col_values{ @{ $sth->{NAME} } } ) );

              my $fetched = $sth->fetch();

              $sth->finish();

              return unless $fetched;

              $self->meta()->ClassForTable($target_table)->new
                  ( %col_values, _from_query => 1 );
            };
}

sub _make_has_one_default_sub_via_fk
{
    my $self = shift;
    my %p    = @_;

    my $fk = $p{fk};

    my %column_map;
    for my $pair ( $fk->column_pairs() )
    {
        my ( $from, $to ) = @{ $pair };

        $column_map{ $from->name() } = [ $to->name(), $to->is_nullable() ];
    }

    my $target_table = $p{table};

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
                 select      => SELECT_TYPE( default => undef ),
                 bind_params => CODEREF_TYPE( default => sub {} ),
               };

    sub _add_has_many_relationship
    {
        my $self = shift;
        my %p    = validate( @_, $spec );

        param_error 'A table object passed to has_many() must have a schema'
            unless $p{table}->has_schema();

        param_error 'You must call has_table() before calling has_many().'
            unless $self->_has_table();

        $self->_make_has_many(%p);
    }
}

sub _make_has_many
{
    my $self = shift;
    my %p    = @_;

    my $name = $p{name} || lc $p{table}->name();

    my $iterator_class = $p{cache} ? 'Fey::Object::Iterator::Caching' : 'Fey::Object::Iterator';

    my $default_sub;
    if ( $p{select} )
    {
        $default_sub = $self->_make_has_many_default_sub_via_sql( %p, iterator_class => $iterator_class );
    }
    else
    {
        $p{fk} ||= $self->_find_one_fk( $p{table}, 'has_many' );

        $p{fk} = $self->_invert_fk_if_necessary( $p{fk}, $p{table}, 'has many' );

        $default_sub = $self->_make_has_many_default_sub_via_fk( %p, iterator_class => $iterator_class );
    }

    if ( $p{cache} )
    {
        my $attr_name = q{_} . $name;

        $self->add_attribute
            ( $attr_name,
              is      => 'rw',
              isa     => $iterator_class,
              lazy    => 1,
              default => $default_sub,
              writer  => q{_set_} . $name,
              clearer => q{_clear_} . $name,
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

sub _make_has_many_default_sub_via_sql
{
    my $self = shift;
    my %p    = @_;

    my $target_table = $p{table};

    my $select = $p{select};
    my $bind   = $p{bind_params};

    my $iterator_class = $p{iterator_class};

    return
        sub { my $self = shift;

              my $class = $self->meta()->ClassForTable($target_table);

              my $dbh = $self->_dbh($select);

              my $sth = $dbh->prepare( $select->sql($dbh) );

              return $iterator_class->new( classes     => $class,
                                           handle      => $sth,
                                           bind_params => [ $self->$bind() ],
                                         );
            };

}

sub _make_has_many_default_sub_via_fk
{
    my $self = shift;
    my %p    = @_;

    my $target_table = $p{table};

    my $select = $self->schema_class()->SQLFactoryClass()->new_select();
    $select->select($target_table)
           ->from($target_table);

    my @from_list;

    my $ph = Fey::Placeholder->new();
    for my $pair ( $p{fk}->column_pairs() )
    {
        my ( $from, $to ) = @{ $pair };

        $select->where( $to, '=', $ph );

        push @from_list, $from->name();
    }

    $select->order_by( @{ $p{order_by} } )
        if $p{order_by};

    my $bind_params_sub =
        sub { my $self = shift;

              return map { $self->$_() } @from_list;
            };

    return
        $self->_make_has_many_default_sub_via_sql
            ( %p,
              select      => $select,
              bind_params => $bind_params_sub,
            );
}

sub _build__count_sql
{
    my $self = shift;

    my $table = $self->table();

    my $select = $self->schema_class()->SQLFactoryClass()->new_select();

    $select
        ->select( Fey::Literal::Function->new( 'COUNT', '*' ) )
        ->from($table);

    return $select;
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

=head2 $meta->table()

Returns the C<Fey::Table> for the metaclass's class.

=head2 $meta->has_inflator($name)

Returns a boolean indicating whether or not there is an inflator
defined for the named column.

=head2 $meta->has_deflator($name)

Returns a boolean indicating whether or not there is an inflator
defined for the named column.

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
