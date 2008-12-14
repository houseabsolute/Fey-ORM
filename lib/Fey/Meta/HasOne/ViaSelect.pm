package Fey::Meta::HasOne::ViaSelect;

use strict;
use warnings;

use Moose;
use MooseX::StrictConstructor;

extends 'Fey::Meta::HasOne';


has 'select' =>
    ( is       => 'ro',
      isa      => 'Fey::SQL::Select',
      required => 1,
    );

has 'bind_params' =>
    ( is  => 'ro',
      isa => 'CodeRef',
    );



# Since we don't know the content of the SQL, we just assume it can
# undef
sub _build_allows_undef
{
    return 1;
}

sub _make_subref
{
    my $self = shift;

    my $foreign_table = $self->foreign_table();
    my $select        = $self->select();
    my $bind          = $self->bind_params();

    # XXX - this is really similar to
    # Fey::Object::Table->_get_column_values() and needs some serious
    # cleanup.
    return
        sub { my $self = shift;

              my $dbh = $self->_dbh($select);

              my $sth = $dbh->prepare( $select->sql($dbh) );

              $sth->execute( $bind ? $self->$bind() : () );

              my %col_values;
              $sth->bind_columns( \( @col_values{ @{ $sth->{NAME} } } ) );

              my $fetched = $sth->fetch();

              $sth->finish();

              return unless $fetched;

              $self->meta()->ClassForTable($foreign_table)->new
                  ( %col_values, _from_query => 1 );
            };

}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
