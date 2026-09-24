/* IMOQFIELD - iMoq: declare subfields of a DS or array parameter    */
             CMD        PROMPT('iMoq - Declare subfields')
             PARM       KWD(OBJ) TYPE(*NAME) LEN(10) MIN(1) +
                          PROMPT('Mock')
             PARM       KWD(PROC) TYPE(*CHAR) LEN(256) DFT(*PGM) +
                          VARY(*YES *INT2) CASE(*MIXED) +
                          PROMPT('Procedure (service programs)')
             PARM       KWD(PARM) TYPE(*INT2) RANGE(0 64) MIN(1) +
                          PROMPT('Parameter (0 = return value)')
             PARM       KWD(FIELDS) TYPE(FDEF) MIN(1) MAX(64) +
                          PROMPT('Fields')
 FDEF:       ELEM       TYPE(*NAME) LEN(30) MIN(1) +
                          PROMPT('Field name')
             ELEM       TYPE(*INT4) DFT(*NEXT) RANGE(1 16000000) +
                          SPCVAL((*NEXT 0)) PROMPT('Position')
             ELEM       TYPE(*CHAR) LEN(10) RSTD(*YES) DFT(*CHAR) +
                          VALUES(*CHAR *VARCHAR *PACKED *ZONED *INT +
                          *UNS *FLOAT *IND *DATE *TIME *TIMESTAMP +
                          *PTR) PROMPT('Type')
             ELEM       TYPE(*INT4) DFT(0) PROMPT('Length or digits')
             ELEM       TYPE(*INT4) DFT(0) PROMPT('Decimal positions')
             ELEM       TYPE(*INT4) DFT(0) RANGE(0 999) +
                          PROMPT('Array elements (0 = none)')
