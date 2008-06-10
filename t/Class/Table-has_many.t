use strict;
use warnings;

use Test::More tests => 21;

use lib 't/lib';

use Fey::ORM::Test qw( schema );
use Fey::Placeholder;
use List::Util qw( first );


my $Schema = schema();


{
    package Schema;

    use Fey::ORM::Schema;

    has_schema $Schema;
}

{
    package User;

    use Fey::ORM::Table;

    has_table $Schema->table('User');

    has_many 'messages' =>
        ( table => $Schema->table('Message') );
}

{
    can_ok( 'User', 'messages' );
    ok( ! User->can('_clear_messages'), 'no clearer for non-cached has_many' );

    ok( ! User->meta()->has_attribute('messages'),
        'without caching messages is not an attribute of the User class' );
}

{
    package User;

    __PACKAGE__->meta()->remove_method('messages');

    has_many 'messages' =>
        ( table => $Schema->table('Message'),
          cache => 1,
        );
}

{
    can_ok( 'User', 'messages' );
    can_ok( 'User', '_clear_messages' );

    my $attr = User->meta()->get_attribute('_messages');
    ok( $attr, 'found attribute for _messages' );
    is( ref $attr->default(), 'CODE',
        '_messages attribute default is a coderef' );
    is( $attr->type_constraint()->name(), 'Fey::Object::Iterator::Caching',
        '_messages attribute type constraint is Fey::Object::Iterator::Caching' );

    ok( User->meta()->get_method('messages'),
        'found method for messages' );
}

{
    package Message;

    use Fey::ORM::Table;

    has_table $Schema->table('Message');

    eval { has_many( $Schema->table('Group') ) };

    ::like( $@, qr/\QThere are no foreign keys between the table for this class, Message and the table you passed to has_many(), Group/,
            'Cannot declare a has_many relationship to a table with which we have no FK' );

    eval { has_many( $Schema->table('Message') ) };

    ::is( $@, '',
          'no exception declaring a self-referential has_many' );

    my $table = Fey::Table->new( name => 'NewTable' );
    eval { has_many $table };

    ::like( $@, qr/\QA table object passed to has_many() must have a schema/,
            'table without a schema passed to has_many()' );
}

{
    package Message;

    my $select =
        Schema->SQLFactoryClass()->new_select()
              ->select( $Schema->table('User') )
              ->from( $Schema->table('User'), $Schema->table('Message') )
              ->where( $Schema->table('Message')->column('parent_message_id'),
                       '=', Fey::Placeholder->new() );

    has_many 'child_message_users' =>
        ( table       => $Schema->table('User'),
          select      => $select,
          bind_params => sub { $_[0]->message_id() },
        );
}

{
    can_ok( 'Message', 'child_message_users' );

    ok( ! Message->meta()->has_attribute('child_message_users'),
        'without caching child_message_users is not an attribute of the Message class' );
}

{
    package Message;

    __PACKAGE__->meta()->remove_method('child_message_users');

    my $select =
        Schema->SQLFactoryClass()->new_select()
              ->select( $Schema->table('User') )
              ->from( $Schema->table('User'), $Schema->table('Message') )
              ->where( $Schema->table('Message')->column('parent_message_id'),
                       '=', Fey::Placeholder->new() );

    has_many 'child_message_users' =>
        ( table       => $Schema->table('User'),
          select      => $select,
          bind_params => sub { $_[0]->message_id() },
          cache       => 1,
        );
}

{
    can_ok( 'Message', 'child_message_users' );

    my $attr = Message->meta()->get_attribute('_child_message_users');
    ok( $attr, 'found attribute for _child_message_users' );
    is( ref $attr->default(), 'CODE',
        '_child_message_users attribute default is a coderef' );
    is( $attr->type_constraint()->name(), 'Fey::Object::Iterator::Caching',
        '_child_message_users attribute type constraint is Fey::Object::Iterator::Caching' );

    ok( Message->meta()->get_method('child_message_users'),
        'found method for child_message_users' );
}

{
    my $editor_user_id =
        Fey::Column->new( name => 'editor_user_id',
                          type => 'integer',
                        );

    $Schema->table('Message')->add_column($editor_user_id);

    my $fk =
        Fey::FK->new
          ( source_columns => [ $Schema->table('Message')->column('editor_user_id') ],
            target_columns => [ $Schema->table('User')->column('user_id') ],
          );

    $Schema->add_foreign_key($fk);
}

{
    package User;

    __PACKAGE__->meta()->remove_attribute('messages');

    eval { has_many 'edited_messages' => ( table => $Schema->table('Message') ) };

    ::like( $@, qr/\QThere is more than one foreign key between the table for this class, User and the table you passed to has_many(), Message. You must specify one explicitly/i,
            'exception is thrown if trying to make a has_many() when there is >1 fk between the two tables' );

    my ($fk) =
        grep { $_->source_columns()->[0]->name() eq 'editor_user_id' }
        $Schema->foreign_keys_between_tables( 'Message', 'User' );

    eval
    {
        has_many 'edited_messages' =>
            ( table => $Schema->table('Message'),
              fk    => $fk,
            );
    };

    ::is( $@, '', 'no error when specifying passing a disambiguating fk to has_many' );
}
