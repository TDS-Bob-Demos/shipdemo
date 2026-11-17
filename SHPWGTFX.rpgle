     H DFTACTGRP(*NO) ACTGRP(*CALLER)
     FSHPITEM   IF   E           K DISK
     D pItm            S             15A
     D pQty            S              9P 2
     D pWgt            S             11P 2
     C     *ENTRY        PLIST
     C                   PARM                    pItm
     C                   PARM                    pQty
     C                   PARM                    pWgt
     C                   Z-ADD     0             pWgt
     C     pItm          CHAIN     SHPITEM                            90
     C     *IN90         IFEQ      *ON
     C                   Z-SUB     1             pWgt
     C                   SETON                                        LR
     C                   RETURN
     C                   ENDIF
     C                   SELECT
     C     ITUOM         WHENEQ    'FT'
     C     pQty          MULT      ITWGTU        pWgt
     C     ITUOM         WHENEQ    'LB'
     C                   Z-ADD     pQty          pWgt
     C     ITUOM         WHENEQ    'SHT'
     C     pQty          MULT      ITWGTU        pWgt
     C     ITUOM         WHENEQ    'CWT'
     C     pQty          MULT      ITWGTU        pWgt
     C                   OTHER
     C     pQty          MULT      ITWGTU        pWgt
     C                   MULT      100           pWgt
     C                   ENDSL
     C                   SETON                                        LR
     C                   RETURN
