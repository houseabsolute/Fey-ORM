use strict;
use warnings;

use Test::More tests => 17;

use lib 't/lib';

use Fey::Class::Test qw( schema );

my $Schema = schema();


{
    package User;

    use Fey::Class;

    has_table $Schema->table('User');

    transform 'email'
        => inflate { return Email::Address->new( $_[1] ) }
        => deflate { return $_[1]->as_string() };
}

{
    ok( User->isa('Fey::Object'),
        q{User->isa('Fey::Object')} );
    can_ok( 'User', 'Table' );
    is( User->Table()->name(), 'User',
        'User->Table() returns User table' );

    for my $column ( $Schema->table('User')->columns() )
    {
        can_ok( 'User', $column->name() );
    }

    can_ok( 'User', 'email_raw' );

    can_ok( 'User', '_email' );

    is ( User->meta()->get_attribute('user_id')->type_constraint()->name(),
         'Int',
         'type for user_id is Int' );

    is ( User->meta()->get_attribute('username')->type_constraint()->name(),
         'Str',
         'type for username is Str' );

    is ( User->meta()->get_attribute('email')->type_constraint()->name(),
         'Str | Undef',
         'type for email is Str | Undef' );

    ok( User->_HasDeflator('email'), 'User has a deflator coderef for email' );
}

{
    package Message;

    use Fey::Class;

    has_table $Schema->table('Message');

    has_one $Schema->table('User');

    # Testing passing >1 attribute to transform
    transform qw( message quality )
        => inflate { $_[0] }
        => deflate { $_[0] };

    eval
    {
        transform 'message'
            => inflate { $_[0] }
    };

    ::like( $@, qr/more than one inflator/,
            'cannot provide more than one inflator for a column' );

    eval
    {
        transform 'message'
            => deflate { $_[0] }
    };

    ::like( $@, qr/more than one deflator/,
            'cannot provide more than one deflator for a column' );
}

{
    can_ok( 'Message', 'user' );

    ok( Message->_HasDeflator('message'), 'Message has a deflator coderef for message' );
    ok( Message->_HasDeflator('quality'), 'Message has a deflator coderef for quality' );
}
