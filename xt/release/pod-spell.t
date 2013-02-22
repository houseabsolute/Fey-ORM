use strict;
use warnings;

use Test::Spelling;

my @stopwords;
for (<DATA>) {
    chomp;
    push @stopwords, $_
        unless /\A (?: \# | \s* \z)/msx;    # skip comments, whitespace
}

add_stopwords(@stopwords);
set_spell_cmd('aspell list -l en');

# This prevents a weird segfault from the aspell command - see
# https://bugs.launchpad.net/ubuntu/+source/aspell/+bug/71322
local $ENV{LC_ALL} = 'C';
all_pod_files_spelling_ok;

__DATA__
API
APIs
DBI
DBI's
FromSelect
HasX
OO
ORM
Rolsky
SQL
SQLite
SUBCLASSES
SomeTable
attribute's
dbh
dbms
deflator
deflators
fk
inflator
iterator's
lookup
metaclass
metaclass's
multi
namespace
nullable
optimizations
params
rethrows
subclasses
subref
subtype
unhashed
unsets
username
webapp
