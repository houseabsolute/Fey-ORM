use strict;
use warnings;

use Test::More;

use lib 't/lib';

use Fey::ORM::Test;
use Fey::Literal::String;
use Fey::Test;


Fey::ORM::Test::define_live_classes();
Fey::ORM::Test::insert_user_data();

plan tests => 9;


{
    package Message;

    use Fey::ORM::Table;

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

{
    my $schema = Schema->Schema();

    $schema->remove_foreign_key($_)
        for $schema->foreign_keys_between_tables( 'Message', 'User' );

    $schema->remove_foreign_key($_)
        for $schema->foreign_keys_between_tables( 'Message', 'Message' );

    # These definitions invert the source/target labeling of the
    # corresponding FKs in Fey::Test. The goal is to test that has_one
    # figures out the proper "direction" of the FK.
    my $fk1 =
        Fey::FK->new
            ( source_columns => [ $schema->table('User')->column('user_id') ],
              target_columns => [ $schema->table('Message')->column('user_id') ],
            );

    my $fk2 =
        Fey::FK->new
            ( source_columns => [ $schema->table('Message')->column('message_id') ],
              target_columns => [ $schema->table('Message')->column('parent_message_id') ],
            );

    $schema->add_foreign_key($_) for $fk1, $fk2;

    package Message;

    __PACKAGE__->meta()->remove_attribute('user');

    has_one $schema->table('User');

    __PACKAGE__->meta()->remove_attribute('parent_message');

    has_one 'parent_message' =>
        ( table => $schema->table('Message') );
}

{

    my $parent =
        Message->insert( message => 'parent body',
                         user_id => 1,
                       );

    is( $parent->user()->user_id(), 1,
        'user() for parent message returns expected user object' );

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
