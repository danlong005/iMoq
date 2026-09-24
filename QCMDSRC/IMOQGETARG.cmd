/* IMOQGETARG - iMoq: capture an argument into a CL variable        */
             CMD        PROMPT('iMoq - Get argument')
             PARM       KWD(OBJ) TYPE(*NAME) LEN(10) MIN(1) +
                          PROMPT('Mock')
             PARM       KWD(PARM) TYPE(*INT2) RANGE(1 64) MIN(1) +
                          PROMPT('Parameter number')
             PARM       KWD(RTNVAL) TYPE(*CHAR) LEN(256) RTNVAL(*YES) +
                          MIN(1) PROMPT('CL var for value (256)')
             PARM       KWD(PROC) TYPE(*CHAR) LEN(256) DFT(*PGM) +
                          VARY(*YES *INT2) CASE(*MIXED) +
                          PROMPT('Procedure (service programs)')
             PARM       KWD(CALL) TYPE(*INT4) DFT(*LAST) +
                          RANGE(1 9999999) SPCVAL((*LAST -1) +
                          (*FIRST 1)) PROMPT('Call number')
             PARM       KWD(FIELD) TYPE(*CHAR) LEN(40) DFT(' ') +
                          PROMPT('Field (IMOQFIELD), or NAME(i)')
