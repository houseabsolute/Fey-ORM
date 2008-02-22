package Fey::Object::Table;

use strict;
use warnings;

use Fey::Literal::Function;
use Fey::Placeholder;
use Fey::SQL;
use Fey::Table;
use List::MoreUtils qw( all );
use Scalar::Util qw( blessed );

use Fey::Exceptions qw( param_error );
use Exception::Class
    ( 'Fey::Exception::NoSuchRow' =>
      { description => 'No row was found for a specified key.',
        isa         => 'Fey::Exception',
        alias       => 'no_such_row',
      },
    );

use MooseX::StrictConstructor;

extends 'Moose::Object';


sub new
{
    my $class = shift;

    if ( $class->meta()->_object_cache_is_enabled() )
    {
        my $object = $class->meta()->_search_cache( ref $_[0] ? $_[0] : { @_ } );

        return $object if $object;
    }

    my $object = eval { $class->SUPER::new(@_) };

    if ( my $e = $@ )
    {
        return if blessed $e && $e->isa('Fey::Exception::NoSuchRow');

        die $e;
    }

    $class->meta()->_write_to_cache($object)
        if $class->meta()->_object_cache_is_enabled();

    return $object;
}

sub BUILD
{
    my $self = shift;
    my $p    = shift;

    if ( delete $p->{_from_query} )
    {
        $self->_require_pk($p);

        return;
    };

    $self->_load_from_dbms($p);

    return;
}

sub _require_pk
{
    my $self = shift;
    my $p    = shift;

    return if all { defined $p->{$_} } map { $_->name() } $self->Table()->primary_key();

    my $package = ref $self;
    param_error "$package->new() requires that you pass the primary key if you set _from_query to true.";
}

sub EnableObjectCache
{
    my $class = shift;

    $class->meta()->_set_object_cache_is_enabled(1);
}

sub DisableObjectCache
{
    my $class = shift;

    $class->meta()->_set_object_cache_is_enabled(0);
}

sub ClearObjectCache
{
    my $class = shift;

    $class->meta()->_clear_object_cache();
}

sub _load_from_dbms
{
    my $self = shift;
    my $p    = shift;

    for my $key ( $self->Table()->candidate_keys() )
    {
        my @names = map { $_->name() } @{ $key };
        next unless all { defined $p->{$_} } @names;

        return if $self->_load_from_key( $key, [ @{ $p }{ @names } ] );
    }

    my $error = 'Could not find a row in ' . $self->Table()->name();
    $error .= ' matching the values you provided to the constructor.';

    no_such_row $error;
}

sub _load_from_key
{
    my $self = shift;
    my $key  = shift;
    my $bind = shift;

    my $select = $self->_SelectSQLForKey($key);

    return 1 if $self->_get_column_values( $select, $bind );

    my $error = 'Could not find a row in ' . $self->Table()->name();
    $error .= ' where ';

    my @where;

    for ( my $i = 0; $i < @{ $key }; $i++ )
    {
        push @where, $key->[$i]->name() . q{ = } . $bind->[$i];
    }

    $error .= join ', ', @where;

    no_such_row $error;
}

sub insert
{
    my $class = shift;
    my %p     = @_;

    return $class->insert_many(\%p);
}

sub insert_many
{
    my $class = shift;
    my @rows  = @_;

    my $insert = $class->_insert_for_data( $rows[0] );

    my $dbh = $class->_dbh($insert);

    my $sth = $dbh->prepare( $insert->sql($dbh) );

    my @auto_inc_columns =
        ( grep { ! exists $rows[0]->{$_} }
          map { $_->name() }
          grep { $_->is_auto_increment() }
          $class->Table->columns() );

    my $table_name = $class->Table()->name();

    my @non_literal_row_keys;
    my @literal_row_keys;
    my @ref_row_keys;

    for my $key ( sort keys %{ $rows[0] } )
    {
        if ( blessed $rows[0]{$key} && $rows[0]{$key}->isa('Fey::Literal') )
        {
            push @literal_row_keys, $key;
            push @ref_row_keys, $key;
        }
        else
        {
            push @non_literal_row_keys, $key;
            push @ref_row_keys, $key
                if ref $rows[0]{$key};
        }
    }

    my $wantarray = wantarray;

    my @objects;
    for my $row (@rows)
    {
        $sth->execute( map { $class->_deflated_value( $_, $row->{$_} ) }
                       @non_literal_row_keys );

        next unless defined $wantarray;

        for my $col (@auto_inc_columns)
        {
            $row->{$col} = $dbh->last_insert_id( undef, undef, $table_name, $col );
        }

        delete @{ $row }{ @ref_row_keys }
            if @ref_row_keys;

        push @objects, $class->new( %{ $row }, _from_query => 1 );
    }

    return $wantarray ? @objects : $objects[0];
}

