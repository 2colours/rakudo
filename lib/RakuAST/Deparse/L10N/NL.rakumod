# This file contains that Dutch translation of features of the Raku
# Programming Language, and as such only has meaning as a template for
# other translations.
#
# See lib/RakuAST/Deparse/CORE.rakumod for more explanation.

use v6.e.PREVIEW;

unit role RakuAST::Deparse::L10N::NL;

my constant %translation =
  block-default  => 'indien-niets',
  block-else     => 'anders',
  block-elsif    => 'anders-als',
  block-for      => 'voor-alle',
  block-given    => 'gegeven',
  block-if       => 'als',
  block-loop     => 'lus',
  block-orwith   => 'of-met',
  block-repeat   => 'herhaal',
  block-unless   => 'tenzij',
  block-until    => 'totdat',
  block-when     => 'indien',
  block-while    => 'zolang',
  block-with     => 'met',
  block-without  => 'zonder',

#  core-abs              => 'abs',
  core-all              => 'alle',
  core-any              => 'elke',
  core-append           => 'voeg-achteraan',
#  core-ast              => 'ast',
#  core-atomic-add-fetch => 'atomic-add-fetch',
#  core-atomic-assign    => 'atomic-assign',
#  core-atomic-dec-fetch => 'atomic-dec-fetch',
#  core-atomic-fetch     => 'atomic-fetch',
#  core-atomic-fetch-add => 'atomic-fetch-add',
#  core-atomic-fetch-dec => 'atomic-fetch-dec',
#  core-atomic-fetch-inc => 'atomic-fetch-inc',
#  core-atomic-fetch-sub => 'atomic-fetch-sub',
#  core-atomic-inc-fetch => 'atomic-inc-fetch',
#  core-atomic-sub-fetch => 'atomic-sub-fetch',
  core-await            => 'wacht-op',

  core-bag => 'tas',

#  core-callframe    => 'callframe',
#  core-callsame     => 'callsame',
#  core-callwith     => 'callwith',
#  core-cas          => 'cas',
  core-categorize   => 'categoriseer',
  core-ceiling      => 'plafond',
  core-chars        => 'letters',
#  core-chdir        => 'chdir',
#  core-chmod        => 'chmod',
  core-chomp        => 'kap-regeleinde',
  core-chop         => 'kap',
#  core-chown        => 'chown',
  core-chr          => 'als-letter',
  core-chrs         => 'als-letters',
  core-classify     => 'classificeer',
  core-close        => 'sluit',
  core-comb         => 'kam',
  core-combinations => 'combinaties',

  core-deepmap => 'diep-arrangeer',
  core-defined => 'gedefinieerd',
  core-die     => 'sterf',
#  core-dir     => 'dir',
  core-done    => 'klaar',
  core-duckmap => 'duik-arrangeer',

  core-elems  => 'elementen',
  core-emit   => 'zend',
  core-end    => 'einde',
  core-exit   => 'verlaat',
#  core-exp    => 'exp',
#  core-expmod => 'expmod',

  core-fail         => 'faal',
  core-fc           => 'vouw-kast',
  core-first        => 'eerste',
  core-flat         => 'plat',
  core-flip         => 'draaiom',
  core-floor        => 'vloer',
#  core-full-barrier => 'full-barrier',

  core-get  => 'pak',
  core-getc => 'pakc',
  core-gist => 'kern',
  core-grep => 'filter',

  core-hash => 'moes',
  core-head => 'hoofd',

  core-indent  => 'indenteer',
#  core-index   => 'index',
#  core-indices => 'indices',
#  core-indir   => 'indir',
#  core-item    => 'item',

  core-join => 'plak',

  core-key  => 'sleutel',
  core-keys => 'sleutels',
  core-kv   => 'sw',

  core-last     => 'laatste',
  core-lastcall => 'laatste-aanroep',
  core-lc       => 'onder-kast',
  core-lines    => 'regels',
  core-link     => 'koppeling',
  core-list     => 'lijst',
#  core-lsb      => 'lsb',

  core-make   => 'maak',
  core-map    => 'arrangeer',
#  core-max    => 'max',
#  core-min    => 'min',
#  core-minmax => 'minmax',
#  core-mix    => 'mix',
#  core-mkdir  => 'mkdir',
  core-move   => 'verplaats',
#  core-msb    => 'msb',

  core-next       => 'volgende',
