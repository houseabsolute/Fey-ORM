package Fey::Meta::Attribute::WithColumn;

use strict;
use warnings;

use Moose;
use Moose::Util::TypeConstraints;

extends 'Moose::Meta::Attribute';


has 'column' =>
    ( is       => 'ro',
      isa      => 'Fey::Column',
      required => 1,
    );


package # hide from PAUSE
    Moose::Meta::Attribute::Custom::WithColumn;
sub register_implementation { 'Fey::Meta::Attribute::WithColumn' }


1;
