package Fey::Class::Schema;

use strict;
use warnings;

use base 'Class::Singleton';

use Fey::Core;
use Fey::DBIManager;
use Fey::Validate qw( validate validate_pos SCHEMA_TYPE );


sub instance
{
    return $_[0] if ref $_[0];

    my $class = shift;
    die "Cannot make an instance of $class, create a subclass instead"
        if $class eq __PACKAGE__;

    return $class->SUPER::instance(@_);
}

{
    my %ClassForSchema;

    my $spec = SCHEMA_TYPE;
    sub SetSchema
    {
        my $self = shift->instance();
        my ($schema) = validate_pos( @_, SCHEMA_TYPE );

        my $sname = $schema->name();
        if ( $ClassForSchema{$sname} )
        {
            die "The $sname schema already belongs to the $ClassForSchema{$sname} class.";
        }

        $self->{schema} = $schema;
        $ClassForSchema{$sname} = ref $self;
    }

    sub ClassForSchema
    {
        return $ClassForSchema{ $_[1]->name() };
    }
}

sub Schema { $_[0]->instance->{schema} }

{
    my $spec = Fey::DBIManager->ConstructorSpec();

    sub AddSourceInfo
    {
        my $self = shift->instance();
        my %p    = validate( @_, $spec );

        $self->{connect_info}{ $p{name} } = \%p;
    }
}

sub SetCurrentSourceName
{
    my $self = shift->instance();

    $self->{default_source_name} = shift;
}

sub CurrentSourceName
{
    my $self = ref $_[0] ? $_[0] : $_[0]->instance();

    return $self->{default_source_name} || 'main';
}

sub Source
{
    my $self = shift->instance();
    my $name = shift || $self->CurrentSourceName();

    die "No source named $name, call AddSourceInfo first."
        unless $self->{connect_info}{$name};

    return
        $self->{sources}{$name} ||=
            Fey::DBIManager->new( %{ $self->{connect_info}{$name} } );
}


1;

__END__
