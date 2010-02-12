use strict;
use warnings;

use Test::Exception;
use Test::More;

use Fey::Object::Iterator::FromSelect;
use Fey::SQL;

use lib 't/lib';

use Fey::ORM::Test::Iterator;
use Fey::Test;

Fey::ORM::Test::Iterator::run_shared_tests(
    'Fey::Object::Iterator::FromSelect');

{
    my $dbh = Fey::Test::SQLite->dbh();

    my $sql = Fey::SQL->new_select();

    throws_ok(
        sub {
            Fey::Object::Iterator::FromSelect->new(
                classes => [],
                dbh     => $dbh,
                select  => $sql,
            );
        },
        qr/\QAttribute (classes) does not pass the type constraint/,
        'cannot pass empty array for classes attribute'
    );

    throws_ok(
        sub {
            Fey::Object::Iterator::FromSelect->new(
                classes => ['DoesNotExist'],
                dbh     => $dbh,
                select  => $sql,
            );
        },
        qr/\QAttribute (classes) does not pass the type constraint/,
        'classes attribute must contain Fey::Object subclasses'
    );

    throws_ok(
        sub {
            Fey::Object::Iterator::FromSelect->new(
                classes       => ['User'],
                dbh           => $dbh,
                select        => $sql,
                attribute_map => {
                    0 => {
                        class     => 'Message',
                        attribute => 'message_id',
                    },
                },
            );
        },
        qr/\QCannot include a class in attribute_map (Message) unless it also in classes/,
        'cannot pass strings for classes attribute, must be a Fey::Object subclass'
    );
}

done_testing();