sub _deflated_value
{
    my $self = shift;
    my $name = shift;
    my $val  = @_ ? shift : $self->$name();

    my $deflators = $self->_Deflators();

    my $meth = $deflators->{$name};

    return $meth ? $self->$meth($val) : $val;
}

sub _insert_for_data
{
    my $class = shift;
    my $data  = shift;

    my $insert = $class->SchemaClass()->SQLFactoryClass()->new_insert();

    my $table = $class->Table();

    $insert->into( $table->columns( sort keys %{ $data } ) );

    my $ph = Fey::Placeholder->new();

    my @vals =
        ( map { $_ => ( blessed $data->{$_} && $data->{$_}->isa('Fey::Literal') ? $data->{$_} : $ph ) }
          sort keys %{ $data }
        );
    $insert->values(@vals);

    return $insert;
}

sub update
{
    my $self = shift;
    my %p    = @_;

    my $update = $self->SchemaClass()->SQLFactoryClass()->new_update();

    my $table = $self->Table();

    $update->update($table);

    $update->set( map { $table->column($_) => $self->_deflated_value( $_, $p{$_} ) } keys %p );

    for my $col ( $table->primary_key() )
    {
        my $name = $col->name();

        $update->where( $col, '=', $self->_deflated_value($name) );
    }

    my $dbh = $self->_dbh($update);

    $dbh->do( $update->sql($dbh), {}, $update->bind_params() );

    for my $k ( sort keys %p )
    {
        if ( ref $p{$k} )
        {
            my $clear = q{_clear_} . $k;
            $self->$clear();
        }
        else
        {
            my $set = q{_set_} . $k;
            $self->$set( $p{$k} );
        }
    }

    return;
}

sub delete
{
    my $self = shift;

    my $delete = $self->SchemaClass()->SQLFactoryClass()->new_delete();

    my $table = $self->Table();

    $delete->from($table);

    for my $col ( $table->primary_key() )
    {
        my $name = $col->name();

        $delete->where( $col, '=', $self->_deflated_value($name) );
    }

    my $dbh = $self->_dbh($delete);

    $dbh->do( $delete->sql($dbh), {}, $delete->bind_params() );

    return;
}

sub _get_column_value
{
    my $self = shift;

    my $col_values = $self->_get_column_values( $self->_SelectByPKSQL(),
                                                [ $self->_pk_vals() ],
                                              );

    my $name = shift;

    return $col_values->{$name};
}

# Based on discussions on #moose, this could be done more elegantly
# with a custom instance metaclass that lazily initializes a batch of
# attributes at once.
sub _get_column_values
{
    my $self   = shift;
    my $select = shift;
    my $bind   = shift;

    my $dbh = $self->_dbh($select);

    my $sth = $dbh->prepare( $select->sql($dbh) );

    $sth->execute( @{ $bind } );

    my %col_values;
    $sth->bind_columns( \( @col_values{ @{ $sth->{NAME} } } ) );

    my $fetched = $sth->fetch();

    $sth->finish();

    return unless $fetched;

    for my $col ( keys %col_values )
    {
        my $set = q{_set_} . $col;
        my $has = q{has_} . $col;

        $self->$set( $col_values{$col} )
            unless $self->$has();
    }

    return \%col_values;
}

sub _dbh
{
    my $self = shift;
    my $sql  = shift;

    my $source = $self->SchemaClass()->DBIManager()->source_for_sql($sql);

    die "Could not get a source for this sql ($sql)"
        unless $source;

    return $source->dbh();
}

sub _pk_vals
{
    my $self = shift;

    return map { $self->$_() } map { $_->name() } $self->Table()->primary_key();
}

sub _MakeSelectByPKSQL
{
    my $class = shift;

    return $class->_SelectSQLForKey( [ $class->Table->primary_key() ] );
}

sub _SelectSQLForKey
{
    my $class = shift;
    my $key   = shift;

    my $cache = $class->_SelectSQLCache();

    my $select = $cache->get($key);

    return $select if $select;

    my $table = $class->Table();

    my %key = map { $_->name() => 1 } @{ $key };

    my @non_key =
        grep { ! $key{ $_->name() } } $table->columns();

    $select = $class->SchemaClass()->SQLFactoryClass()->new_select();
    $select->select( sort { $a->name() cmp $b->name() } @non_key );
    $select->from($table);
    $select->where( $_, '=', Fey::Placeholder->new() ) for @{ $key };

    $cache->store( $key => $select );

    return $select;
}

