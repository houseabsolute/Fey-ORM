use strict;
use warnings;

use Test::More;

use lib 't/lib';

use Fey::ORM::Test;
use Fey::Literal::String;
use Fey::Test;


Fey::ORM::Test::define_live_classes();
Fey::ORM::Test::insert_user_data();

plan tests => 7;


{
    package User;

    use Fey::ORM::Table;

    has_many messages => ( table => Schema->Schema()->table('Message') );

    package Message;

    use Fey::ORM::Table;

    has_many 'child_messages' =>
        ( table => Schema->Schema()->table('Message') );
}

{
    my $parent =
        Message->insert( message_id => 1,
                         message    => 'parent body',
                         user_id    => 1,
                       );

    for my $i ( 1 .. 3 )
    {
        Message->insert( message_id        => $i * 3,
                         message           => 'child body',
                         parent_message_id => $parent->message_id(),
                         user_id           => 1,
                       );
    }

    my $user = User->new( user_id => 1 );

    my $messages = $user->messages();

    is_deeply( [ sort map { $_->message_id() } $messages->all() ],
               [ 1, 3, 6, 9 ],
               'messages() method returns iterator with expected message data' );

    $messages = $parent->child_messages();

    is_deeply( [ sort map { $_->message_id() } $messages->all() ],
               [ 3, 6, 9 ],
               'child_messages() method returns iterator with expected message data' );
}

{
    package User;

    __PACKAGE__->meta()->remove_method('message' );

    has_many messages =>
        ( table    => Schema->Schema()->table('Message'),
          order_by => [ Schema->Schema()->table('Message')->column('message_id'), 'DESC' ],
        );
}

{
    my $user = User->new( user_id => 1 );

    my $messages = $user->messages();

    is_deeply( [ map { $_->message_id() } $messages->all() ],
               [ 9, 6, 3, 1 ],
               'messages() method returns iterator with expected message data, respecting order_by' );
}

{
    package User;

    __PACKAGE__->meta()->remove_method('message' );

    has_many messages =>
        ( table => Schema->Schema()->table('Message'),
          cache => 1,
        );
}

{
    my $user = User->new( user_id => 1 );

    isa_ok( $user->messages(), 'Fey::Object::Iterator::Caching' );
}

{
    my $schema = Schema->Schema();

    $schema->remove_foreign_key($_)
        for $schema->foreign_keys_between_tables( 'Message', 'User' );

    $schema->remove_foreign_key($_)
        for $schema->foreign_keys_between_tables( 'Message', 'Message' );

    # These definitions invert the source/target labeling of the
    # corresponding FKs in Fey::Test. The goal is to test that
    # has_many figures out the proper "direction" of the FK.
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

    package User;

    __PACKAGE__->meta()->remove_method('messages');

    has_many messages => ( table => Schema->Schema()->table('Message') );

    package Message;

    __PACKAGE__->meta()->remove_attribute('child_messages');

    has_many 'child_messages' =>
        ( table => Schema->Schema()->table('Message') );

}

{
    my $user = User->new( user_id => 1 );

    my $messages = $user->messages();

    is_deeply( [ sort map { $_->message_id() } $messages->all() ],
               [ 1, 3, 6, 9 ],
               'messages() method returns iterator with expected message data' );

    my $parent = Message->new( message_id => 1 );

    $messages = $parent->child_messages();

    is_deeply( [ sort map { $_->message_id() } $messages->all() ],
               [ 3, 6, 9 ],
               'messages() method returns iterator with expected message data' );
}

{
    my $user = User->new( user_id => 1 );

    my $messages = $user->messages();

    $messages->next();
    $messages->next();

    $messages = $user->messages();

    is_deeply( [ sort map { $_->message_id() } $messages->all() ],
               [ 1, 3, 6, 9 ],
               'messages() method resets iterator with each call' );
}
