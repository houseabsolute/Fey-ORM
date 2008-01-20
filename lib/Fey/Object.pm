package Fey::Object;

use strict;
use warnings;

use Fey::Literal::Function;
use Fey::Placeholder;
use Fey::SQL;
use Fey::Table;
use List::MoreUtils qw( all );
use Scalar::Util qw( blessed );

use Fey::Exceptions;
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

    if ( $class->ObjectCacheIsEnabled() )
    {
        my $object = $class->SearchCache( ref $_[0] ? $_[0] : { @_ } );

        return $object if $object;
    }

    my $self = eval { $class->SUPER::new(@_) };

    if ( my $e = $@ )
    {
        return if blessed $e && $e->isa('Fey::Exception::NoSuchRow');

        die $e;
    }

    $class->WriteToCache($self)
        if $class->ObjectCacheIsEnabled();

    return $self;
}

sub BUILD
{
    my $self = shift;
    my $p    = shift;

    return if delete $p->{_from_query};

    $self->_load_from_dbms($p);

    return;
}

sub SearchCache
{
    my $class = shift;
    my $p     = shift;

    my $cache = $class->_ObjectCache();

    for my $key ( $class->Table()->candidate_keys() )
    {
        my @names = map { $_->name() } @{ $key };
        next unless all { defined $p->{$_} } @names;

        my $cache_key = join "\0", map { $_, $p->{$_} } sort @names;

        return $cache->{$cache_key}
            if exists $cache->{$cache_key};
    }
}

sub WriteToCache
{
    my $class  = shift;
    my $object = shift;

    my $cache = $class->_ObjectCache();

    for my $key ( $class->Table()->candidate_keys() )
    {
        my @names = map { $_->name() } @{ $key };

        my $cache_key = join "\0", map { $_, $object->$_() } sort @names;

        $cache->{$cache_key} = $object;
    }
}

sub EnableObjectCache
{
    my $class = shift;

    $class->_ObjectCacheIsEnabled(1);
}

sub DisableObjectCache
{
    my $class = shift;

    $class->_ObjectCacheIsEnabled(0);
}

sub _load_from_dbms
{
    my $self = shift;
    my $p    = shift;

    for my $key ( $self->Table()->candidate_keys() )
    {
        my @names = map { $_->name() } @{ $key };
        next unless all { defined $p->{$_} } @names;

        $self->_load_from_key( $key, [ @{ $p }{ @names } ] );
    }
}

sub _load_from_key
{
    my $self = shift;
    my $key  = shift;
    my $bind = shift;

    my $select = $self->_SelectSQLForKey($key);

    return if $self->_get_column_values( $select, $bind );

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

    my @non_ref_row_keys;
    my @ref_row_keys;

    for my $key ( sort keys %{ $rows[0] } )
    {
        if ( ref $rows[0]->{$key} )
        {
            push @ref_row_keys, $key;
        }
        else
        {
            push @non_ref_row_keys, $key;
        }
    }

    my $wantarray = wantarray;

    my @objects;
    for my $row (@rows)
    {
        $sth->execute( @{ $row }{ @non_ref_row_keys } );

        next unless defined $wantarray;

        for my $col (@auto_inc_columns)
        {
            $row->{$col} = $dbh->last_insert_id( undef, undef, $table_name, $col );
        }

        delete @{ $row }{ @ref_row_keys }
            if @ref_row_keys;

        push @objects, $class->new($row);
    }

    return $wantarray ? @objects : $objects[0];
}

sub _insert_for_data
{
    my $class = shift;
    my $data  = shift;

    my $insert = $class->SchemaClass()->SQLFactoryClass()->new_insert();

    my $table = $class->Table();

    $insert->into( $table->columns( sort keys %{ $data } ) );

    my $ph = Fey::Placeholder->new();

    $insert->values( map { $_ => ref $data->{$_} ? $data->{$_} : $ph } sort keys %{ $data } );

    return $insert;
}

sub update
{
    my $self = shift;
    my %p    = @_;

    my $update = $self->SchemaClass()->SQLFactoryClass()->new_update();

    my $table = $self->Table();

    $update->update($table);

    my $ph = Fey::Placeholder->new();

    my @bind;
    for my $k ( keys %p )
    {
        $update->set( $table->column($k) => ref $p{$k} ? $p{$k} : $ph );

        push @bind, $p{$k}
            unless ref $p{$k};
    }

    for my $col ( $table->primary_key() )
    {
        my $name = $col->name();

        $update->where( $col, '=', $ph );

        push @bind, $self->$name();
    }

    my $dbh = $self->_dbh($update);

    $dbh->do( $update->sql($dbh), {}, @bind );

    for my $k ( keys %p )
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

    my @non_key = grep { ! $key{ $_->name() } } $table->columns();

    $select = $class->SchemaClass()->SQLFactoryClass()->new_select();
    $select->select(@non_key);
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
