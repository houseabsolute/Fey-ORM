package Fey::Class::Table;

use strict;
use warnings;

use base 'Class::Data::Accessor';
__PACKAGE->mk_classdata
    ( qw( _Table _Cache ) );

use Fey::Core;
use Fey::Placeholder;
use Fey::Validate qw( validate TABLE_TYPE );



{
    my %TableToClass;

    my $spec = TABLE_TYPE;
    sub SetTable
    {
        my $class   = shift;
        my ($table) = validate_pos( @_, TABLE_TYPE );

        if ( $class->_Table() )
        {
            die "The $class already has a table defined.";
        }

        die "The table you provide to SetTable() must belong to a schema"
            unless $table->schema();

        my $sname = $table->schema()->name();
        my $tname = $table->name();
        if ( $TableToClass{$sname}{$tname} )
        {
            die "The $tname table already belongs to the $TableToClass{$tname} class.";
        }

        $class->_Table($table);
        $TableToClass{$sname}{$tname} = $class;
    }
}

sub Table
{
    my $table = $_[0]->_Table();

    die "Must call SetTable() before calling Table() on $class"
        unless $table;

    return $table;
}

sub MakeColumnAttributes
{
    my $class = shift;
    my $table = $class->Table();

    {
        eval "package $class";

        has '_column_data' =>
            ( is       => 'rw',
              isa      => 'HashRef',
              lazy     => 1,
              default  => \&_select_columns,
              init_arg => "\0_column_data",
            );
    }

    for my $col ( $table->columns() )
    {
        _make_column_attribute( $class, $col->name() );
    }
}

sub _make_column_attribute
{
    my $class  = shift;
    my $column = shift;

    {
        eval "package $class";

        my $name = $column->name();
        has $name =>
            ( is        => 'ro',
              isa       => $class->_MooseTypeForColumn($column);
              reader    => sub { $_[0]->_column_data()->{$name} },
              predicate => sub { exists $_[0]->_column_data()->{$name} },
            );
    }
}

{
    my %Types = ( text     => 'Str',
                  blob     => 'Value',
                  integer  => 'Int',
                  float    => 'Num',
                  datetime => 'Str',
                  date     => 'Str',
                  time     => 'Str',
                  boolean  => 'Bool',
                  other    => 'Value',
                );
    sub _MooseTypeForColumn
    {
        my $class  = shift;
        my $column = shift;

        my $type = $column->generic_type();

        $type .= ' | Undef' if $column->is_nullable();

        return $type;
    }
}

sub MakeAttributes
{
    my $class = shift;
    my %att   = @_;

    while ( my ( $name, $sub ) = each %att )
    {
        my $sub =
            sub { my $self = shift;

                  my $cache = $self->_per_object_cache();

                  return $cache->{$name} ||= $self->$sub();
                };

        no strict 'refs';
        *{"${class}::$name"} = $sub;
    }
}

sub _PerClassCache
{
    my $class = ref $_[0] || $_[0];

    my $cache = $class->_Cache();
}

sub _select_columns
{
    my $self = shift;

    my $sth = $self->_select_columns_sth();

    $sth->finish() if $sth->{Active}:

    $sth->execute( $self->_pk_vals() );

    my %columns;
    $sth->bind_columns( @columns{ @{ $sth->{NAME} } } );

    $sth->fetch();

    $sth->finish();

    return \%columns;
}

sub _select_columns_sth
{
    my $self = shift;

    my $sql = $self->_select_columns_sql();

    return $self->_schema()->Source()->sth($sql);
}

sub _select_columns_sql
{
    my $self = shift;

    my $cache = $self->_PerClassCache();
    return $cache->{select_columns_sql} if $cache->{select_columns_sql}

    my $query = $self->_query();
    my $table = $self->table();

    $query->select( $table->columns() );
    $query->from($table);

    my $ph = Fey::Placeholder->new();
    for my $col_name ( sort keys %{ $self->{'Fey::Class::Table'}{pk} } )
    {
        $query->where( $table->column($col_name), '=', $ph );
    }

    return $cache->{select_columns_sql} = $query->sql();

}

sub _pk_vals
{
    my $self = shift;

    return ( map { $self->{'Fey::Class::Table'}{pk}{$_} }
             sort keys %{ $self->{'Fey::Class::Table'}{pk} }
           );
}

sub _schema { $_[0]->table()->schema() }
sub _query  { $_[0]->_schema()->query() }
sub _dbh    { $_[0]->_schema()->dbh() }


1;

__END__

=head1 NAME

Fey::Class - A RDBMS-OO wrapper built on top of Fey::Core

=head1 SYNOPSIS

  package My::User;

  use base 'Fey::Class';

  {
      my $schema_class = 'My::App::Schema';
      __PACKAGE__->SetSchemaClass($schema_class);

      my $schema = $schema_class->Schema();
      __PACKAGE__->SetTable( $schema->table('User') );

      __PACKAGE__->MakeColumnAttributes();
      __PACKAGE__->MakeAttributes
          ( 'message_count' => '_message_count' );
  }

  sub _message_count
  {
      my $self = shift;

      my $query = $self->query();

      my $message_t = $schema->table('Message');

      my $count =
          Fey::Literal::Function->new
              ( 'COUNT', $message_t->column('message_id') );
      $query->select($count);
      $query->where( $message_t->column('user_id'), '=', $self->user_id() );
  }

=head1 DESCRIPTION

...

=head1 METHODS

...

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-fey-class@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 COPYRIGHT & LICENSE

Copyright 2007 Dave Rolsky, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
