package Fey::Object::Iterator::Cached;

use strict;
use warnings;

use MooseX::AttributeHelpers;
use MooseX::StrictConstructor;

extends 'Fey::Object::Iterator';

has _cached_results =>
    ( metaclass => 'Collection::Array',
      is        => 'ro',
      isa       => 'ArrayRef[ArrayRef]',
      lazy      => 1,
      default   => sub { [] },
      provides  => { push => '_cache_result',
                     get  => '_get_cached_result',
                   },
    );


sub next
{
    my $self = shift;

    my $result = $self->_get_cached_result( $self->index() );

    unless ($result)
    {
        $result = $self->_get_next_result();

        return unless $result;

        $self->_cache_result($result);
    }

    $self->_inc_index() if $result;

    return wantarray ? @{ $result } : $result->[0];
}

sub reset
{
    my $self = shift;

    $self->_reset_index();
}


no Moose;
__PACKAGE__->meta()->make_immutable();

1;
