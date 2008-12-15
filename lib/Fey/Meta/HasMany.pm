package Fey::Meta::HasMany;

use strict;
use warnings;

use Fey::Exceptions qw( param_error );

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::StrictConstructor;

extends 'Fey::Meta::FK';


has associated_method =>
    ( is         => 'rw',
      isa        => 'Moose::Meta::Method',
      writer     => '_set_associated_method',
      init_arg   => undef,
      lazy_build => 1,
    );

subtype 'Fey.ORM.Type.IteratorClass'
    => as 'ClassName'
    => where { $_[0]->isa('Fey::Object::Iterator') }
    => message { "$_[0] is a not a subclass of Fey::Object::Iterator" };

has 'iterator_class' =>
    ( is         => 'ro',
      isa        => 'Fey.ORM.Type.IteratorClass',
      lazy_build => 1,
    );


sub _build_name
{
    my $self = shift;

    return lc $self->foreign_table()->name();
}

sub _build_iterator_class
{
    my $self = shift;

    return
        $self->is_cached()
        ? 'Fey::Object::Iterator::Caching'
        : 'Fey::Object::Iterator';
}

sub _build_is_cached { 0 }

sub _build_associated_method
{
    my $self = shift;

    my $iterator_maker = $self->_make_iterator_maker();

    my $iterator;
    my $method = sub { $iterator ||= $_[0]->$iterator_maker();
                       $iterator->reset();
                       return $iterator; };

    return
        $self->associated_class()->method_metaclass()
             ->wrap( name         => $self->name(),
                     package_name => $self->associated_class()->name(),
                     body         => $method,
                   );
}

sub _make_subref_for_sql
{
    my $self     = shift;
    my $select   = shift;
    my $bind_sub = shift;

    my $target_table = $self->foreign_table();

    my $iterator_class = $self->iterator_class();

    return
        sub { my $self = shift;

              my $class = $self->meta()->ClassForTable($target_table);

              my $dbh = $self->_dbh($select);

              return
                  $iterator_class->new( classes     => $class,
                                        dbh         => $dbh,
                                        select      => $select,
                                        bind_params => [ $self->$bind_sub() ],
                                      );
            };

}

sub attach_to_class
{
    my $self  = shift;
    my $class = shift;

    $self->_set_associated_class($class);

    $class->add_method( $self->name() => $self->associated_method() );
}

sub detach_from_class
{
    my $self  = shift;

    return unless $self->associated_class();

    $self->associated_class->remove_method( $self->name() );

    $self->_clear_associated_class();
}


no Moose;
no Moose::Util::TypeConstraints;

__PACKAGE__->meta()->make_immutable();

1;
