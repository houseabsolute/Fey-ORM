# This isn't really an example, so much as some ideas I had when I
# started. Some have been done in a different way already, and some
# still need implementation.

package VegGuide::Vendor;

use strict;
use warnings;

use VegGuide::Schema;

use Fey::ORM;


cache_objects;

has_table => VegGuide::Schema->Schema()->table('Vendor');

has 'is_closed' =>
    ( is       => 'ro',
      isa      => 'Bool',
      lazy     => 1,
      default  => sub { return defined $_[0]->close_date_raw() },
      init_arg => "\0is_closed",
    );

has_many 'categories' =>
    ( foreign_table => 'Category',
      via_table     => 'VendorCategory',
      order_by      => VegGuide::Schema->Schema()->table('Category')->column('display_order'),
      id_reader     => 'category_ids',
      counter       => 'category_count',
      cache         => 1,
    );

has_one 'location' =>
    ( foreign_table => 'Location',
      cache         => 1,
    );

has 'primary_category' =>
    ( is       => 'ro',
      isa      => 'Vendor::Category',
      lazy     => 1,
      default  => sub { return ( $_[0]->categories() )[0] },
      init_arg => "\0primary_category",
    );

has_sql 'weighted_rating' =>
    ( is      => 'ro',
      isa     => 'Int',
      lazy    => 1,
      default => sub { $_[0]->_weighted_rating() },
    );

no Fey::ORM;

package VegGuide::Location;


package VegGuide::Fey::Policy;

use Fey::ORM::Policy;

use DateTime::Format::MySQL;


transform
    => matching { $_->generic_type()  eq 'date' }
    => inflate { return unless defined;
                 DateTime::Format::MySQL->parse_date($_) }
    => deflate { ref $_ ? DateTime::Format::MySQL->format_date($_) : $_ };

class_has 'Count' =>
    ( is      => 'ro',
      isa     => 'Int',
      lazy    => 1,
      default => sub { ... },
    );
