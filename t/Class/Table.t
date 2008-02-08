use strict;
use warnings;

use Test::More tests => 28;

use lib 't/lib';

use Fey::ORM::Test qw( schema );

my $Schema = schema();


{
    package Group;

    use Fey::ORM::Table;

    eval { has_table $Schema->table('Group') };

    ::like( $@, qr/must load your schema class/,
            'cannot call has_table() before schema class is loaded' );
}

{
    package Schema;

    use Fey::ORM::Schema;

    has_schema $Schema;


    package Email;

    sub new
    {
        return bless \$_[1], $_[0];
    }

    sub as_string
    {
        return ${ $_[0] };
    }


    package User;

    use Fey::ORM::Table;

    has_table $Schema->table('User');

    transform 'email'
        => inflate { return Email->new( $_[1] ) }
        => deflate { return $_[1]->as_string() };


    eval { has_table $Schema->table('User') };
    ::like( $@, qr/more than once per class/,
            'cannot call has_table() more than once for a class' );

    package User2;

    use Fey::ORM::Table;

    eval { has_table $Schema->table('User') };
    ::like( $@, qr/associate the same table with multiple classes/,
            'cannot associate the same table with multiple classes' );

    my $table = Fey::Table->new( name => 'User2' );

    eval { has_table $table };
    ::like( $@, qr/must have a schema/,
            'tables passed to has_table() must have a schema' );

    $Schema->add_table($table);

    eval { has_table $table };
    ::like( $@, qr/must have at least one key/,
            'tables passed to has_table() must have at least one key' );
}

{
    package Group;

    use Fey::ORM::Table;

    has_table $Schema->table('Group');
}

{
    ok( User->isa('Fey::Object'),
        q{User->isa('Fey::Object')} );
    can_ok( 'User', 'Table' );
    is( User->Table()->name(), 'User',
        'User->Table() returns User table' );

    is( Fey::Meta::Class::Table->TableForClass('User')->name(), 'User',
        q{Fey::Meta::Class::Table->TableForClass('User') returns User table} );

    is( Fey::Meta::Class::Table->ClassForTable( $Schema->table('User') ), 'User',
        q{Fey::Meta::Class::Table->ClassForTable('User') returns User class} );

    is_deeply( [ Fey::Meta::Class::Table->ClassForTable( $Schema->tables( 'User', 'Group' ) ) ],
               [ 'User', 'Group' ],
               q{Fey::Meta::Class::Table->ClassForTable( 'User', 'Group' ) returns expected classes} );

    for my $column ( $Schema->table('User')->columns() )
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

    ok( User->HasInflator('email'), 'User has an inflator coderef for email' );
    ok( User->HasDeflator('email'), 'User has a deflator coderef for email' );

    my $user = User->new( user_id     => 1,
                          email       => 'test@example.com',
                          _from_query => 1,
                        );

    ok( ! ref $user->email_raw(),
        'email_raw() returns a plain string' );
    is( $user->email_raw(), 'test@example.com',
        'email_raw = test@example.com' );

    my $email = $user->email();
    isa_ok( $email, 'Email' );
    is( $email, $user->email(), 'inflated values are cached' );
}

{
    package Message;

    use Fey::ORM::Table;

    has_table $Schema->table('Message');

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
    ok( Message->HasDeflator('message'), 'Message has a deflator coderef for message' );
    ok( Message->HasDeflator('quality'), 'Message has a deflator coderef for quality' );
}
