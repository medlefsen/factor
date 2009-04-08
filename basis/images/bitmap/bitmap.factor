! Copyright (C) 2007, 2009 Doug Coleman.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors alien alien.c-types arrays byte-arrays columns
combinators fry grouping io io.binary io.encodings.binary io.files
kernel macros math math.bitwise math.functions namespaces sequences
strings images endian summary locals ;
IN: images.bitmap

: assert-sequence= ( a b -- )
    2dup sequence= [ 2drop ] [ assert ] if ;

: read2 ( -- n ) 2 read le> ;
: read4 ( -- n ) 4 read le> ;
: write2 ( n -- ) 2 >le write ;
: write4 ( n -- ) 4 >le write ;

TUPLE: bitmap-image < image ;

! Used to construct the final bitmap-image

TUPLE: loading-bitmap 
size reserved offset header-length width
height planes bit-count compression size-image
x-pels y-pels color-used color-important rgb-quads color-index ;

ERROR: bitmap-magic magic ;

M: bitmap-magic summary
    drop "First two bytes of bitmap stream must be 'BM'" ;

<PRIVATE

: 8bit>buffer ( bitmap -- array )
    [ rgb-quads>> 4 <sliced-groups> [ 3 head-slice ] map ]
    [ color-index>> >array ] bi [ swap nth ] with map concat ;

ERROR: bmp-not-supported n ;

: reverse-lines ( byte-array width -- byte-array )
    3 * <sliced-groups> <reversed> concat ; inline

: raw-bitmap>seq ( loading-bitmap -- array )
    dup bit-count>>
    {
        { 32 [ color-index>> ] }
        { 24 [ [ color-index>> ] [ width>> ] bi reverse-lines ] }
        { 8 [ [ 8bit>buffer ] [ width>> ] bi reverse-lines ] }
        [ bmp-not-supported ]
    } case >byte-array ;

: parse-file-header ( loading-bitmap -- loading-bitmap )
    2 read "BM" assert-sequence=
    read4 >>size
    read4 >>reserved
    read4 >>offset ;

: parse-bitmap-header ( loading-bitmap -- loading-bitmap )
    read4 >>header-length
    read4 >>width
    read4 32 >signed >>height
    read2 >>planes
    read2 >>bit-count
    read4 >>compression
    read4 >>size-image
    read4 >>x-pels
    read4 >>y-pels
    read4 >>color-used
    read4 >>color-important ;

: rgb-quads-length ( loading-bitmap -- n )
    [ offset>> 14 - ] [ header-length>> ] bi - ;

: color-index-length ( loading-bitmap -- n )
    {
        [ width>> ]
        [ planes>> * ]
        [ bit-count>> * 31 + 32 /i 4 * ]
        [ height>> abs * ]
    } cleave ;

: image-size ( loading-bitmap -- n )
    [ [ width>> ] [ height>> ] bi * ] [ bit-count>> 8 /i ] bi * abs ;

:: fixup-color-index ( loading-bitmap -- loading-bitmap )
    loading-bitmap width>> :> width
    width 3 * :> width*3
    loading-bitmap height>> abs :> height
    loading-bitmap color-index>> length :> color-index-length
    color-index-length height /i :> stride
    color-index-length width*3 height * - height /i :> padding
    padding 0 > [
        loading-bitmap [
            stride <sliced-groups>
            [ width*3 head-slice ] map concat
        ] change-color-index
    ] [
        loading-bitmap
    ] if ;

: parse-bitmap ( loading-bitmap -- loading-bitmap )
    dup rgb-quads-length read >>rgb-quads
    dup color-index-length read >>color-index
    fixup-color-index ;

: load-bitmap-data ( path loading-bitmap -- loading-bitmap )
    [ binary ] dip '[
        _ parse-file-header parse-bitmap-header parse-bitmap
    ] with-file-reader ;

ERROR: unknown-component-order bitmap ;

: bitmap>component-order ( loading-bitmap -- object )
    bit-count>> {
        { 32 [ BGRA ] }
        { 24 [ BGR ] }
        { 8 [ BGR ] }
        [ unknown-component-order ]
    } case ;

: loading-bitmap>bitmap-image ( loading-bitmap -- bitmap-image )
    [ bitmap-image new ] dip
    {
        [ raw-bitmap>seq >>bitmap ]
        [ [ width>> ] [ height>> abs ] bi 2array >>dim ]
        [ height>> 0 < [ t >>upside-down? ] when ]
        [ bitmap>component-order >>component-order ]
    } cleave ;

M: bitmap-image load-image* ( path loading-bitmap -- bitmap )
    drop loading-bitmap new
    load-bitmap-data
    loading-bitmap>bitmap-image ;

PRIVATE>

: bitmap>color-index ( bitmap-array -- byte-array )
    4 <sliced-groups> [ 3 head-slice <reversed> ] map B{ } join ; inline

: save-bitmap ( image path -- )
    binary [
        B{ CHAR: B CHAR: M } write
        [
            bitmap>> bitmap>color-index length 14 + 40 + write4
            0 write4
            54 write4
            40 write4
        ] [
            {
                ! width height
                [ dim>> first2 [ write4 ] bi@ ]

                ! planes
                [ drop 1 write2 ]

                ! bit-count
                [ drop 24 write2 ]

                ! compression
                [ drop 0 write4 ]

                ! size-image
                [ bitmap>> bitmap>color-index length write4 ]

                ! x-pels
                [ drop 0 write4 ]

                ! y-pels
                [ drop 0 write4 ]

                ! color-used
                [ drop 0 write4 ]

                ! color-important
                [ drop 0 write4 ]

                ! rgb-quads
                [
                    [ bitmap>> bitmap>color-index ] [ dim>> first ] bi
                    reverse-lines write
                ]
            } cleave
        ] bi
    ] with-file-writer ;