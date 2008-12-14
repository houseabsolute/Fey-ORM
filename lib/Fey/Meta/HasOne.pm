package Fey::Meta::HasOne;

use strict;
use warnings;

use Fey::Exceptions qw( param_error );

use Moose;
use MooseX::StrictConstructor;

extends 'Fey::Meta::FK';

has associated_class =>
    ( is       => 'rw',
      isa      => 'Fey::Meta::Class::Table',
      writer   => '_set_associated_class',
      weak_ref => 1,
      init_arg => undef,
    );

has name =>
    ( is         => 'ro',
      isa        => 'Str',
      lazy_build => 1,
    );

has table =>
    ( is       => 'ro',
      isa      => 'Fey.ORM.Type.TableWithSchema',
      required => 1,
    );

has foreign_table =>
    ( is       => 'ro',
      isa      => 'Fey.ORM.Type.TableWithSchema',
      required => 1,
    );

has is_cached =>
    ( is      => 'ro',
      isa     => 'Bool',
      default => 1,
    );

has handles =>
    ( is  => 'ro',
      # just gets passed on for attribute creation
      isa => 'Any',
    );

has allows_undef =>
    ( is         => 'ro',
      isa        => 'Bool',
      lazy_build => 1,
    );


sub _build_name
{
    my $self = shift;

    return lc $self->foreign_table()->name();
}

sub attach_to_class
{
    my $self  = shift;
    my $class = shift;

    $self->_set_associated_class($class);

    if ( $self->is_cached() )
    {
        $self->_make_attribute();
    }
    else
    {
        $self->_make_method();
    }
}

sub _make_attribute
{
    my $self = shift;

    # It'd be nice to set isa to the actual foreign class, but we may
    # not be able to map a table to a class yet, since that depends on
    # the related class being loaded. It doesn't really matter, since
    # this accessor is read-only, so there's really no typing issue to
    # deal with.
    my $type = 'Fey::Object::Table';
    $type = "Maybe[$type]" if $self->allows_undef();

    my %attr_p =
        ( is        => 'rw',
          isa       => $type,
          lazy      => 1,
          default   => $self->_make_subref(),
          writer    => q{_set_} . $self->name(),
          predicate => q{_has_} . $self->name(),
          clearer   => q{_clear_} . $self->name(),
        );

    $attr_p{handles} = $self->handles()
        if $self->handles();

    $self->associated_class()->add_attribute( $self->name(), %attr_p );
}

sub _make_method
{
    my $self = shift;

    $self->associated_class()->add_method
        ( $self->name() => $self->_make_subref() );
}


no Moose;

__PACKAGE__->meta()->make_immutable();

1;
