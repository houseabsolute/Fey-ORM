package Fey::Meta::Method::FromSelect;

use strict;
use warnings;
use namespace::autoclean;

use Moose;

extends 'Moose::Meta::Method', 'Class::MOP::Method::Generated';

with 'Fey::Meta::Role::FromSelect';

sub new {
    my $class   = shift;
    my %options = @_;

    ( $options{package_name} && $options{name} )
        || confess
        "You must supply the package_name and name parameters $Class::MOP::Method::UPGRADE_ERROR_TEXT";

    $options{select}
        || confess 'You must supply a select query';

    my $self = $class->_new( \%options );

    $self->_initialize_body;

    return $self;
}

sub _new {
    my $class = shift;
    my $options = @_ == 1 ? $_[0] : {@_};

    return bless $options, $class;
}

sub _initialize_body {
    my $self = shift;

    $self->{body} = $self->_make_sub_from_select(
        $self->select(),
        $self->bind_params(),
        $self->is_multi_column(),
    );

}

__PACKAGE__->meta()->make_immutable( inline_constructor => 0 );

1;
