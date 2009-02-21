package Fey::ORM::Role::Iterator;

use strict;
use warnings;

use List::MoreUtils qw( pairwise );
use Moose::Role;
use MooseX::AttributeHelpers;
use Moose::Util::TypeConstraints;

requires qw( _get_next_result reset );

my $arrayref_of_classes =
    subtype
          as 'ArrayRef[ClassName]',
       => where { return 0 unless @{ $_ };
                  return List::MoreUtils::all { $_->isa('Fey::Object::Table') } @{ $_ };
                }
       => message { my @contents = eval { @{$_} } ? @{$_} : $_;
                    "Must be an array reference of Fey::Object::Table subclasses and you passed [@contents]";
                  };

coerce $arrayref_of_classes
    => from 'ClassName'
    => via { return [ $_ ] };

has classes =>
    ( is     => 'ro',
      isa    => $arrayref_of_classes,
      coerce => 1,
    );

has index =>
    ( metaclass => 'Counter',
      is       => 'ro',
      isa      => 'Int',
      default  => 0,
      init_arg => undef,
      provides => { 'inc'   => '_inc_index',
                    'reset' => '_reset_index',
                  },
    );


sub all
{
    my $self = shift;

    $self->reset() if $self->index();

    return $self->remaining();
}

sub remaining
{
    my $self = shift;

    my @result;
    while ( my @r = $self->next() )
    {
        push @result, @r == 1 ? @r : \@r;
    }

    return @result;
}

sub next
{
    my $self = shift;

    my $result = $self->_get_next_result();

    return unless $result;

    $self->_inc_index();

    return wantarray ? @{ $result } : $result->[0];
}

sub all_as_hashes
{
    my $self = shift;

    $self->reset() if $self->index();

    return $self->remaining_as_hashes();
}

sub remaining_as_hashes
{
    my $self = shift;

    my @result;
    while ( my %r = $self->next_as_hash() )
    {
        push @result, \%r;
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

no Moose::Role;
no Moose::Util::TypeConstraints;

1;
