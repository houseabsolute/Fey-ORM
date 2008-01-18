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

sub require_sqlite
{
    unless ( eval "use Fey::Test::SQLite; 1" )
    {
        Test::More::plan skip_all => 'These tests require Fey::Test::SQLite';
    }
}

sub insert_user_data
{
    require_sqlite();

    my $dbh = Fey::Test::SQLite->dbh();

    my $insert = 'INSERT INTO User ( user_id, username, email ) VALUES ( ?, ?, ? )';
    my $sth = $dbh->prepare($insert);

    $sth->execute( 1,  'autarch', 'autarch@example.com' );
    $sth->execute( 42, 'bubba',   'bubba@example.com' );

    $sth->finish();
}

sub define_basic_classes
{
    my $schema = schema();

    eval <<'EOF';
package Schema;

use Fey::Class::Schema;

has_schema $schema;

package User;

use Fey::Class::Table;

has_table $schema->table('User');

package Message;

use Fey::Class::Table;

has_table $schema->table('Message');
EOF

    die $@ if $@;
}

sub define_live_classes
{
    define_basic_classes();

    Schema->DBIManager()->add_source( dbh => Fey::Test::SQLite->dbh() );
}

1;
