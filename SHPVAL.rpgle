     H DFTACTGRP(*NO) ACTGRP(*CALLER)
     FSHPLOAD   UF   E           K DISK
     FSHPORDL1  IF   E           K DISK
     FSHPORDD   IF   E           K DISK
     FSHPITEM   IF   E           K DISK
     FSHPMTR    IF   E           K DISK
     D pLd             S              5P 0
     D pSt             S              8A
     D pMsg            S             50A
     D pTrk            S              6A
     D pTot            S              9P 0
     D pMax            S              7P 0
     D wT              S             11P 2
     D wL              S             11P 2
     D xH              S             10A
     D xI              S             15A
     C     *ENTRY        PLIST
     C                   PARM                    pLd
     C                   PARM                    pSt
     C                   PARM                    pMsg
     C                   PARM                    pTrk
     C                   PARM                    pTot
     C                   PARM                    pMax
     C                   SETOFF                                       818290
     C                   MOVE      *BLANKS       pSt
     C                   MOVE      *BLANKS       pMsg
     C                   MOVE      *BLANKS       pTrk
     C                   Z-ADD     0             pTot
     C                   Z-ADD     0             pMax
     C                   Z-ADD     0             wT
     C     pLd           CHAIN     SHPLOAD                            90
     C     *IN90         IFEQ      *ON
     C                   MOVEL(P)  'ERROR'       pSt
     C                   EVAL      pMsg = 'LOAD ' + %CHAR(pLd) + ' NOT FOUND'
     C                   SETON                                        LR
     C                   RETURN
     C                   ENDIF
     C                   MOVEL     LDTRUK        pTrk
     C                   Z-ADD     LDMAXW        pMax
     C     pLd           SETLL     SHPORDL1
     C     pLd           READE     SHPORDL1                               91
     C     *IN91         DOWEQ     *OFF
     C     OHORD         SETLL     SHPORDD
     C     OHORD         READE     SHPORDD                                92
     C     *IN92         DOWEQ     *OFF
     C                   CALL      'SHPWGT'
     C                   PARM                    ODITEM
     C                   PARM                    ODQTY
     C                   PARM                    wL
     C     wL            IFLT      0
     C                   SETON                                        81
     C                   MOVEL(P)  ODITEM        xI
     C                   ELSE
     C                   ADD       wL            wT
     C                   ENDIF
     C     ODITEM        CHAIN     SHPITEM                            93
     C     *IN93         IFEQ      *OFF
     C     ITHEAT        CHAIN     SHPMTR                             94
     C     *IN94         IFEQ      *ON
     C     MTSCAN        ORNE      'Y'
     C                   SETON                                        82
     C                   MOVEL(P)  ITHEAT        xH
     C                   ENDIF
     C                   ENDIF
     C     OHORD         READE     SHPORDD                                92
     C                   ENDDO
     C     pLd           READE     SHPORDL1                               91
     C                   ENDDO
     C                   EVAL(H)   pTot = wT
     C                   SELECT
     C     *IN81         WHENEQ    *ON
     C                   MOVEL(P)  'HELD'        pSt
     C                   EVAL      pMsg = 'ITEM ' + %TRIM(xI) +
     C                                    ' NOT IN ITEM MASTER'
     C     *IN82         WHENEQ    *ON
     C                   MOVEL(P)  'HELD'        pSt
     C                   EVAL      pMsg = 'NO MTR ON FILE FOR HEAT ' +
     C                                    %TRIM(xH)
     C     pTot          WHENGT    LDMAXW
     C                   MOVEL(P)  'HELD'        pSt
     C                   EVAL      pMsg = 'LOAD ' + %CHAR(pLd) +
     C                                    ' HELD - EXCEEDS MAX WEIGHT'
     C                   OTHER
     C                   MOVEL(P)  'RELEASED'    pSt
     C                   EVAL      pMsg = 'LOAD ' + %CHAR(pLd) +
     C                                    ' RELEASED - BOL SENT TO DOCK1'
     C                   ENDSL
     C                   Z-ADD     pTot          LDTOTW
     C                   MOVEL(P)  pSt           LDSTAT
     C                   MOVEL(P)  pMsg          LDMSG
     C                   UPDATE    SHPLOADR
     C                   SETON                                        LR
     C                   RETURN
