use strict;
use warnings;

use Test::More;

use Fey::Object::Iterator::Caching;

use lib 't/lib';

use Fey::ORM::Test::Iterator;
use Fey::Test;


Test::More::plan tests => 43;


Fey::ORM::Test::Iterator::run_shared_tests('Fey::Object::Iterator::Caching');

my $dbh = Fey::Test::SQLite->dbh();

{
    my $sth = $dbh->prepare( 'SELECT user_id, username, email FROM User ORDER BY user_id' );

    my $iterator = Fey::Object::Iterator::Caching->new( classes => 'User',
                                                        handle  => $sth,
                                                      );

    # Just empty the iterator
    while ( $iterator->next() ) { }

    # This means we can only get results from the cache.
    no warnings 'redefine';
    local *Fey::Object::Iterator::_get_next_result = sub {};

    $iterator->reset();

    my $user = $iterator->next();

    is( $iterator->index(), 1,
        'index() is 1 after reset and first row has been fetched' );

    is( $user->user_id(), 1,
        'user_id = 1' );
    is( $user->username(), 'autarch',
        'username = autarch' );
    is( $user->email(), 'autarch@example.com',
        'email = autarch@example.com' );

    $user = $iterator->next();

    is( $iterator->index(), 2,
        'index() is 2 after second row has been fetched' );

    is( $user->user_id(), 42,
        'user_id = 42' );
    is( $user->username(), 'bubba',
        'username = bubba' );
    is( $user->email(), 'bubba@example.com',
        'email = bubba@example.com' );

    $user = $iterator->next();

    is( $iterator->index(), 2,
        'index() is 2 after attempt to fetch another row' );
    is( $user, undef,
        '$user is undef when there are no more objects to fetch' );
}
