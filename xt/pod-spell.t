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
APIs
attribute's
deflator
deflators
dbms
dbh
DBI
fk
FromSelect
inflator
iterator's
lookup
ORM
metaclass
metaclass's
multi
namespace
nullable
params
rethrows
SomeTable
SQLite
subref
unhashed
unsets
username
