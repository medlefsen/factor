USING: accessors assocs math kernel shuffle generalizations
words quotations arrays combinators sequences math.vectors
io.styles prettyprint vocabs sorting io generic locals.private
math.statistics math.order combinators.lib ;
IN: reports.noise

: badness ( word -- n )
    H{
        { -nrot 5 }
        { -roll 4 }
        { -rot 3 }
        { bi@ 1 }
        { 2curry 1 }
        { 2drop 1 }
        { 2dup 1 }
        { 2keep 1 }
        { 2nip 2 }
        { 2over 4 }
        { 2slip 2 }
        { 2swap 3 }
        { 2with 2 }
        { 2with* 3 }
        { 3curry 2 }
        { 3drop 1 }
        { 3dup 2 }
        { 3keep 3 }
        { 3nip 4 }
        { 3slip 3 }
        { 3with 3 }
        { 3with* 4 }
        { 4drop 2 }
        { 4dup 3 }
        { 4slip 4 }
        { compose 1/2 }
        { curry 1/3 }
        { dip 1 }
        { 2dip 2 }
        { drop 1/3 }
        { dup 1/3 }
        { if 1/3 }
        { when 1/4 }
        { unless 1/4 }
        { when* 1/3 }
        { unless* 1/3 }
        { ?if 1/2 }
        { cond 1/2 }
        { case 1/2 }
        { keep 1 }
        { napply 2 }
        { ncurry 3 }
        { ndip 5 }
        { ndrop 2 }
        { ndup 3 }
        { nip 2 }
        { nipd 3 }
        { nkeep 5 }
        { npick 6 }
        { nrev 5 }
        { nrot 5 }
        { nslip 5 }
        { ntuck 6 }
        { nwith 4 }
        { over 2 }
        { pick 4 }
        { roll 4 }
        { rot 3 }
        { slip 1 }
        { spin 3 }
        { swap 1 }
        { swapd 3 }
        { tuck 2 }
        { tuckd 4 }
        { with 1/2 }
        { with* 2 }
        { r> 1 }
        { >r 1 }

        { bi 1/2 }
        { tri 1 }
        { bi* 1/2 }
        { tri* 1 }

        { cleave 2 }
        { spread 2 }
    } at 0 or ;

: vsum ( pairs -- pair ) { 0 0 } [ v+ ] reduce ;

GENERIC: noise ( obj -- pair )

M: word noise badness 1 2array ;

M: wrapper noise wrapped>> noise ;

M: let noise let-body noise ;

M: wlet noise wlet-body noise ;

M: lambda noise lambda-body noise ;

M: object noise drop { 0 0 } ;

M: quotation noise [ noise ] map vsum { 1/4 1/2 } v+ ;

M: array noise [ noise ] map vsum ;

: noise-factor ( x y -- z ) / 100 * >integer ;

: quot-noise-factor ( quot -- n )
    #! For very short words, noise doesn't count so much
    #! (so dup foo swap bar isn't penalized as badly).
    noise first2 {
        { [ over 4 <= ] [ >r drop 0 r> ] }
        { [ over 15 >= ] [ >r 2 * r> ] }
        [ ]
    } cond
    {
        ! short words are easier to read
        { [ dup 10 <= ] [ >r 2 / r> ] }
        { [ dup 5 <= ] [ >r 3 / r> ] }
        ! long words are penalized even more
        { [ dup 25 >= ] [ >r 2 * r> 20 max ] }
        { [ dup 20 >= ] [ >r 5/3 * r> ] }
        { [ dup 15 >= ] [ >r 3/2 * r> ] }
        [ ]
    } cond noise-factor ;

GENERIC: word-noise-factor ( word -- factor )

M: word word-noise-factor
    def>> quot-noise-factor ;

M: lambda-word word-noise-factor
    "lambda" word-prop quot-noise-factor ;

: flatten-generics ( words -- words' )
    [
        dup generic? [ "methods" word-prop values ] [ 1array ] if
    ] map concat ;

: noisy-words ( -- alist )
    all-words flatten-generics
    [ dup word-noise-factor ] { } map>assoc
    sort-values reverse ;

: noise. ( alist -- )
    standard-table-style [
        [
            [ [ pprint-cell ] [ pprint-cell ] bi* ] with-row
        ] assoc-each
    ] tabular-output ;

: vocab-noise-factor ( vocab -- factor )
    words flatten-generics
    [ word-noise-factor dup 20 < [ drop 0 ] when ] map
    dup empty? [ drop 0 ] [
        [ [ sum ] [ length 5 max ] bi /i ]
        [ supremum ]
        bi +
    ] if ;

: noisy-vocabs ( -- alist )
    vocabs [ dup vocab-noise-factor ] { } map>assoc
    sort-values reverse ;

: noise-report ( -- )
    "NOISY WORDS:" print
    noisy-words 80 head noise.
    nl
    "NOISY VOCABS:" print
    noisy-vocabs 80 head noise. ;

MAIN: noise-report
