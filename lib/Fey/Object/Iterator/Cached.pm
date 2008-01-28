package Fey::Object::Iterator::Cached;

use strict;
use warnings;

use Moose;

extends 'Fey::Object::Iterator';



no Moose;
__PACKAGE__->meta()->make_immutable();

1;
