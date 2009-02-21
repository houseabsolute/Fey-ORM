package Fey::ORM::Role::Iterator;

use strict;
use warnings;

use Moose::Role;
use MooseX::AttributeHelpers;

requires qw( all remaining next
             all_as_hashes remaining_as_hashes next_as_hash
             reset );

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

no Moose::Role;

1;
