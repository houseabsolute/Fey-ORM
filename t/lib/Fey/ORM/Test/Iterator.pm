package Fey::ORM::Test::Iterator;

use strict;
use warnings;

use Fey::SQL;

use Fey::ORM::Test;
use Test::Exception;
use Test::More;

Fey::ORM::Test::require_sqlite();


sub run_shared_tests
{
    my $class = shift;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    Fey::ORM::Test::insert_user_data();
    Fey::ORM::Test::insert_message_data();
    Fey::ORM::Test::define_basic_classes();

    my $schema = Fey::ORM::Test->schema();
    my $dbh = Fey::Test::SQLite->dbh();

    {
        my $sql = Fey::SQL->new_select
                          ->select( $schema->table('User')->columns( qw( user_id username email ) ) )
                          ->from( $schema->table('User') )
                          ->order_by( $schema->table('User')->column('user_id') );

        my $iterator = $class->new( classes => 'User',
                                    dbh     => $dbh,
                                    select  => $sql,
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
        my $sql = Fey::SQL->new_select
                          ->select( $schema->table('User')->columns( qw( user_id username email ) ) )
                          ->from( $schema->table('User') )
                          ->order_by( $schema->table('User')->column('user_id') );

        my $iterator = $class->new( classes => 'User',
                                    dbh     => $dbh,
                                    select  => $sql,
                                  );

        my @users = $iterator->all();

        is_deeply( [ sort map { $_->user_id() } @users ],
                   [ 1, 42 ],
                   'all() returns expected result' );

        $iterator->reset();

        my %user = $iterator->next_as_hash();

        is( ( scalar keys %user ), 1,
            'next_as_hash() returns hash with one key' );
        is( $user{User}->user_id(), 1,
            'found expected user via next_as_hash()' );

        $iterator->reset();

        my @results = $iterator->all_as_hashes();

        is_deeply( [ map { [ keys %{ $_ } ] } @results ],
                   [ [ 'User' ], [ 'User' ] ],
                   'all_as_hashes returns arrayref of hashes with expected keys' );

        is( $results[0]{User}->user_id(), 1,
            'found expected first user in result' );
        is( $results[1]{User}->user_id(), 42,
            'found expected second user in result' );
    }

    {
        my $sql = Fey::SQL->new_select
                          ->select( $schema->table('User')->columns( qw( user_id username email ) ) )
                          ->from( $schema->table('User') )
                          ->where( $schema->table('User')->column('user_id'), 'IN', 1, 42 )
                          ->order_by( $schema->table('User')->column('user_id') );

        my $iterator = $class->new( classes => 'User',
                                    dbh     => $dbh,
                                    select  => $sql,
                                  );

        my $user = $iterator->next();

        is( $user->user_id(), 1,
            'first user_id with bind params in sql object' );

        $user = $iterator->next();

        is( $user->user_id(), 42,
            'second user_id with bind params in sql object' );
    }

    {
        my $sql = Fey::SQL->new_select
                          ->select( $schema->table('User')->columns( qw( user_id username email ) ) )
                          ->from( $schema->table('User') )
                          ->where( $schema->table('User')->column('user_id'), 'IN',
                                   ( Fey::Placeholder->new() ) x 2 )
                          ->order_by( $schema->table('User')->column('user_id') );

        my $iterator = $class->new( classes     => 'User',
                                    dbh         => $dbh,
                                    select      => $sql,
                                    bind_params => [ 1, 42 ],
                                  );

        my $user = $iterator->next();

        is( $user->user_id(), 1,
            'first user_id with explicit bind params' );

        $user = $iterator->next();

        is( $user->user_id(), 42,
            'second user_id with explicit bind params' );
    }

    {
        my $sql = Fey::SQL->new_select
                          ->select( $schema->table('User')->columns( qw( user_id username ) ),
                                    $schema->table('Message')->columns( qw( message_id message ) ),
                                  )
                          ->from( $schema->tables( 'User', 'Message' ) )
                          ->order_by( $schema->table('User')->column('user_id'),
                                      $schema->table('Message')->column('message_id'),
                                    );

        my $iterator = $class->new( classes => [ 'User', 'Message' ],
                                    dbh     => $dbh,
                                    select  => $sql,
                                  );

        my ( $user, $message ) = $iterator->next();

        is( $user->user_id(), 1, 'first user id is 1' );
        is( $message->message_id(), 1, 'first message id is 1' );

        $user = $iterator->next();
        # testing next() in scalar context
        isa_ok( $user, 'User' );

        $iterator->reset();

        is_deeply( [ map { [ $_->[0]->user_id(), $_->[1]->message_id() ] } $iterator->all() ],
                   [ [ 1,   1 ],
                     [ 1,   2 ],
                     [ 42, 10 ],
                     [ 42, 99 ],
                   ],
                   'all() returns expected set of objects' );

        $iterator->reset();

        my %result = $iterator->next_as_hash();

        is( $result{User}->user_id(), 1, 'first user id is 1' );
        is( $result{Message}->message_id(), 1, 'first message id is 1' );

        $iterator->reset();

        is_deeply( [ map { [ $_->{User}->user_id(), $_->{Message}->message_id() ] } $iterator->all_as_hashes() ],
                   [ [ 1,   1 ],
                     [ 1,   2 ],
                     [ 42, 10 ],
                     [ 42, 99 ],
                   ],
                   'all_as_hashes() returns expected set of objects' );
    }

    {
        # This simulates an OUTER JOIN where Message could be NULL
        my $sql = Fey::SQL->new_select
                          ->select( Fey::Literal::Null->new(),
                                    $schema->table('User')->columns( qw( user_id username ) ),
                                  )
                          ->from( $schema->tables( 'User' ) )
                          ->order_by( $schema->table('User')->column('user_id') );

        my $iterator = $class->new( classes       => [ 'Message', 'User' ],
                                    dbh           => $dbh,
                                    select        => $sql,
                                    attribute_map =>
                                        { 0 => { class     => 'Message',
                                                 attribute => 'message_id',
                                               },
                                        },
                                  );

        my ( $message, $user ) = $iterator->next();

        is( $message, undef, 'message object is undefined' );
        ok( $user, 'user object is defined' );
    }
}

1;
