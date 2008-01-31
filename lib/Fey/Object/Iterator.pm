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
    for my $class ( keys %{ $map } )
    {
        my %attr = map { $_ => $row->{$_} } grep { exists $row->{$_ } } @{ $map->{$class} };
        $attr{_from_query} = 1;

        push @result, $class->new( \%attr );
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