sub Count
{
    my $class = shift;

    my $select = $class->_CountSQL();

    my $dbh = $class->_dbh($select);

    my $row = $dbh->selectcol_arrayref( $select->sql($dbh) );

    return $row->[0];
}

sub _MakeCountSQL
{
    my $class = shift;

    my $table = $class->Table();

    my $select = $class->SchemaClass()->SQLFactoryClass()->new_select();

    $select
        ->select( Fey::Literal::Function->new( 'COUNT', '*' ) )
        ->from($table);

    return $select;
}

no Moose;
__PACKAGE__->meta()->make_immutable();

1;

__END__

=head1 NAME

Fey::Object::Table - Base class for table-based objects

=head1 SYNOPSIS

  package MyApp::User;

  use Fey::ORM::Table;

  has_table(...);

=head1 DESCRIPTION

This class is a the base class for all table-based objects. It
implements a large amount of the core L<Fey::ORM> functionality,
including CRUD (create, update, delete) and loading of data from the
DBMS.

=head1 METHODS

This class provides the following methods:

=head2 $class->new(...)

This method overrides the default C<Moose::Object> constructor in
order to implement cache management.

By default, object caching is disabled. In that case, this method lets
its parent class do most of the work. However, unlike the standard
Moose constructor, this method may sometimes not return an object. If
it attempts to load object data from the DBMS and cannot find anything
matching the parameters given to the constructor, it will return
false. When this happens you can check C<$@> for details on the error.

If caching is enabled, then this method will attempt to find a
matching object in the cache. A match is determined by looking for an
object which has a candidate key with the same values as are passed to
the constructor.

If no match is found, it attempts to create a new object. If this
succeeds, it stores it in the cache before returning it.

=head3 Constructor Parameters

The constructor accepts any attribute of the class as a
parameter. This includes any column-based attributes, as well as any
additional attributes defined by C<has_one()> or C<has_many()>. Of
course, if you disabled caching for C<has_one()> or C<has_many()>
relationships, then they are implemented as simple methods, not
attributes.

If you define additional methods via Moose's C<has()> function, and
these will be accepted by the constructor as well.

Finally, the constructor accepts a parameter C<_from_query>. This
tells the constructor that the parameters passed to the constructor
are the result of a C<SELECT>. This stops the C<BUILD()> method from
attempting to load the object from the DBMS. However, you still must
pass values for the primary key, so that the object is identifiable in
the DBMS.

=head2 $class->EnableObjectCache()

=head2 $class->DisableObjectCache()

These methods enable or disable the object cache for the calling
class.

=head2 $class->Count()

Returns the number of rows in the class's associated table.

=head2 $class->ClearObjectCache()

Clears the object cache for the calling class.

=head2 $class->insert(%values)

Given a hash of column names and values, this method inserts a new row
for the class's table, and returns a new object for that row.

The values for the columns can be plain scalars or object. Values will
be passed through the appropriate deflators. You can also pass
C<Fey::Literal> objects of any type.

As an optimization, no objects will be created in void context.

=head2 $class->insert_many( \%values, \%values, ... )

This method allows you to insert multiple rows efficiently. It expects
an array of hash references. Each hash reference should contain the
same set of column names as keys. The advantage of using this method
is that under the head it uses the same C<DBI> statement handle
repeatedly.

In scalar context, it returns the first object created. In list
context, it returns all the objects created.

As an optimization, no objects will be created in void context.

=head2 $object->update(%values)

This method accepts a hash of column keys and values, just like C<<
$class->insert() >>. However, it instead updates the values for an
existing object's row. It will also make sure that the object's
attributes are updated properly. In some cases, it will just clear the
attribute, forcing it to be reloaded the next time it is
accessed. This is necesasry when the update value was a
C<Fey::Literal>, since that could be a function that gets interpreted
by the DBMS, such as C<NOW()>.

=head2 $object->delete()

This method delete's the object's associated row from the DBMS.

The object is still usable after this method is called, but if you
attempt to call any method that tries to access the DBMS it will
probably blow up.

=head1 METHODS FOR SUBCLASSES

Since your table-based class will be a subclass of this object, there
are several methods you'll want to use that are not intended for use
outside of your subclasses:

=head2 $class->_dbh($sql)

Given a C<Fey::SQL> object, this method returns an appropriate C<DBI>
object for that SQL. Internally, it calls C<source_for_sql()> on the
schema class's C<Fey::DBIManager> object and then calls C<<
$source->dbh() >> on the source.

If there is no source for the given SQL, it will die.

=head2 $object->_pk_vals()

This method returns an array of primary key values for the object's
row.

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