#  core-nextcallee => 'nextcallee',
#  core-nextsame   => 'nextsame',
#  core-nextwith   => 'nextwith',
  core-none       => 'geen',
  core-not        => 'niet',
  core-note       => 'merk-op',

  core-one  => 'een',
#  core-open => 'open',
  core-ord  => 'als-getal',
  core-ords => 'als-getallen',

  core-pair         => 'paer',
  core-pairs        => 'paren',
#  core-parse-base   => 'parse-base',
  core-permutations => 'permutaties',
  core-pick         => 'kies',
#  core-pop          => 'pop',
  core-prepend      => 'voeg-voor',
  core-print        => 'druk',
  core-printf       => 'drukf',
  core-proceed      => 'ga-door',
  core-prompt       => 'vraag',
  core-push         => 'stapel-op',
  core-put          => 'zeg-het',

  core-rand       => 'willkeurig',
  core-redo       => 'nog-eens',
  core-reduce     => 'reduceer',
  core-repeated   => 'herhaaldelijk',
#  core-repl       => 'repl',
  core-return     => 'retour',
  core-return-rw  => 'retour-rw',
  core-reverse    => 'keer-om',
  core-rindex     => 'om-index',
#  core-rmdir      => 'rmdir',
  core-roll       => 'gooi',
  core-rotate     => 'roteer',
  core-round      => 'rond-af',
  core-roundrobin => 'ieder-een',
  core-run        => 'voer-uit',

  core-samecase    => 'zelfde-kast',
  core-samemark    => 'zelfde-accent',
#  core-samewith    => 'samewith',
  core-say         => 'zeg',
  core-set         => 'verzameling',
#  core-shell       => 'shell',
  core-shift       => 'onderuit',
  core-sign        => 'teken',
  core-signal      => 'signaal',
  core-skip        => 'sla-over',
  core-sleep       => 'slaap',
  core-sleep-timer => 'wekker',
  core-sleep-until => 'slaap-tot',
  core-slip        => 'glip',
#  core-slurp       => 'slurp',
  core-snip        => 'knip',
  core-snitch      => 'spiek',
  core-so          => 'dus',
  core-sort        => 'sorteer',
  core-splice      => 'splits-lijst',
  core-split       => 'splits-letters',
  core-sprintf     => 'sdrukf',
  core-spurt       => 'spuit',
  core-sqrt        => 'wortel',
  core-squish      => 'plet',
  core-srand       => 'zo-willekeurig',
#  core-subbuf      => 'subbuf',
#  core-subbuf-rw   => 'subbuf-rw',
  core-succeed     => 'slaag',
  core-sum         => 'sommeer',
  core-symlink     => 'symbolische-koppeling',

  core-tail          => 'staart',
  core-take          => 'neem',
  core-take-rw       => 'neem-rw',
  core-tc            => 'titel-kast',
  core-tclc          => 'titel-onder-kast',
  core-trim          => 'trim',
  core-trim-leading  => 'trim-vooraan',
  core-trim-trailing => 'trim-achteraan',
  core-truncate      => 'kap-af',

  core-uc       => 'boven-kast',
#  core-unimatch => 'unimatch',
#  core-uniname  => 'uniname',
#  core-uninames => 'uninames',
#  core-uniparse => 'uniparse',
#  core-uniprop  => 'uniprop',
#  core-uniprops => 'uniprops',
  core-unique   => 'uniek',
#  core-unival   => 'unival',
#  core-univals  => 'univals',
  core-unlink   => 'ontkoppel',
  core-unshift  => 'onderin',

  core-val    => 'als-nummers',
  core-value  => 'waarde',
  core-values => 'waardes',

  core-warn     => 'waarschuw',
  core-wordcase => 'woord-kast',
  core-words    => 'woorden',

  infix-after      => 'na',
  infix-and        => 'en',
  infix-andthen    => 'en-dan',
  infix-before     => 'voor',
  infix-but        => 'maar',
  infix-cmp        => 'vergelijk',
#  infix-coll       => 'coll',
  infix-div        => 'deel',
  infix-does       => 'doet',
  infix-eq         => 'gelijk',
#  infix-ff         => 'ff',
#  infix-fff        => 'fff',
#  infix-gcd        => 'gcd',
  infix-ge         => 'groter-gelijk',
  infix-gt         => 'groter',
  infix-le         => 'kleiner-gelijk',
