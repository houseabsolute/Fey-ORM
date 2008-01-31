use strict;
use warnings;

use Test::More;

use Fey::Object::Iterator::Cached;

use lib 't/lib';

use Fey::Class::Test;
use Fey::Test;


Fey::Class::Test::insert_user_data();
Fey::Class::Test::define_basic_classes();

Test::More::plan tests => 22;

my $dbh = Fey::Test::SQLite->dbh();

{
    my $sth = $dbh->prepare( 'SELECT user_id, username, email FROM User ORDER BY user_id' );

    my $iterator = Fey::Object::Iterator::Cached->new( classes => 'User',
                                                       handle  => $sth,
                                                     );

    is( $iterator->index(), 0,
        'index() is 0 before any data has been fetched' );

    my $user = $iterator->next();
    isa_ok( $user, 'User' );

    is( $iterator->index(), 1,
        'index() is 1 after first row has been fetched' );

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

    $iterator->reset();

    $user = $iterator->next();

    is( $iterator->index(), 1,
        'index() is 1 after reset and first row has been fetched' );

    is( $user->user_id(), 1,
        'user_id = 1' );
    is( $user->username(), 'autarch',
        'username = autarch' );
    is( $user->email(), 'autarch@example.com',
        'email = autarch@example.com' );
}
