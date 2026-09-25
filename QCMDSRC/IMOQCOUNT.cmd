/* IMOQCOUNT - iMoq: number of recorded calls                       */
             CMD        PROMPT('iMoq - Count calls')
             PARM       KWD(OBJ) TYPE(*NAME) LEN(10) MIN(1) +
                          PROMPT('Mock')
             PARM       KWD(RTNVAL) TYPE(*DEC) LEN(10 0) RTNVAL(*YES) +
                          MIN(1) PROMPT('CL var for count (10 0)')
             PARM       KWD(PROC) TYPE(*CHAR) LEN(256) DFT(*PGM) +
                          VARY(*YES *INT2) CASE(*MIXED) +
                          PROMPT('Procedure (service programs)')
             PARM       KWD(ARGS) TYPE(ADEF) MAX(64) +
                          PROMPT('Argument matchers')
 ADEF:       ELEM       TYPE(*INT2) RANGE(1 64) MIN(1) +
                          PROMPT('Parameter number')
             ELEM       TYPE(*CHAR) LEN(10) RSTD(*YES) DFT(*EQ) +
                          VALUES(*ANY *EQ *NE *GT *GE *LT *LE *LIKE +
                          *BLANK *OMIT *NOTPASSED *IN *BETWEEN) +
                          PROMPT('Matcher')
             ELEM       TYPE(*CHAR) LEN(256) VARY(*YES *INT2) +
                          CASE(*MIXED) DFT(' ') PROMPT('Value')
             ELEM       TYPE(*CHAR) LEN(40) DFT(' ') +
                          PROMPT('Field (IMOQFIELD), or NAME(i)')
