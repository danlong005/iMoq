**free
// ------------------------------------------------------------------
// EXANSSRV - Answer procedures for EXANSWER_T's command form
//
// IMOQWHEN ... ANSWER(EXANSSRV EURANSWER) calls EURANSWER, an export
// of this service program, to answer each call. An answer procedure
// takes no parameters: it reads the call with imoq_answerArg... and
// sets outputs with imoq_answerSetParm and imoq_answerReturns.
// Built by the driver EXANSWER.
// ------------------------------------------------------------------
ctl-opt nomain;

/copy QRPGLESRC,IMOQ_H

// EX_CONVERT(amount : currency): euros at 1.10 dollars each
dcl-proc eurAnswer export;
  imoq_answerReturns(imoq_answerArgNum(1) * 1.10);
end-proc;
