package Fey::Meta::Attribute::Inflated;

use strict;
use warnings;

use Moose;

extends 'Moose::Meta::Attribute';


has 'inflator' =>
    ( is       => 'ro',
      isa      => 'CodeRef',
      required => 1,
    );

has 'raw_attribute' =>
    ( is       => 'ro',
      isa      => 'Fey::Meta::Attribute::FromColumn',
      required => 1,
    );

sub column
{
    return $_[0]->raw_attribute()->column();
}

no Moose;

# The parent class's constructor is not a Moose::Object-based
# constructor, so we don't want to inline one that is.
__PACKAGE__->meta()->make_immutable( inline_constructor => 0 );

1;
