/* IMOQORDER - iMoq: verify a call came after the previous one      */
             CMD        PROMPT('iMoq - Verify call order')
             PARM       KWD(OBJ) TYPE(*NAME) LEN(10) MIN(1) +
                          PROMPT('Mock')
             PARM       KWD(PROC) TYPE(*CHAR) LEN(256) DFT(*PGM) +
                          VARY(*YES *INT2) CASE(*MIXED) +
                          PROMPT('Procedure (service programs)')
             PARM       KWD(ARGS) TYPE(ADEF) MAX(64) +
                          PROMPT('Argument matchers')
             PARM       KWD(AFTER) TYPE(*CHAR) LEN(6) RSTD(*YES) +
                          DFT(*PREV) VALUES(*PREV *START) +
                          PROMPT('After the previous IMOQORDER')
 ADEF:       ELEM       TYPE(*INT2) RANGE(1 64) MIN(1) +
                          PROMPT('Parameter number')
             ELEM       TYPE(*CHAR) LEN(10) RSTD(*YES) DFT(*EQ) +
                          VALUES(*ANY *EQ *NE *GT *GE *LT *LE *LIKE +
                          *BLANK *OMIT *NOTPASSED) PROMPT('Matcher')
             ELEM       TYPE(*CHAR) LEN(256) VARY(*YES *INT2) +
                          CASE(*MIXED) DFT(' ') PROMPT('Value')
             ELEM       TYPE(*CHAR) LEN(40) DFT(' ') +
                          PROMPT('Field (IMOQFIELD), or NAME(i)')
