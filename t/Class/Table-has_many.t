use strict;
use warnings;

use Test::More tests => 11;

use lib 't/lib';

use Fey::ORM::Test qw( schema );
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

    my $attr = User->meta()->get_attribute('_messages');
    ok( $attr, 'found attribute for _messages' );
    is( ref $attr->default(), 'CODE',
        'messages attribute default is a coderef' );
    is( $attr->type_constraint()->name(), 'Fey::Object::Iterator::Caching',
        'messages attribute type constraint is Fey::Object::Iterator::Caching' );

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

