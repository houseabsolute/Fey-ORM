use strict;
use warnings;

use Test::More tests => 15;

use Fey::Test;


my $schema = Fey::Test->mock_test_schema_with_fks();

{
    package User;

    use Fey::Class;

    has_table $schema->table('User');

    transform 'email'
        => inflate { return Email::Address->new( $_[1] ) }
        => deflate { return $_[1]->as_string() };
}

{
    ok( User->isa('Fey::Class::Object'),
        q{User->isa('Fey::Class::Object')} );
    can_ok( 'User', 'Table' );
    is( User->Table()->name(), 'User',
        'User->Table() returns User table' );

    for my $column ( $schema->table('User')->columns() )
    {
        can_ok( 'User', $column->name() );
    }

    can_ok( 'User', 'email_raw' );

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

    has_table $schema->table('Message');

    # Just testing passing >1 attribute to transofmr
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
    ok( Message->_HasDeflator('message'), 'Message has a deflator coderef for message' );
    ok( Message->_HasDeflator('quality'), 'Message has a deflator coderef for quality' );
}
