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

1;
