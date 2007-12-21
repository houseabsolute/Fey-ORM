use strict;
use warnings;

use Test::More tests => 11;

use Fey::Class::Schema;
use Fey::Test;


{
    eval { Fey::Class::Schema->instance() };
    like( $@, qr/Cannot make an instance of Fey::Class::Schema/,
          'Cannot call instance() on Fey::Class::Schema' );
}

{
    is( My::Schema->CurrentSourceName(), 'main',
        'default current source is main' );

    My::Schema->SetCurrentSourceName('bob');

    is( My::Schema->CurrentSourceName(), 'bob',
        'current source is bob' );

    eval { My::Schema->Source() };
    like( $@, qr/No source named bob/,
          'Cannot call Source() without source info' );

    eval { My::Schema->Source('main') };
    like( $@, qr/No source named main/,
          'Cannot call Source() without source info' );

    My::Schema->AddSourceInfo( name => 'main',
                               dsn  => 'dbi:Mock:main',
                             );

    My::Schema->SetCurrentSourceName(undef);

    my $man = My::Schema->Source();
    is( $man->dbh()->{Name}, 'main',
        'Source() returns main source by default' );


    My::Schema->AddSourceInfo( name => 'bob',
                               dsn  => 'dbi:Mock:bob',
                             );

    $man = My::Schema->Source('bob');
    is( $man->dbh()->{Name}, 'bob',
        'Source() returns named source if given an argument' );

    My::Schema->SetCurrentSourceName('bob');

    $man = My::Schema->Source();
    is( $man->dbh()->{Name}, 'bob',
        'Source() returns current source when current source is set' );
}

{
    my $schema = Fey::Test->mock_test_schema();

    My::Schema->SetSchema($schema);

    is( My::Schema->Schema()->name(), $schema->name(),
        'Schema() returns schema passed to My::Schema' );

    eval { My::Schema->SetSchema($schema) };
    like( $@, qr/already belongs to the My::Schema class/,
          'Cannot pass the same schema to SetSchema twice' );

    is( Fey::Class::Schema->ClassForSchema($schema), 'My::Schema',
        'ClassForSchema() finds right class for schema object' );
}

package My::Schema;

use base 'Fey::Class::Schema';
