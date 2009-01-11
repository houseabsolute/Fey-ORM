package Fey::Meta::Attribute::FromColumn;

use strict;
use warnings;

use Moose;

extends 'Moose::Meta::Attribute';


has 'column' =>
    ( is       => 'ro',
      isa      => 'Fey::Column',
      required => 1,
    );

no Moose;

# The parent class's constructor is not a Moose::Object-based
# constructor, so we don't want to inline one that is.
__PACKAGE__->meta()->make_immutable( inline_constructor => 0 );

1;
