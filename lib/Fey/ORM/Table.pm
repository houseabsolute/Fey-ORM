package Fey::ORM::Table;

use strict;
use warnings;

our @EXPORT = ## no critic ProhibitAutomaticExportation
    qw( has_table has_one has_many transform inflate deflate );
use base 'Exporter';

use Fey::Meta::Class::Table;
use Fey::Object;
use Fey::Validate qw( validate_pos TABLE_TYPE );
use Moose ();


# This re-exporting is a mess. Once MooseX::Exporter is done,
# hopefully it can replace all of this.
sub import
{
    my $caller = Moose::_get_caller();

    return if $caller eq 'main';

    Moose::init_meta( $caller,
                      'Fey::Object',
                      'Fey::Meta::Class::Table',
                    );

    Moose->import( { into => $caller } );

    __PACKAGE__->export_to_level( 1, @_ );

    return;
}

sub unimport ## no critic RequireFinalReturn
{
    my $caller = caller();

    no strict 'refs'; ## no critic ProhibitNoStrict
    foreach my $name (@EXPORT)
    {
        if ( defined &{ $caller . '::' . $name } )
        {
            my $keyword = \&{ $caller . '::' . $name };

            my $pkg_name =
                eval { svref_2object($keyword)->GV()->STASH()->NAME() };

            next if $@;
            next if $pkg_name ne __PACKAGE__;

            delete ${ $caller . '::' }{$name};
        }
    }

    Moose::unimport( { into_level => 1 } );
}

{
    my $spec = ( TABLE_TYPE );
    sub has_table
    {
        my ($table) = validate_pos( @_, $spec );

        my $caller = caller();

        $caller->meta()->_has_table($table);
    }
}

sub transform
{
    my @p;

    push @p, pop @_ while ref $_[-1];

    my %p = _combine_hashes(@p);

    my $caller = caller();

    for my $name (@_)
    {
        $caller->meta()->_add_transform( $name => %p );
    }
}

sub _combine_hashes
{
    return map { %{ $_ } } @_;
}

sub inflate (&)
{
    return { inflate => $_[0] };
}

sub deflate (&)
{
    return { deflate => $_[0] };
}

{
    my $simple_spec = ( TABLE_TYPE );

    sub has_one
    {
        my %p;
        if ( @_ == 1 )
        {
            ( $p{table} ) = validate_pos( @_, $simple_spec );
        }
        else
        {
            $p{name} = shift;

            %p = ( %p, @_ );
        }

        my $caller = caller();

        $caller->meta()->_add_has_one_relationship(%p);
    }
}

{
    my $simple_spec = ( TABLE_TYPE );

    sub has_many
    {
        my %p;
        if ( @_ == 1 )
        {
            ( $p{table} ) = validate_pos( @_, $simple_spec );
        }
        else
        {
            $p{name} = shift;

            %p = ( %p, @_ );
        }

        my $caller = caller();

        $caller->meta()->_add_has_many_relationship(%p);
    }
}

1;

__END__

=head1 NAME

Fey::ORM::Table - Provides sugar for table-based classes

=head1 SYNOPSIS

  package MyApp::User;

  use Fey::ORM::Table;

  has_table ...;

  no Fey::ORM::Table;

=head1 DESCRIPTION

Use this class to associate your class with a table. It exports a
number of sugar functions to allow you to define things in a
declarative manner.

=head1 EXPORTED FUNCTIONS

This package exports the following functions:

=head2 has_table($table)

Given a C<Fey::Table> object, this method associates that table with
the calling class.

Calling C<has_table()> will make your class a subclass of
L<Fey::Object>, which provides basic CRUD operations for
L<Fey::ORM>. You should make sure to review the docs for
L<Fey::Object>.

Calling this function also generates a number of methods and
attributes in the calling class.

First, it generates one attribute for each column in the associated
table. Of course, this assumes that your columns are namde in such a
way as to be usable as Perl methods.

It also generates a predicate for each attribute, where the predicate
is the column named prefixed with "has_". So for a column named
"user_id", you get a C<user_id()> attribute and a C<has_user_id()>
predicate.

These column-named attributes do not have a public setter method. If
you want to change the value of these attributes, you need to use the
C<update()> method.

