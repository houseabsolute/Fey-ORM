package Fey::Class::Test;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw( schema );

use Fey::Test;


sub schema
{
    my $schema = Fey::Test->mock_test_schema_with_fks();
    $schema->table('Message')->add_column
        ( Fey::Column->new( name => 'user_id',
                            type => 'integer',
                          ) );

    $schema->add_foreign_key
        ( Fey::FK->new
          ( source_columns => [ $schema->table('Message')->column('user_id') ],
            target_columns => [ $schema->table('User')->column('user_id') ],
          )
        );

    return $schema;
}


1;
