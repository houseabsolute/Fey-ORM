use strict;
use warnings;

use Test::More;

use lib 't/lib';

use Fey::Class::Test;
use Fey::Literal::String;
use Fey::Test;


Fey::Class::Test::insert_user_data();
Fey::Class::Test::define_live_classes();

plan tests => 21;


{
    is( User->Count(), 2, 'Count() finds two rows' );
}

{
    my $user1 = User->new( user_id => 1 );
    ok( $user1, 'was able to load user where user_id = 1' );

    is( $user1->username(), 'autarch',
        'username is set as side effect of calling _get_column_values()' );
    is( $user1->email(), 'autarch@example.com',
        'email is set as side effect of calling _get_column_values()' );

    my $user2 = User->new( user_id => 1 );
    isnt( $user1, $user2,
          'calling User->new() twice with the same user_id returns two different objects' );

    is( $user2->username(), 'autarch',
        'username is fetched as needed' );
    ok( $user2->has_email(),
        'email is set as side effect of calling username()' );
}

{
    my $new_called = 0;

    {
        no warnings 'redefine', 'once';
        local *User::new = sub { $new_called = 1 };

        User->insert( username => 'new',
                      email    => 'new@example.com' );
    }

    ok( ! $new_called, 'new() is not called when insert() is done in void context' );

    is( User->Count(), 3, 'Count() is now 3' );

    my $user = User->insert( username => 'new2',
                             email    => 'new@example.com' );

    is( $user->username(), 'new2',
        'object returned from insert() has username = new2' );
    cmp_ok( $user->user_id(), '>', 0,
            'object returned from insert() has a user id > 0 (fetched via last_insert_id())' );
    is( User->Count(), 4, 'Count() is now 4' );

    my $string = Fey::Literal::String->new( 'literal' );

    $user = User->insert( username => $string,
                          email    => 'new@example.com' );

    is( $user->username(), 'literal',
        'literals are handled correctly in an insert' );
}

{
    my @users = User->insert_many( { username => 'new3',
                                     email    => 'new3@example.com',
                                   },
                                   { username => 'new4',
                                     email    => 'new4@example.com',
                                   },
                                 );

    is( @users, 2, 'two new users were inserted' );
    is_deeply( [ map { $_->username() } @users ],
               [ qw( new3 new4 ) ],
               'users were returned with expected data in the order they were provided'
             );
}

{
    my $user = User->new( user_id => 1 );
    $user->update( username => 'updated',
                   email    => 'updated@example.com' );

    ok( $user->has_email(), 'email is not cleared when update value is a non-reference' );
    is( $user->username(), 'updated', 'username = updated' );
    is( $user->email(), 'updated@example.com', 'email = updated@example.com' );

    my $string = Fey::Literal::String->new( 'updated2' );
    $user->update( username => $string );

    ok( ! $user->has_username(), 'username is cleared when update value is a reference' );
    is( $user->username(), 'updated2', 'username = updated2' );
}


{
    package Email;

    sub new
    {
        return bless \$_[1], $_[0];
    }

    package User;

    use Fey::Class::Table;

    transform 'email'
        => inflate { return Email->new( $_[1] ) }
        => deflate { return $_[1]->as_string() };
}

{
    my $user = User->new( user_id => 1 );

    isa_ok( $user->email(), 'Email' );
}
