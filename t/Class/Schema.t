use strict;
use warnings;

use Test::More tests => 7;

use lib 't/lib';

use Fey::ORM::Test qw( schema );

my $Schema = schema();

{
    package Schema;

    use Fey::ORM::Schema;

    has_schema $Schema;
}

ok( Schema->_HasSchema(), '_HasSchema() is true' );
is( Schema->Schema()->name(), $Schema->name(),
    'Schema() returns expected schema' );
isa_ok( Schema->DBIManager(), 'Fey::DBIManager' );
is( Schema->SQLFactoryClass(), 'Fey::SQL',
    'SQLFactoryClass() is Fey::SQL' );
ok( Schema->isa('Fey::Object::Schema'),
    q{Schema->isa('Fey::Object::Schema')} );

is( Fey::Meta::Class::Schema->ClassForSchema($Schema),
    'Schema',
    'ClassForSchema() return Schema as class name' );

{
    package Schema2;

    use Fey::ORM::Schema;

    eval { has_schema $Schema };

    ::like( $@, qr/associate the same schema with multiple classes/,
            'cannot associate the same schema with multiple classes' );
}
