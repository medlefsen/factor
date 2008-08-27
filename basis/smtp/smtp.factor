! Copyright (C) 2007, 2008 Elie CHAFTARI, Dirk Vleugels,
! Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: arrays namespaces io io.timeouts kernel logging io.sockets
sequences combinators sequences.lib splitting assocs strings
math.parser random system calendar io.encodings.ascii summary
calendar.format accessors sets hashtables ;
IN: smtp

SYMBOL: smtp-domain
SYMBOL: smtp-server     "localhost" "smtp" <inet> smtp-server set-global
SYMBOL: read-timeout    1 minutes read-timeout set-global
SYMBOL: esmtp           t esmtp set-global

LOG: log-smtp-connection NOTICE ( addrspec -- )

: with-smtp-connection ( quot -- )
    smtp-server get
    dup log-smtp-connection
    ascii [
        smtp-domain [ host-name or ] change
        read-timeout get timeouts
        call
    ] with-client ; inline

TUPLE: email
    { from string }
    { to array }
    { cc array }
    { bcc array }
    { subject string }
    { body string } ;

: <email> ( -- email ) email new ;

: crlf ( -- ) "\r\n" write ;

: command ( string -- ) write crlf flush ;

: helo ( -- )
    esmtp get "EHLO " "HELO " ? host-name append command ;

ERROR: bad-email-address email ;

: validate-address ( string -- string' )
    #! Make sure we send funky stuff to the server by accident.
    dup "\r\n>" intersect empty?
    [ bad-email-address ] unless ;

: mail-from ( fromaddr -- )
    "MAIL FROM:<" swap validate-address ">" 3append command ;

: rcpt-to ( to -- )
    "RCPT TO:<" swap validate-address ">" 3append command ;

: data ( -- )
    "DATA" command ;

ERROR: message-contains-dot message ;

M: message-contains-dot summary ( obj -- string )
    drop
    "Message cannot contain . on a line by itself" ;

: validate-message ( msg -- msg' )
    "." over member?
    [ message-contains-dot ] when ;

: send-body ( body -- )
    string-lines
    validate-message
    [ write crlf ] each
    "." command ;

: quit ( -- )
    "QUIT" command ;

LOG: smtp-response DEBUG

ERROR: smtp-error message ;
ERROR: smtp-server-busy < smtp-error ;
ERROR: smtp-syntax-error < smtp-error ;
ERROR: smtp-command-not-implemented < smtp-error ;
ERROR: smtp-bad-authentication < smtp-error ;
ERROR: smtp-mailbox-unavailable < smtp-error ;
ERROR: smtp-user-not-local < smtp-error ;
ERROR: smtp-exceeded-storage-allocation < smtp-error ;
ERROR: smtp-bad-mailbox-name < smtp-error ;
ERROR: smtp-transaction-failed < smtp-error ;

: check-response ( response -- )
    dup smtp-response
    {
        { [ dup "bye" head? ] [ drop ] }
        { [ dup "220" head? ] [ drop ] }
        { [ dup "235" swap subseq? ] [ drop ] }
        { [ dup "250" head? ] [ drop ] }
        { [ dup "221" head? ] [ drop ] }
        { [ dup "354" head? ] [ drop ] }
        { [ dup "4" head? ] [ smtp-server-busy ] }
        { [ dup "500" head? ] [ smtp-syntax-error ] }
        { [ dup "501" head? ] [ smtp-command-not-implemented ] }
        { [ dup "50" head? ] [ smtp-syntax-error ] }
        { [ dup "53" head? ] [ smtp-bad-authentication ] }
        { [ dup "550" head? ] [ smtp-mailbox-unavailable ] }
        { [ dup "551" head? ] [ smtp-user-not-local ] }
        { [ dup "552" head? ] [ smtp-exceeded-storage-allocation ] }
        { [ dup "553" head? ] [ smtp-bad-mailbox-name ] }
        { [ dup "554" head? ] [ smtp-transaction-failed ] }
        [ smtp-error ]
    } cond ;

: multiline? ( response -- boolean )
    ?fourth CHAR: - = ;

: process-multiline ( multiline -- response )
    >r readln r> 2dup " " append head? [
        drop dup smtp-response
    ] [
        swap check-response process-multiline
    ] if ;

: receive-response ( -- response )
    readln
    dup multiline? [ 3 head process-multiline ] when ;

: get-ok ( -- ) receive-response check-response ;

ERROR: invalid-header-string string ;

: validate-header ( string -- string' )
    dup "\r\n" intersect empty?
    [ invalid-header-string ] unless ;

: write-header ( key value -- )
    [ validate-header write ]
    [ ": " write validate-header write ] bi* crlf ;

: write-headers ( assoc -- )
    [ write-header ] assoc-each ;

: message-id ( -- string )
    [
        "<" %
        64 random-bits #
        "-" %
        millis #
        "@" %
        smtp-domain get [ host-name ] unless* %
        ">" %
    ] "" make ;

: extract-email ( recepient -- email )
    #! This could be much smarter.
    " " last-split1 swap or "<" ?head drop ">" ?tail drop ;

: email>headers ( email -- hashtable )
    [
        {
            [ from>> "From" set ]
            [ to>> ", " join "To" set ]
            [ cc>> ", " join [ "Cc" set ] unless-empty ]
            [ subject>> "Subject" set ]
        } cleave
        now timestamp>rfc822 "Date" set
        message-id "Message-Id" set
    ] { } make-assoc ;

: (send-email) ( headers email -- )
    [
        helo get-ok
        dup from>> extract-email mail-from get-ok
        dup to>> [ extract-email rcpt-to get-ok ] each
        dup cc>> [ extract-email rcpt-to get-ok ] each
        dup bcc>> [ extract-email rcpt-to get-ok ] each
        data get-ok
        swap write-headers
        crlf
        body>> send-body get-ok
        quit get-ok
    ] with-smtp-connection ;

: send-email ( email -- )
    [ email>headers ] keep (send-email) ;

! Dirk's old AUTH CRAM-MD5 code. I don't know anything about
! CRAM MD5, and the old code didn't work properly either, so here
! it is in case anyone wants to fix it later.
!
! check-response used to have this clause:
! { [ dup "334" head? ] [ " " split 1 swap nth base64> challenge set ] }
!
! and the rest of the code was as follows:
! : (cram-md5-auth) ( -- response )
!     swap challenge get 
!     string>md5-hmac hex-string 
!     " " prepend append 
!     >base64 ;
! 
! : cram-md5-auth ( key login  -- )
!     "AUTH CRAM-MD5\r\n" get-ok 
!     (cram-md5-auth) "\r\n" append get-ok ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!