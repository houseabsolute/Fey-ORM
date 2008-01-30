use strict;
use warnings;

use Test::More;

use lib 't/lib';

use Fey::Class::Test;
use Fey::Literal::String;
use Fey::Test;


Fey::Class::Test::define_live_classes();
Fey::Class::Test::insert_user_data();

plan tests => 1;


{
    package Message;

    use Fey::Class::Table;

    has_one Schema->Schema()->table('User');

    has_one 'parent_message' =>
        ( table => Schema->Schema()->table('Message') );
}

{
    my $parent =
        Message->insert( message => 'parent body',
                         user_id => 1,
                       );

    is( $parent->user()->user_id(), 1,
        'user() for parent message returns expected user object' );

    is( $parent->user(), $parent->user(),
        'user() attribute is cached' );

    is( $parent->parent_message(), undef,
        'parent message has no parent itself' );

    my $child =
        Message->insert( message           => 'child body',
                         parent_message_id => $parent->message_id(),
                         user_id           => 1,
                       );

    my $parent_from_attr = $child->parent_message();

    is( $parent_from_attr->message_id(), $parent->message_id(),
        'parent_message() attribute created via has_one returns expected message' );
}

{
    package Message;

    __PACKAGE__->meta()->remove_attribute('user');

    has_one 'user' =>
        ( table => Schema->Schema()->table('User'),
          cache => 0,
        );
}

{
    my $message =
        Message->insert( message => 'message body',
                         user_id => 1,
                       );

    is( $message->user()->user_id(), 1,
        'user() for parent message returns expected user object' );

    isnt( $message->user(), $message->user(),
          'user() attribute is not cached' );
}
