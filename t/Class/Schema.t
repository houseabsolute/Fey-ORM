use strict;
use warnings;

use Test::More tests => 5;

use lib 't/lib';

use Fey::Class::Test qw( schema );

my $Schema = schema();

{
    package Schema;

    use Fey::Class::Schema;

    has_schema $Schema;
}

ok( Schema->HasSchema(), 'HasSchema() is true' );
is( Schema->Schema()->name(), $Schema->name(),
    'Schema() returns expected schema' );
isa_ok( Schema->DBIManager(), 'Fey::DBIManager' );
is( Schema->SQLFactoryClass(), 'Fey::SQL',
    'SQLFactoryClass() is Fey::SQL' );

is( Fey::Meta::Class::Schema->ClassForSchema($Schema),
    'Schema',
    'ClassForSchema() return Schema as class name' );
