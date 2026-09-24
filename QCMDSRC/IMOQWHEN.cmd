/* IMOQWHEN - iMoq: stub behavior (when ... then return/throw)      */
             CMD        PROMPT('iMoq - When called')
             PARM       KWD(OBJ) TYPE(*NAME) LEN(10) MIN(1) +
                          PROMPT('Mock')
             PARM       KWD(PROC) TYPE(*CHAR) LEN(256) DFT(*PGM) +
                          VARY(*YES *INT2) CASE(*MIXED) +
                          PROMPT('Procedure (service programs)')
             PARM       KWD(ARGS) TYPE(ADEF) MAX(64) +
                          PROMPT('Argument matchers')
             PARM       KWD(RETURN) TYPE(*CHAR) LEN(256) MAX(32) +
                          VARY(*YES *INT2) CASE(*MIXED) +
                          PROMPT('Return value(s)')
             PARM       KWD(SETPARM) TYPE(SDEF) MAX(64) +
                          PROMPT('Set parameter values')
             PARM       KWD(THROW) TYPE(TDEF) +
                          PROMPT('Send escape message')
             PARM       KWD(TIMES) TYPE(*INT4) DFT(*ALWAYS) +
                          RANGE(1 9999999) SPCVAL((*ALWAYS -1)) +
                          PROMPT('Number of calls to answer')
 ADEF:       ELEM       TYPE(*INT2) RANGE(1 64) MIN(1) +
                          PROMPT('Parameter number')
             ELEM       TYPE(*CHAR) LEN(10) RSTD(*YES) DFT(*EQ) +
                          VALUES(*ANY *EQ *NE *GT *GE *LT *LE *LIKE +
                          *BLANK *OMIT *NOTPASSED) PROMPT('Matcher')
             ELEM       TYPE(*CHAR) LEN(256) VARY(*YES *INT2) +
                          CASE(*MIXED) DFT(' ') PROMPT('Value')
             ELEM       TYPE(*CHAR) LEN(40) DFT(' ') +
                          PROMPT('Field (IMOQFIELD), or NAME(i)')
 SDEF:       ELEM       TYPE(*INT2) RANGE(0 64) MIN(1) +
                          PROMPT('Parameter (0 = return value)')
             ELEM       TYPE(*CHAR) LEN(256) VARY(*YES *INT2) +
                          CASE(*MIXED) MIN(1) PROMPT('Value')
             ELEM       TYPE(*CHAR) LEN(40) DFT(' ') +
                          PROMPT('Field (IMOQFIELD), or NAME(i)')
 TDEF:       ELEM       TYPE(*CHAR) LEN(7) DFT(*NONE) +
                          SPCVAL((*NONE) (*MOCK)) +
                          PROMPT('Message identifier')
             ELEM       TYPE(*NAME) LEN(10) DFT(*MOCK) +
                          SPCVAL((*MOCK)) PROMPT('Message file')
             ELEM       TYPE(*NAME) LEN(10) DFT(*LIBL) +
                          SPCVAL((*LIBL) (*CURLIB)) +
                          PROMPT('Message file library')
             ELEM       TYPE(*CHAR) LEN(256) VARY(*YES *INT2) +
                          CASE(*MIXED) DFT(' ') PROMPT('Message data')
