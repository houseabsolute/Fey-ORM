use strict;
use warnings;

use Test::More;

use lib 't/lib';

use Fey::ORM::Test;
use Fey::Literal::Function;


Fey::ORM::Test::define_live_classes();
Fey::ORM::Test::insert_user_data();

plan tests => 2;


{
    package User;

    use Fey::ORM::Table;

    has email_length =>
        ( metaclass   => 'FromSelect',
          is          => 'ro',
          isa         => 'Int',
          select      => __PACKAGE__->_BuildEmailLengthSelect(),
          bind_params => sub { $_[0]->user_id() },
        );

    has user_ids =>
        ( metaclass   => 'FromSelect',
          is          => 'ro',
          isa         => 'ArrayRef',
          select      => __PACKAGE__->_BuildUserIdsSelect(),
        );

    sub _BuildEmailLengthSelect
    {
        my $class = shift;

        my $schema = Schema->Schema();

        my $length =
            Fey::Literal::Function->new( 'LENGTH', $class->Table()->column('email') );

        my $select = Schema->SQLFactoryClass()->new_select();

        $select->select($length)
               ->from( $class->Table() )
               ->where( $class->Table()->column('user_id'), '=',
                        Fey::Placeholder->new() );

        return $select;
    }

    sub _BuildUserIdsSelect
    {
        my $class = shift;

        my $schema = Schema->Schema();

        my $select = Schema->SQLFactoryClass()->new_select();

        $select->select( $class->Table()->column('user_id') )
               ->from( $class->Table() )
               ->order_by( $class->Table()->column('user_id') );

        return $select;
    }
}

{
    my $user = User->new( user_id => 1 );
    is( $user->email_length(), length $user->email(),
        'email_length accessor gets the right value' );
    is_deeply( $user->user_ids(), [ 1, 42 ],
               'user_ids returns an arrayref with the expected values' );
}
