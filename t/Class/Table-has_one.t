use strict;
use warnings;

use Test::More tests => 12;

use lib 't/lib';

use Fey::Class::Test qw( schema );

my $Schema = schema();


{
    package Schema;

    use Fey::Class::Schema;

    has_schema $Schema;
}

{
    package Message;

    use Fey::Class::Table;

    has_table $Schema->table('Message');

    has_one $Schema->table('User');
}

{
    can_ok( 'Message', 'user' );

    my $attr = Message->meta()->get_attribute('user');
    ok( $attr, 'found attribute for user' );
    is( ref $attr->default(), 'CODE',
        'user attribute default is a coderef' );
    is( $attr->type_constraint()->name(), 'Fey::Object',
        'user attribute type constraint is Fey::Object' );
}

{
    package Message;

    __PACKAGE__->meta()->remove_attribute('user');

    has_one 'my_user' =>
        ( table => $Schema->table('User'),
          cache => 1,
        );
}

{
    can_ok( 'Message', 'my_user' );

    my $attr = Message->meta()->get_attribute('my_user');
    ok( $attr, 'found attribute for my_user' );
    is( ref $attr->default(), 'CODE',
        'my_user attribute default is a coderef' );
    is( $attr->type_constraint()->name(), 'Fey::Object',
        'my_user attribute type constraint is Fey::Object' );
}

{
    package Message;

    __PACKAGE__->meta()->remove_attribute('user');

    has_one 'user' =>
        ( table => $Schema->table('User'),
          cache => 0,
        );
}

{
    can_ok( 'Message', 'user' );

    ok( ! Message->meta()->has_attribute('user'),
        'Message does not have an attribute for user (but does have a user() method)' );
}


{
    package Message;

    eval { has_one $Schema->table('Group') };

    ::like( $@, qr/\QThere are no foreign keys between the table for this class, Message and the table you passed to has_one(), Group/,
            'Cannot declare a has_one relationship to a table with which we have no FK' );

    eval { has_one $Schema->table('Message') };

    ::is( $@, '',
          'no exception declaring a self-referential has_one' );
}
