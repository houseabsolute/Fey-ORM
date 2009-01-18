package Fey::ORM::Policy;

use strict;
use warnings;

use Fey::Object::Policy;


{
    my @subs;

    BEGIN
    {
        @subs = qw( Policy transform_all matching inflate deflate
                    has_one_namer has_many_namer );
    }

    use Sub::Exporter -setup =>
        { exports => \@subs,
          groups  => { default => \@subs },
        };
}

# I could use MooseX::ClassAttribute and add a class attribute to the
# calling class, but really, that class doesn't need to use Moose,
# since it's just a name we can use to find the associated policy
# object.
{
    my %Policies;

    sub Policy
    {
        my $caller = shift;

        return $Policies{$caller} ||= Fey::Object::Policy->new();
    }
}

sub transform_all
{
    my $class = caller();

    $class->Policy()->add_transform( {@_} );
}

sub matching (&)
{
    return ( matching => $_[0] );
}

sub inflate (&)
{
    return ( inflate => $_[0] );
}

sub deflate (&)
{
    return ( deflate => $_[0] );
}

sub has_one_namer (&)
{
    my $class = caller();

    $class->Policy()->set_has_one_namer( $_[0] );
}

sub has_many_namer (&)
{
    my $class = caller();

    $class->Policy()->set_has_many_namer( $_[0] );
}

1;

__END__

=head1 SYNOPSIS

  package MyApp::Policy;

  use strict;
  use warnings;

  use Fey::ORM::Policy;
  use Lingua::EN::Inflect qw( PL_N );

  transform_all
         matching { $_[0]->type() eq 'date' }

      => inflate  { return unless defined $_[1];
                    return DateTime::Format::Pg->parse_date( $_[1] ) }

      => deflate  { defined $_[1] && ref $_[1]
                      ? DateTime::Format::Pg->format_date( $_[1] )
                      : $_[1] };

  has_many_namer { my $name = $_[0]->name();
                   my @parts = map { lc } /([A-Z][a-z]+)+/;

                   $parts[-1] = PL_N( $parts[-1] );

                   return join q{_}, @parts; };
