use strict;
use warnings;

use Test::Exception;
use Test::More;

use Fey::Object::Iterator::FromArray;
use Fey::SQL;

use lib 't/lib';

use Fey::ORM::Test::Iterator;
use Fey::Test;


plan tests => 37;

Fey::ORM::Test::Iterator::run_shared_tests('Fey::Object::Iterator::FromArray');
