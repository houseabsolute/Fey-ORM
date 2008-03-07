package Fey::ORM;

use strict;
use warnings;

our $VERSION = '0.04';


1;

__END__

=head1 NAME

Fey::ORM - A Fey-based ORM

=head1 SYNOPSIS

For a "table-based" class for the User table:

  package MyApp::Model::User;

  use MyApp::Model::Schema;
  use Fey::Class::Table;

  my $schema = MyApp::Model::Schema->new();

  has_table $schema->table('User');

  has_one $schema->table('Group');

  has_many 'messages' =>
      ( table =>  $schema->table('Messages') );

Here is what C<MyApp::Model::Schema> might look like:

  package MyApp::Model::Schema;

  use Fey::Class::Schema;
  use Fey::DBIManager::Source;
  use Fey::Loader;

  my $source =
      Fey::DBIManager::Source->new( dsn  => 'dbi:Pg:dbname=MyApp',
                                    user => 'myapp',
                                  );

  my $schema = Fey::Loader->new( dbh => $source->dbh() )->make_schema();

  has_schema $Schema;

  __PACKAGE__->DBIManager()->add_source($source);

Then in your application:

  use MyApp::Model::User;

  my $user = MyApp::Model::User->new( user_id => 1 );

  print $user->username();

  $user->update( username => 'bob' );

=head1 DESCRIPTION

C<Fey::ORM> builds on top of other Fey project libraries to create an
ORM focused on easy SQL generation. This is an ORM for people who are
comfortable with SQL and want to be able to use it with their objects,
rather than people who like OO and don't want to think about the DBMS.

C<Fey::ORM> also draws inspiration from C<Moose> and tries to provide
as much functionality as it can via a simple declarative interface. Of
course, it uses C<Moose> under the hood for its implementation.

=head1 EARLY VERSION WARNING

B<This is still very new software, and APIs may change in future
releases without notice. You have been warned.>

Moreover, this software is still missing a number of features which
will be needed to make it more easily usable and competitive with
other ORM packages.

=head1 GETTING STARTED

You should start by reading L<Fey::ORM::Manual::Intro>. This will walk
you through creating a set of classes based on a schema. Then look at
L<Fey::ORM::Manual> for a list of additional documentation.

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-fey-orm@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 COPYRIGHT & LICENSE

Copyright 2006-2008 Dave Rolsky, All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. The full text of the license
can be found in the LICENSE file included with this module.

=cut
