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
all_pod_files_spelling_ok;

__DATA__
APIs
attribute's
deflator
deflators
dbms
DBI
fk
inflator
lookup
ORM
metaclass
multi
namespace
nullable
rethrows
unhashed
unsets
username

