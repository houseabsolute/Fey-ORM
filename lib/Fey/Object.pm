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

    return if delete $p->{_from_query};

    $self->_load_from_dbms($p);

    return;
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

        push @objects, $class->new($row);
    }

    return $wantarray ? @objects : $objects[0];
}

sub _deflated_value
{
    my $self = shift;
    my $name = shift;
    my $val  = @_ ? shift : $self->$name();

    my $deflators = $self->Deflators();

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

    my @non_key = grep { ! $key{$_} } $table->columns();

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
