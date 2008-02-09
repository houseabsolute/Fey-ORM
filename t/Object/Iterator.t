use strict;
use warnings;

use Test::More;

use Fey::Object::Iterator;

use lib 't/lib';

use Fey::ORM::Test::Iterator;
use Fey::Test;


Test::More::plan tests => 35;

{
    eval { Fey::Object::Iterator->new( classes => [] ) };
    like( $@, qr/\QAttribute (classes) does not pass the type constraint/,
          'cannot pass empty array for classes attribute' );

    eval { Fey::Object::Iterator->new( classes => [ 'DoesNotExist' ] ) };
    like( $@, qr/\QAttribute (classes) does not pass the type constraint/,
          'cannot pass strings for classes attribute, must be a Fey::Object subclass' );
}


Fey::ORM::Test::Iterator::run_shared_tests('Fey::Object::Iterator');
