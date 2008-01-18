package Fey::Object::Iterator;

use strict;
use warnings;

use Fey::Exceptions qw( param_error );
use List::MoreUtils qw( pairwise );

use Moose::Policy 'MooseX::Policy::SemiAffordanceAccessor';
use Moose;
use Moose::Util::TypeConstraints;

subtype 'ArrayRefOfClasses'
    => as 'ArrayRef',
    => where { return unless @{$_};
               return if grep { ! $_->isa('Fey::Object') } @{ $_ };
               return 1;
             };

coerce 'ArrayRefOfClasses'
    => from 'Str'
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

has index =>
    ( is       => 'rw',
      isa      => 'Int',
      writer   => '_set_index',
      default  => 0,
      init_arg => "\0index",
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

    my $sth = $self->_executed_handle();

    return unless $sth->fetch();

    $self->_set_index( $self->index() + 1 );

    my $map = $self->_attribute_map();

    my $row = $self->_row();

    my @return;
    for my $class ( keys %{ $map } )
    {
        my %attr = map { $_ => $row->{$_} } grep { exists $row->{$_ } } @{ $map->{$class} };
        $attr{_from_query} = 1;

        push @return, $class->new( \%attr );
    }

    return wantarray ? @return : $return[0];
}

sub _executed_handle
{
    my $self = shift;

    my $sth = $self->handle();

    return $sth if $self->_executed();

    my $row = $self->_row();

    $sth->bind_columns( \( @{ $row }{ @{ $sth->{NAME_lc} } } ) );

    $sth->execute();

    $self->_set_executed(1);

    return $sth;
}

sub _make_attribute_map
{
    my $self = shift;

    return { map { $_ => [ map { lc } $_->meta()->get_attribute_list() ] }
             @{ $self->classes() }
           };
}

sub next_as_hash
{
    my $self = shift;

    my @objects = $self->next();

    return
        pairwise { $a->Table()->name() => $b }
        @{ $self->classes() }, @objects;
}

sub reset
{
    my $self = shift;

    $self->_set_executed(0);
    $self->_set_index(0);

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


1;