Finally, it will create a number of class methods in the calling
class:

=head3 CallingClass->Table()

Returns the L<Fey::Table> object passed to C<has_table()>.

=head3 CallingClass->HasInflator($name)

Returns a boolean indicating whether or not there is an inflator
defined for the named column.

=head3 CallingClass->HasDeflator($name)

Returns a boolean indicating whether or not there is an inflator
defined for the named column.

=head3 CallingClass->SchemaClass()

Returns the name of the class associated with the caller's table's
schema.

=head2 has_one($table)

=head2 has_one 'name' => ( table => $table, fk => $fk, cache => $bool )

The C<has_one()> function declares a relationship between the calling
class's table and another table. The method it creates returns an
object of the foreign table's class.

With the single-argument form, you can simply pass a single
C<Fey::Table> object. This works when there is a single foreign key
between the calling class's table and the table passed to
C<has_one()>.

With a single argument, the generated attribute will be named as C<<
lc $has_one_table->name() >>, and caching will be turned on.

If you want to change any of the defaults, you can use the
multi-argument form. In this case, the first argument is the name of
the attribute or method to add. Then you can specify various
parameters by name. You must spceify a C<table>, of course.

The C<fk> parameter is required when there is more than one foreign
key between the two tables. Finally, you can turn off caching by
setting C<cache> to a false value.

When caching is enabled, the object for the foreign table is only
fetched once, and is cached afterwards. This is independent of the
object caching for a particular class. If you turn off caching, then
the object is fetched every time the method is called.

=head2 has_many($table)

=head2 has_many 'name' => ( table => $table, fk => $fk, cache => $bool, order_by => [ ... ] )

The C<has_many()> function declares a relationship between the calling
class's table and another table, just like C<has_one()>. The method it
creates returns a C<Fey::Object::Iterator> of the foreign table's
objects.

With the single-argument form, you can simply pass a single
C<Fey::Table> object. This works when there is a single foreign key
between the calling class's table and the table passed to
C<has_many()>.

With a single argument, the generated attribute will be named as C<<
lc $has_one_table->name() >>, and caching will be turned off. There
will be no specific order to the results returned.

If you want to change any of the defaults, you can use the
multi-argument form. In this case, the first argument is the name of
the attribute or method to add. Then you can specify various
parameters by name. You must spceify a C<table>, of course.

The C<fk> parameter is required when there is more than one foreign
key between the two tables. Finally, you can turn on caching by
setting C<cache> to a true value.

When caching is enabled, the iterator returned is of the
C<Fey::Object::Iterator::Caching> class.

You can also specify an C<order_by> parameter as an array
reference. This should be an array like you would pass to C<<
Fey::SQL::Select->order_by() >>.

=head2 transform $column => inflate { ... }, deflate { ... }

The C<transform()> function declares an inflator, deflator, or both
for the specified column. The inflator will be used to wrap the normal
accessor for the column. You'd generally use this to turn a raw value
from the DBMS into an object, for example:

  transform 'creation_date' =>
      inflate { DateTime::Format::Pg->parse_date( $_[1] ) };

The inflator (and deflator) coderef you specify will be called as a
I<method> on the object (or class). This lets you get at other
attributes for the object if needed.

When a column is inflated, a new attribute is created to allow you to
get at the raw data by suffixing the column name with "_raw". Given
the above inflator, a C<creation_date_raw()> attribute would be
created.

If the column in question is nullable your inflator should be prepared
to handle an undef value for the column.

Deflators are used to transform objects passed to C<update()> or
C<insert()> into values suitable for passing to the DBMS:

  transform 'creation_date' =>
      deflate { defined $_[1] && ref $_[1]
                  ? DateTime::Format::Pg->format_date( $_[1] )
                  : $_[1] };

Just as with an inflator, your deflator should be prepared to accept
an undef if the column is nullable.

You can only declare one inflator and one deflator for each column.

=head2 inflate { .. }

=head2 deflate { .. }

These are sugar functions that accept a single coderef. They mostly
exist to prevent you from having to write this:

  transform 'creation_date' =>
      ( inflator => sub { ... },
        deflator => sub { ... },
      );

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