#  infix-lcm        => 'lcm',
  infix-leg        => 'lgg',
  infix-lt         => 'kleiner',
#  infix-max        => 'max',
#  infix-min        => 'min',
#  infix-minmax     => 'minmax',
  infix-mod        => 'modulo',
  infix-ne         => 'ongelijk',
  infix-notandthen => 'niet-en-dan',
#  infix-o          => 'o',
  infix-or         => 'of',
  infix-orelse     => 'of-anders',
#  infix-unicmp     => 'unicmp',
#  infix-x          => 'x',
#  infix-X          => 'X',
#  infix-xx         => 'xx',
#  infix-Z          => 'Z',
#  'infix-ff^'      => 'ff^',
#  'infix-fff^'     => 'fff^',
  'infix-(cont)'   => '(bevat)',
  'infix-(elem)'   => '(is-element-van)',
#  'infix-^ff'      => '^ff',
#  'infix-^fff'     => '^fff',
#  'infix-^ff^'     => '^ff^',
#  'infix-^fff^'    => '^fff^',

  modifier-for     => 'voor-alle',
  modifier-given   => 'gegeven',
  modifier-if      => 'als',
  modifier-unless  => 'tenzij',
  modifier-until   => 'tot',
  modifier-when    => 'indien',
  modifier-while   => 'terwijl',
  modifier-with    => 'met',
  modifier-without => 'zonder',

#  multi-multi => 'multi',
  multi-only  => 'alleen',
#  multi-proto => 'proto',

  package-class   => 'klasse',
  package-grammar => 'grammatica',
  package-module  => 'module',
  package-package => 'pakket',
  package-role    => 'rol',

#  phaser-BEGIN   => 'BEGIN',
  phaser-CATCH   => 'VANG-FOUT',
#  phaser-CHECK   => 'CHECK',
  phaser-CLOSE   => 'CLOSE',
  phaser-CONTROL => 'VANG-BERICHT',
#  phaser-DOC     => 'DOC',
  phaser-END     => 'EINDE',
  phaser-ENTER   => 'BINNENKOMST',
  phaser-FIRST   => 'EERSTE-KEER',
#  phaser-INIT    => 'INIT',
  phaser-KEEP    => 'ACCEPTEER',
  phaser-LAST    => 'LAATSTE-KEER',
  phaser-LEAVE   => 'AFSCHEID',
  phaser-NEXT    => 'VOLGENDE',
  phaser-PRE     => 'VOORAF',
  phaser-POST    => 'ACHTERAF',
  phaser-QUIT    => 'STOP',
  phaser-UNDO    => 'NEGEER',

  prefix-not => 'nietes',
  prefix-so  => 'welles',

  routine-method    => 'methode',
  routine-sub       => 'sub',
  routine-regex     => 'regex',
  routine-rule      => 'regel',
  routine-submethod => 'submethode',
  routine-token     => 'merkteken',

  scope-anon     => 'anoniem',
  scope-constant => 'constant',
  scope-has      => 'heeft',
  scope-HAS      => 'HEEFT',
  scope-my       => 'mijn',
  scope-our      => 'onze',
  scope-state    => 'steeds',
  scope-unit     => 'eenheid',

  stmt-prefix-do       => 'doe',
  stmt-prefix-eager    => 'vlijtig',
  stmt-prefix-gather   => 'verzamel',
  stmt-prefix-hyper    => 'hyper',
  stmt-prefix-lazy     => 'lui',
  stmt-prefix-quietly  => 'stilletjes',
  stmt-prefix-race     => 'race',
  stmt-prefix-sink     => 'zink',
  stmt-prefix-start    => 'start',
  stmt-prefix-try      => 'probeer',
  stmt-prefix-react    => 'reageer',
  stmt-prefix-whenever => 'zodra',

  trait-does    => 'doet',
  trait-hides   => 'verbergt',
  trait-is      => 'is',
  trait-of      => 'net-als',
  trait-returns => 'geeft-terug',

#  typer-enum   => 'enum',
#  typer-subset => 'subset',

  use-import  => 'importeer',
  use-need    => 'behoeft',
  use-no      => 'geen',
  use-require => 'require',
  use-use     => 'gebruik',
;

method xsyn(str $prefix, str $key) {
    %translation{"$prefix-$key"} // $key
}

# vim: expandtab shiftwidth=4
