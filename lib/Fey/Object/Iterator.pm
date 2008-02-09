package Fey::Object::Iterator;

use strict;
use warnings;

use Fey::Exceptions qw( param_error );
use List::MoreUtils qw( pairwise );

use Moose::Policy 'MooseX::Policy::SemiAffordanceAccessor';
use MooseX::AttributeHelpers;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

subtype 'ArrayRefOfClasses'
    => as 'ArrayRef',
    => where { return unless @{$_};
               return if grep { ! $_->isa('Fey::Object') } @{ $_ };
               return 1;
             };

coerce 'ArrayRefOfClasses'
    => from 'ClassName'
    => via { return [ $_ ] };

has classes =>
    ( is     => 'ro',
      isa    => 'ArrayRefOfClasses',
      coerce => 1,
    );

has handle =>
    ( is  => 'ro',
      isa => 'DBI::st',
    );

has bind_params =>
    ( is      => 'ro',
      isa     => 'ArrayRef',
      default => sub { [] },
    );

has index =>
    ( metaclass => 'Counter',
      is       => 'ro',
      isa      => 'Int',
      default  => 0,
      init_arg => "\0index",
      provides => { 'inc'   => '_inc_index',
                    'reset' => '_reset_index',
                  },
    );

has _executed =>
    ( is      => 'rw',
      isa     => 'Bool',
      default => 0,
    );

has _row =>
    ( is      => 'ro',
      isa     => 'HashRef',
      default => sub { return {} },
    );

has _attribute_map =>
    ( is      => 'ro',
      isa     => 'HashRef[ArrayRef[Str]]',
      lazy    => 1,
      default => sub { return $_[0]->_make_attribute_map() },
    );

no Moose;
__PACKAGE__->meta()->make_immutable();


sub next
{
    my $self = shift;

    my $result = $self->_get_next_result();

    return unless $result;

    $self->_inc_index();

    return wantarray ? @{ $result } : $result->[0];
}

sub _get_next_result
{
    my $self = shift;

    my $sth = $self->_executed_handle();

    return unless $sth->fetch();

    my $map = $self->_attribute_map();

    my $row = $self->_row();

    my @result;
    for my $class ( @{ $self->classes() } )
    {
        my %attr = map { $_ => $row->{$_} } grep { exists $row->{$_ } } @{ $map->{$class} };
        $attr{_from_query} = 1;

        # We eval since in an outer join the primary key may be undef
        push @result, eval { $class->new( \%attr ) } || undef;
    }

    return \@result;
}

sub _executed_handle
{
    my $self = shift;

    my $sth = $self->handle();

    return $sth if $self->_executed();

    my $row = $self->_row();

    $sth->execute( @{ $self->bind_params() } );

    $sth->bind_columns( \( @{ $row }{ @{ $sth->{NAME_lc} } } ) );

    $self->_set_executed(1);

    return $sth;
}

sub _make_attribute_map
{
    my $self = shift;

    return { map { $_ => [ map { lc } grep { ! /^_/ }
                           $_->meta()->get_attribute_list() ] }
             @{ $self->classes() }
           };
}

sub all
{
    my $self = shift;

    my @result;
    while ( my @r = $self->next() )
    {
        push @result, @r == 1 ? @r : \@r;
    }

    return @result;
}

sub next_as_hash
{
    my $self = shift;

    my @result = $self->next();

    return unless @result;

    return
        pairwise { $a->Table()->name() => $b }
        @{ $self->classes() }, @result;
}

sub all_as_hashes
{
    my $self = shift;

    my @result;
    while ( my %r = $self->next_as_hash() )
    {
        push @result, \%r;
    }

    return @result;
}

sub reset
{
    my $self = shift;

    $self->_set_executed(0);
    $self->_reset_index();

    return;
}

sub DEMOLISH
{
    my $self = shift;

    if ( my $sth = $self->handle() )
    {
        $sth->finish() if $sth->{Active};
    }
}

no Moose;
__PACKAGE__->meta()->make_immutable();

1;

__END__

=head1 NAME

Fey::Object::Iterator - Wraps a DBI statement handle to construct objects from the results

=head1 SYNOPSIS

  use Fey::Object::Iterator;

  my $iter =
      Fey::Object::Iterator->new
          ( classes     => 'MyApp::User',
            handle      => $sth,
            bind_params => \@bind,
          );

  print $iter->index(); # 0

  while ( my $user = $iter->next() )
  {
      print $iter->index(); # 1, 2, 3, ...
      print $user->username();
  }

  $iter->reset();

=head1 DESCRIPTION

This class implements an iterator on top of a DBI statement
handle. Each call to C<next()> returns one or more objects based on
the data returned by the statement handle.

=head1 METHODS

This class provides the following methods:

=head2 Fey::Object::Iterator->new(...)

This method constructs a new iterator. It accepts the following
parameters:

=over 4

=item * classes

This can be a single class name, or an array reference of class
names. These should be classes associated with the tables from which
data is being C<SELECT>ed. The iterator will return an object of each
class in order when C<< $iterator->next() >> is called.

=item * handle

This should be a prepared, but not yet executed, C<DBI> statement
handle. Obviously, the statement handle should be for a C<SELECT>
statement.

=item * bind_params

This should be an array reference of one or more bind params to be
passed to C<< $sth->execute() >>.

=back

=head2 $iterator->index()

This returns the current index value of the iterator. When the object
is first constructed, this index is 0, and it is incremented once for
each row fetched by calling C<< $iteartor->next() >>.

=head2 $iterator->next()

This returns the next set of objects, based on data retrieved by the
query. In list context this returns all the objects. In scalar context
it returns the first object.

It is possible that one or more of the objects it returns will be
undefined, though this should really only happen with an outer
join. The statement handle will be executed the first time this method
is called.

If the statement handle is exhausted, this method returns false.

=head2 $iterator->all()

This returns all of the I<remaining> sets of objects. If the iterator
is for a single class, it returns a list of objects of that class. If
it is for multiple objects, it returns a list of array references.

=head2 $iterator->next_as_hash()

Returns the next set of objects as a hash. The keys are the names of
the object's associated table.

If the statement handle is exhausted, this method returns false.

=head2 $iterator->all_as_hashes()

This returns all of the I<remaining> sets of objects as a list of hash
references. Each hash ref is keyed on the table name of the associated
object's class.

=head2 $iterator->reset()

Resets the iterator so that the next call to C<< $iterator->next() >>
returns the first objects. Internally this means that the statement
handle will be executed again. It's possible that data will have
changed in the DBMS since then, meaning that the iterator will return
different objects after a reset.

=head2 $iterator->DEMOLISH()

This method will call C<< $sth->finish() >> on its C<DBI> statment
handle if necessary.

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
