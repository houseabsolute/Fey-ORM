use strict;
use warnings;

use Test::More;

BEGIN
{
    if ( eval "use Fey::Test::SQLite; 1" )
    {
        plan tests => 20;
    }
    else
    {
        plan skip_all => 'These tests require Fey::Test::SQLite';
    }
}

use Fey::Object::Iterator;

use lib 't/lib';


use Fey::Class::Test qw( schema );
use Fey::Test;

my $Schema = schema();


{
    package User;

    use Fey::Class;

    has_table $Schema->table('User');

    package Message;

    use Fey::Class;

    has_table $Schema->table('Message');
}

{
    eval { Fey::Object::Iterator->new( classes => [] ) };
    like( $@, qr/\QAttribute (classes) does not pass the type constraint/,
          'cannot pass empty array for classes attribute' );

    eval { Fey::Object::Iterator->new( classes => [ 'DoesNotExist' ] ) };
    like( $@, qr/\QAttribute (classes) does not pass the type constraint/,
          'cannot pass strings for classes attribute, must be a Fey::Object subclass' );
}

my $dbh = Fey::Test::SQLite->dbh();

{
    my $insert = 'INSERT INTO User ( user_id, username, email ) VALUES ( ?, ?, ? )';
    my $sth = $dbh->prepare($insert);

    $sth->execute( 1,  'autarch', 'autarch@example.com' );
    $sth->execute( 42, 'bubba',   'bubba@example.com' );
}

{
    my $sth = $dbh->prepare( 'SELECT user_id, username, email FROM User ORDER BY user_id' );
    $sth->execute();

    my $iterator = Fey::Object::Iterator->new( classes => 'User',
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

{
    my $sth = $dbh->prepare( 'SELECT user_id, username, email FROM User ORDER BY user_id' );
    $sth->execute();

    my $iterator = Fey::Object::Iterator->new( classes => 'User',
                                               handle  => $sth,
                                             );

    my %user = $iterator->next_as_hash();

    is( ( scalar keys %user ), 1,
        'next_as_hash() returns hash with one key' );
    is( $user{User}->user_id(), 1,
        'found expected user via next_as_hash()' );
}

