**free
// ------------------------------------------------------------------
// IMOQENG - iMoq engine: mock state (QTEMP tables), stub runtime,
//           stubbing, verification and the public test API.
// Module of service program IMOQENG (ACTGRP iMoq).
// ------------------------------------------------------------------
ctl-opt nomain option(*srcstmt:*nodebugio) decprec(63);

/copy QTEMP/IMOQINC,IMOQENG_H

exec sql set option commit = *none, naming = *sql,
  closqlcsr = *endactgrp, datfmt = *iso, timfmt = *iso;

dcl-c LOWER 'abcdefghijklmnopqrstuvwxyz';
dcl-c UPPER 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
dcl-c MAXCALLS 5000;
dcl-c MAXSTUBS 500;
dcl-c MAXFIELDS 256;         // declared subfields per procedure
dcl-c MAXFVALS 2000;         // subfield values recorded per call
dcl-c NAMECHARS 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_#$@';
dcl-c DIGITS '0123456789';

dcl-ds psds psds qualified;
  excType char(3) pos(40);
  excNum char(4) pos(43);
  lib char(10) pos(81);
end-ds;

// Target of a stub or verification: the mock, the procedure and
// its declared layout
dcl-ds target_t qualified template;
  obj char(10);
  objType char(7);
  behavior char(7);
  proc varchar(4096);
  kind char(4);
  lbl varchar(4200);
  nDefs int(10);
  defs likeds(imoq_def_t) dim(64);
  rtnDef likeds(imoq_def_t);
  hasRtn ind;
end-ds;

// Subfields declared with IMOQFIELD for one procedure
dcl-ds fields_t qualified template;
  n int(10);
  parm int(10) dim(MAXFIELDS);
  name varchar(30) dim(MAXFIELDS);
  pos int(10) dim(MAXFIELDS);
  dim int(10) dim(MAXFIELDS);
  def likeds(imoq_def_t) dim(MAXFIELDS);
end-ds;

dcl-s gTablesOk ind;
dcl-s gLastErr varchar(512);
dcl-s gLastStub int(10);
// Call the last successful order check matched (IMOQORDER); 0 = none
dcl-s gOrderPos int(10);

dcl-ds apiErr_t qualified template;
  bytesProv int(10);
  bytesAvail int(10);
  msgId char(7);
  rsv char(1);
end-ds;

dcl-pr qcmdexc extpgm('QCMDEXC');
  cmd char(3000) const options(*varsize);
  len packed(15:5) const;
end-pr;

dcl-pr qmhsndpm extpgm('QMHSNDPM');
  msgId char(7) const;
  msgf char(20) const;
  msgDta char(512) const;
  msgDtaLen int(10) const;
  msgType char(10) const;
  callStk char(10) const;
  callStkCtr int(10) const;
  msgKey char(4);
  errCode likeds(apiErr_t);
end-pr;

dcl-pr qusrobjd extpgm('QUSROBJD');
  rcv char(90);
  rcvLen int(10) const;
  format char(8) const;
  objQual char(20) const;
  objType char(10) const;
  errCode likeds(apiErr_t);
end-pr;

// ==================================================================
// Error helpers
// ==================================================================
dcl-proc clearErr;
  dcl-pi *n;
    err likeds(imoq_err_t);
  end-pi;
  err.msgId = ' ';
  err.msgfLib = psds.lib;
  err.text = ' ';
end-proc;

dcl-proc setErr;
  dcl-pi *n;
    err likeds(imoq_err_t);
    msgId char(7) const;
    text varchar(512) const;
  end-pi;
  err.msgId = msgId;
  err.msgfLib = psds.lib;
  err.text = text;
  gLastErr = text;
end-proc;

dcl-proc sqlFailText;
  dcl-pi *n varchar(512);
    what varchar(100) const;
  end-pi;
  dcl-s code int(10);
  dcl-s state char(5);
  dcl-s t varchar(400);
  code = sqlcode;
  state = sqlstate;
  exec sql get diagnostics condition 1 :t = message_text;
  return what + ' failed (SQLCODE ' + %char(code) + ', SQLSTATE '
       + state + '): ' + t;
end-proc;

// ==================================================================
// State tables in QTEMP
// ==================================================================
dcl-proc runDdl;
  dcl-pi *n;
    stmt varchar(2000) const;
  end-pi;
  dcl-s s varchar(2000);
  s = stmt;
  exec sql execute immediate :s;
end-proc;

dcl-proc ensureTables;
  if gTablesOk;
    return;
  endif;
  runDdl('CREATE TABLE QTEMP.IMOQ_OBJ (OBJ CHAR(10) NOT NULL, '
       + 'OBJTYPE CHAR(7) NOT NULL, BEHAVIOR CHAR(7) NOT NULL, '
       + 'REALLIB CHAR(10) NOT NULL, BUILT CHAR(1) NOT NULL, '
       + 'EXPMODE CHAR(4) NOT NULL, SIGNATURE VARCHAR(16) NOT NULL, '
       + 'MOCKLIB CHAR(10) NOT NULL)');
  runDdl('CREATE TABLE QTEMP.IMOQ_PROC (OBJ CHAR(10) NOT NULL, '
       + 'PROC VARCHAR(4096) NOT NULL, SEQ INT NOT NULL, '
       + 'KIND CHAR(4) NOT NULL, DATASIZE INT NOT NULL, '
       + 'DECLARED CHAR(1) NOT NULL)');
  runDdl('CREATE TABLE QTEMP.IMOQ_SIG (OBJ CHAR(10) NOT NULL, '
       + 'PROC VARCHAR(4096) NOT NULL, PARMNO SMALLINT NOT NULL, '
       + 'TYPE CHAR(10) NOT NULL, LEN INT NOT NULL, DEC INT NOT NULL, '
       + 'PASSING CHAR(6) NOT NULL)');
  runDdl('CREATE TABLE QTEMP.IMOQ_STUB (STUBID INT NOT NULL, '
       + 'OBJ CHAR(10) NOT NULL, PROC VARCHAR(4096) NOT NULL, '
       + 'TIMESLEFT INT NOT NULL, USED INT NOT NULL, '
       + 'THRID CHAR(7) NOT NULL, THRMSGF CHAR(10) NOT NULL, '
       + 'THRLIB CHAR(10) NOT NULL, THRDTA VARCHAR(512) NOT NULL, '
       + 'RTNCNT INT NOT NULL)');
  runDdl('CREATE TABLE QTEMP.IMOQ_SARG (STUBID INT NOT NULL, '
       + 'PARMNO SMALLINT NOT NULL, MATCHER CHAR(10) NOT NULL, '
       + 'VAL VARCHAR(1024) NOT NULL, FIELD VARCHAR(40) NOT NULL)');
  runDdl('CREATE TABLE QTEMP.IMOQ_SRTN (STUBID INT NOT NULL, '
       + 'SEQ INT NOT NULL, VAL VARCHAR(1024) NOT NULL)');
  runDdl('CREATE TABLE QTEMP.IMOQ_SSET (STUBID INT NOT NULL, '
       + 'PARMNO SMALLINT NOT NULL, VAL VARCHAR(1024) NOT NULL, '
       + 'FIELD VARCHAR(40) NOT NULL)');
  runDdl('CREATE TABLE QTEMP.IMOQ_CALL (CALLID INT NOT NULL, '
       + 'OBJ CHAR(10) NOT NULL, PROC VARCHAR(4096) NOT NULL, '
       + 'PARMCNT INT NOT NULL, STUBID INT NOT NULL, '
       + 'VERIFIED CHAR(1) NOT NULL, TS TIMESTAMP NOT NULL)');
  runDdl('CREATE TABLE QTEMP.IMOQ_CARG (CALLID INT NOT NULL, '
       + 'PARMNO SMALLINT NOT NULL, STATE CHAR(1) NOT NULL, '
       + 'VAL VARCHAR(1024) NOT NULL, FIELD VARCHAR(40) NOT NULL)');
  runDdl('CREATE TABLE QTEMP.IMOQ_FLD (OBJ CHAR(10) NOT NULL, '
       + 'PROC VARCHAR(4096) NOT NULL, PARMNO SMALLINT NOT NULL, '
       + 'SEQ INT NOT NULL, NAME VARCHAR(30) NOT NULL, POS INT NOT NULL, '
       + 'TYPE CHAR(10) NOT NULL, LEN INT NOT NULL, DEC INT NOT NULL, '
       + 'DIM INT NOT NULL)');
  gTablesOk = *on;
end-proc;

dcl-proc dropTables;
  runDdl('DROP TABLE QTEMP.IMOQ_OBJ');
  runDdl('DROP TABLE QTEMP.IMOQ_PROC');
  runDdl('DROP TABLE QTEMP.IMOQ_SIG');
  runDdl('DROP TABLE QTEMP.IMOQ_STUB');
  runDdl('DROP TABLE QTEMP.IMOQ_SARG');
  runDdl('DROP TABLE QTEMP.IMOQ_SRTN');
  runDdl('DROP TABLE QTEMP.IMOQ_SSET');
  runDdl('DROP TABLE QTEMP.IMOQ_CALL');
  runDdl('DROP TABLE QTEMP.IMOQ_CARG');
  runDdl('DROP TABLE QTEMP.IMOQ_FLD');
  runDdl('DROP ALIAS QTEMP.IMOQ_SRCW');
  runDdl('DROP ALIAS QTEMP.IMOQ_BNDR');
  gTablesOk = *off;
  gOrderPos = 0;
end-proc;

// ------------------------------------------------------------------
// Delete stubs (and their children) for obj/proc ('' = all procs)
// ------------------------------------------------------------------
dcl-proc deleteStubs;
  dcl-pi *n;
    obj char(10) const;
  end-pi;
  exec sql delete from qtemp.imoq_sarg where stubid in
    (select stubid from qtemp.imoq_stub where obj = :obj or :obj = '*ALL');
  exec sql delete from qtemp.imoq_srtn where stubid in
    (select stubid from qtemp.imoq_stub where obj = :obj or :obj = '*ALL');
  exec sql delete from qtemp.imoq_sset where stubid in
    (select stubid from qtemp.imoq_stub where obj = :obj or :obj = '*ALL');
  exec sql delete from qtemp.imoq_stub where obj = :obj or :obj = '*ALL';
end-proc;

dcl-proc deleteCalls;
  dcl-pi *n;
    obj char(10) const;
  end-pi;
  exec sql delete from qtemp.imoq_carg where callid in
    (select callid from qtemp.imoq_call where obj = :obj or :obj = '*ALL');
  exec sql delete from qtemp.imoq_call where obj = :obj or :obj = '*ALL';
  // call numbers can be handed out again, so start any order over
  gOrderPos = 0;
end-proc;

dcl-proc forgetObj;
  dcl-pi *n;
    obj char(10) const;
  end-pi;
  deleteStubs(obj);
  deleteCalls(obj);
  exec sql delete from qtemp.imoq_sig where obj = :obj or :obj = '*ALL';
  exec sql delete from qtemp.imoq_fld where obj = :obj or :obj = '*ALL';
  exec sql delete from qtemp.imoq_proc where obj = :obj or :obj = '*ALL';
  exec sql delete from qtemp.imoq_obj where obj = :obj or :obj = '*ALL';
end-proc;

// ==================================================================
// Command parameter (list) helpers
// ==================================================================
dcl-proc lstCount;
  dcl-pi *n int(10);
    p pointer value;
  end-pi;
  dcl-s n int(5) based(p);
  if p = *null;
    return 0;
  endif;
  return n;
end-proc;

// entry i (1-based) of a list of mixed lists
dcl-proc lstEntry;
  dcl-pi *n pointer;
    p pointer value;
    i int(10) value;
  end-pi;
  dcl-s q pointer;
  dcl-s off int(5) based(q);
  q = p + 2 * i;
  return p + off;
end-proc;

// value with a 2-byte length prefix (VARY(*YES))
dcl-proc varyText;
  dcl-pi *n varchar(4096);
    p pointer value;
    maxLen int(10) value;
  end-pi;
  dcl-s n int(5) based(p);
  dcl-s q pointer;
  dcl-s c char(4096) based(q);
  dcl-s len int(10);
  len = n;
  if len <= 0;
    return '';
  endif;
  if len > maxLen;
    len = maxLen;
  endif;
  q = p + 2;
  return %subst(c : 1 : len);
end-proc;

dcl-proc charAt;
  dcl-pi *n varchar(256);
    p pointer value;
    len int(10) value;
  end-pi;
  dcl-s c char(256) based(p);
  return %subst(c : 1 : len);
end-proc;

dcl-proc int2At;
  dcl-pi *n int(10);
    p pointer value;
  end-pi;
  dcl-s n int(5) based(p);
  return n;
end-proc;

dcl-proc int4At;
  dcl-pi *n int(10);
    p pointer value;
  end-pi;
  dcl-s n int(10) based(p);
  return n;
end-proc;

// ------------------------------------------------------------------
// Read one layout entry: TYPE(*CHAR 10) LEN(*INT4) DEC(*INT4)
//                        [PASSING(*CHAR 6)]
// ------------------------------------------------------------------
dcl-proc readDef;
  dcl-pi *n;
    e pointer value;
    def likeds(imoq_def_t);
    withPassing ind const;
  end-pi;
  clear def;
  def.type = charAt(e + 2 : 10);
  def.len = int4At(e + 12);
  def.dec = int4At(e + 16);
  def.passing = '*REF';
  if withPassing;
    def.passing = charAt(e + 20 : 6);
    // (*CHAR 10 *CONST): passing given in the decimal positions element
    select;
    when def.dec = -1;
      def.passing = '*CONST';
      def.dec = 0;
    when def.dec = -2;
      def.passing = '*VALUE';
      def.dec = 0;
    when def.dec = -3;
      def.passing = '*REF';
      def.dec = 0;
    endsl;
  endif;
end-proc;

// ==================================================================
// Mock metadata lookups
// ==================================================================
dcl-proc objInfo;
  dcl-pi *n ind;
    obj char(10) const;
    objType char(7);
    behavior char(7);
    built char(1);
    realLib char(10);
  end-pi;
  exec sql select objtype, behavior, built, reallib
             into :objType, :behavior, :built, :realLib
             from qtemp.imoq_obj where obj = :obj
             fetch first 1 row only;
  return sqlcode = 0;
end-proc;

dcl-proc label;
  dcl-pi *n varchar(4200);
    obj char(10) const;
    proc varchar(4096) const;
  end-pi;
  if proc = '*PGM';
    return %trim(obj);
  endif;
  return %trim(obj) + '.' + proc;
end-proc;

// Resolve the PROC parameter against the mock's exports
dcl-proc resolveProc;
  dcl-pi *n ind;
    obj char(10) const;
    objType char(7) const;
    procIn varchar(4096) const;
    procOut varchar(4096);
    kind char(4);
    declared char(1);
    err likeds(imoq_err_t);
  end-pi;
  dcl-s n int(10);
  dcl-s p varchar(4096);

  p = %trim(procIn);
  if objType = '*PGM';
    if p <> '' and p <> '*PGM';
      setErr(err : 'IMQ0012' : 'Mock ' + %trim(obj) + ' is a program; '
           + 'omit the PROC parameter (PROC(*PGM))');
      return *off;
    endif;
    procOut = '*PGM';
    kind = 'PROC';
    declared = 'Y';
    return *on;
  endif;

  if p = '' or p = '*PGM';
    setErr(err : 'IMQ0012' : 'PROC is required for service program mock '
         + %trim(obj));
    return *off;
  endif;

  exec sql select proc, kind, declared into :procOut, :kind, :declared
             from qtemp.imoq_proc where obj = :obj and proc = :p
             fetch first 1 row only;
  if sqlcode = 0;
    return *on;
  endif;

  exec sql select count(*) into :n from qtemp.imoq_proc
             where obj = :obj and upper(proc) = upper(:p);
  if n = 1;
    exec sql select proc, kind, declared into :procOut, :kind, :declared
               from qtemp.imoq_proc
               where obj = :obj and upper(proc) = upper(:p)
               fetch first 1 row only;
    return *on;
  endif;

  setErr(err : 'IMQ0012' : %trim(obj) + ' does not export ' + p);
  return *off;
end-proc;

// ------------------------------------------------------------------
// addExport - for a SRCFILE(*NONE) mock, IMOQPROC defines the export
// ------------------------------------------------------------------
dcl-proc addExport;
  dcl-pi *n ind;
    obj char(10) const;
    procIn varchar(4096) const;
    err likeds(imoq_err_t);
  end-pi;
  dcl-s mode char(4);
  dcl-s p varchar(4096);
  dcl-s n int(10);
  dcl-s seq int(10);

  exec sql select expmode into :mode from qtemp.imoq_obj
            where obj = :obj;
  if sqlcode <> 0 or mode <> 'PROC';
    return *on;
  endif;

  p = %trim(procIn);
  if p = '' or p = '*PGM';
    setErr(err : 'IMQ0012' : 'PROC is required for service program mock '
         + %trim(obj));
    return *off;
  endif;
  if %scan('''' : p) > 0 or %scan('"' : p) > 0 or %len(p) > 180;
    setErr(err : 'IMQ0014' : 'PROC must be an export name of at most 180 '
         + 'characters without quotes');
    return *off;
  endif;

  exec sql select count(*) into :n from qtemp.imoq_proc
            where obj = :obj and proc = :p;
  if n = 0;
    exec sql select coalesce(max(seq), 0) + 1 into :seq
               from qtemp.imoq_proc where obj = :obj;
    exec sql insert into qtemp.imoq_proc
      values(:obj, :p, :seq, 'PROC', 0, 'N');
  endif;
  return *on;
end-proc;

dcl-proc loadSig;
  dcl-pi *n;
    obj char(10) const;
    proc varchar(4096) const;
    defs likeds(imoq_def_t) dim(64);
    nDefs int(10);
    rtnDef likeds(imoq_def_t);
    hasRtn ind;
  end-pi;
  dcl-s parmNo int(5);
  dcl-s type char(10);
  dcl-s len int(10);
  dcl-s dec int(10);
  dcl-s passing char(6);

  clear defs;
  clear rtnDef;
  nDefs = 0;
  hasRtn = *off;

  exec sql declare cSig cursor for
    select parmno, type, len, dec, passing from qtemp.imoq_sig
     where obj = :obj and proc = :proc order by parmno;
  exec sql open cSig;
  dow sqlcode = 0;
    exec sql fetch next from cSig
      into :parmNo, :type, :len, :dec, :passing;
    if sqlcode <> 0;
      leave;
    endif;
    if parmNo = 0;
      hasRtn = *on;
      rtnDef.type = type;
      rtnDef.len = len;
      rtnDef.dec = dec;
      rtnDef.passing = passing;
    elseif parmNo <= IMOQ_MAXP;
      defs(parmNo).type = type;
      defs(parmNo).len = len;
      defs(parmNo).dec = dec;
      defs(parmNo).passing = passing;
      if parmNo > nDefs;
        nDefs = parmNo;
      endif;
    endif;
  enddo;
  exec sql close cSig;
end-proc;

dcl-proc insertSig;
  dcl-pi *n;
    obj char(10) const;
    proc varchar(4096) const;
    parmNo int(5) const;
    def likeds(imoq_def_t) const;
  end-pi;
  dcl-s type char(10);
  dcl-s len int(10);
  dcl-s dec int(10);
  dcl-s passing char(6);
  type = def.type;
  len = def.len;
  dec = def.dec;
  passing = def.passing;
  exec sql insert into qtemp.imoq_sig
    values(:obj, :proc, :parmNo, :type, :len, :dec, :passing);
end-proc;

// Validate that text can be stored in a value of this layout
dcl-proc canEncode;
  dcl-pi *n ind;
    def likeds(imoq_def_t) const;
    text varchar(1024) const;
    msg varchar(256);
  end-pi;
  dcl-s p pointer;
  dcl-s ok ind;
  p = %alloc(def.len + 16);
  ok = imoq_encode(p : def : text : msg);
  dealloc(n) p;
  return ok;
end-proc;

// ==================================================================
// Target resolution
// ==================================================================
dcl-proc openTarget;
  dcl-pi *n ind;
    obj char(10) const;
    procIn varchar(4096) const;
    tgt likeds(target_t);
    err likeds(imoq_err_t);
  end-pi;
  dcl-s built char(1);
  dcl-s realLib char(10);
  dcl-s declared char(1);

  clear tgt;
  tgt.obj = obj;
  if not objInfo(obj : tgt.objType : tgt.behavior : built : realLib);
    setErr(err : 'IMQ0011' : 'Mock ' + %trim(obj) + ' does not exist. '
         + 'Create it with IMOQPGM or IMOQSRVPGM first');
    return *off;
  endif;
  if not resolveProc(obj : tgt.objType : procIn : tgt.proc : tgt.kind
                     : declared : err);
    return *off;
  endif;
  tgt.lbl = label(obj : tgt.proc);
  loadSig(obj : tgt.proc : tgt.defs : tgt.nDefs : tgt.rtnDef
          : tgt.hasRtn);
  return *on;
end-proc;

// ==================================================================
// Subfield references: NAME, or NAME(i) for an array element
// ==================================================================
dcl-proc imoq_parseField export;
  dcl-pi *n ind;
    text varchar(64) const;
    field varchar(40);
    msg varchar(256);
  end-pi;
  dcl-s name varchar(64);
  dcl-s idx varchar(64);
  dcl-s q int(10);
  dcl-s i int(10);

  field = '';
  msg = '''' + %trim(text) + ''' is not a field name. Use NAME, or '
      + 'NAME(i) for an array element';
  name = %xlate(LOWER : UPPER : %trim(text));
  if name = '';
    msg = '';
    return *on;
  endif;
  q = %scan('(' : name);
  if q > 0;
    if %subst(name : %len(name) : 1) <> ')' or q < 2
       or q > %len(name) - 2;
      return *off;
    endif;
    idx = %trim(%subst(name : q + 1 : %len(name) - q - 1));
    name = %trim(%subst(name : 1 : q - 1));
    if idx = '' or %len(idx) > 3 or %check(DIGITS : idx) > 0;
      return *off;
    endif;
    i = %int(idx);
    if i < 1;
      msg = 'Array elements are numbered from 1';
      return *off;
    endif;
  endif;
  if %len(name) > 30 or %check(NAMECHARS : name) > 0;
    return *off;
  endif;
  field = name;
  if q > 0;
    field += '(' + %char(i) + ')';
  endif;
  msg = '';
  return *on;
end-proc;

// NAME(2) -> NAME and 2; NAME -> NAME and 0
dcl-proc splitField;
  dcl-pi *n;
    field varchar(40) const;
    name varchar(30);
    idx int(10);
  end-pi;
  dcl-s q int(10);
  q = %scan('(' : field);
  if q = 0;
    name = field;
    idx = 0;
    return;
  endif;
  name = %subst(field : 1 : q - 1);
  idx = %int(%subst(field : q + 1 : %len(field) - q - 1));
end-proc;

// 2, 2.QTY or 0.TOTAL, as written in commands
dcl-proc refText;
  dcl-pi *n varchar(48);
    parmNo int(10) const;
    field varchar(40) const;
  end-pi;
  if field = '';
    return %char(parmNo);
  endif;
  return %char(parmNo) + '.' + field;
end-proc;

// Layout and byte offset of a declared subfield (element)
dcl-proc findField;
  dcl-pi *n ind;
    obj char(10) const;
    proc varchar(4096) const;
    parmNo int(10) const;
    field varchar(40) const;
    def likeds(imoq_def_t);
    offset int(10);
    err likeds(imoq_err_t);
  end-pi;
  dcl-s name varchar(30);
  dcl-s idx int(10);
  dcl-s p5 int(5);
  dcl-s pos int(10);
  dcl-s type char(10);
  dcl-s len int(10);
  dcl-s dec int(10);
  dcl-s dim int(10);
  dcl-s what varchar(200);

  clear def;
  offset = 0;
  splitField(field : name : idx);
  p5 = parmNo;
  what = 'Field ' + name + ' of ' + label(obj : proc) + ' parameter '
       + %char(parmNo);
  exec sql select pos, type, len, dec, dim
             into :pos, :type, :len, :dec, :dim
             from qtemp.imoq_fld
            where obj = :obj and proc = :proc and parmno = :p5
              and name = :name;
  if sqlcode <> 0;
    setErr(err : 'IMQ0014' : what + ' is not declared. Declare it with '
         + 'IMOQFIELD');
    return *off;
  endif;
  def.type = type;
  def.len = len;
  def.dec = dec;
  def.passing = '*REF';
  if dim = 0 and idx > 0;
    setErr(err : 'IMQ0014' : what + ' is not an array; leave out (' +
           %char(idx) + ')');
    return *off;
  endif;
  if dim > 0 and idx = 0;
    setErr(err : 'IMQ0014' : what + ' is an array of ' + %char(dim)
         + '; name an element, such as ' + name + '(1)');
    return *off;
  endif;
  if idx > dim;
    setErr(err : 'IMQ0014' : what + ' has ' + %char(dim)
         + ' elements, not ' + %char(idx));
    return *off;
  endif;
  if idx = 0;
    idx = 1;
  endif;
  offset = pos - 1 + (idx - 1) * imoq_byteSize(def);
  return *on;
end-proc;

// ==================================================================
// Matchers: ARGS((ref matcher value) ...)
// ==================================================================

// Unpack the ARGS list of a command: parameter (int2), matcher (10),
// value (VARY 256), field (40)
dcl-proc unpackMatchers;
  dcl-pi *n ind;
    blob pointer value;
    m likeds(imoq_matcher_t) dim(64);
    nM int(10);
    err likeds(imoq_err_t);
  end-pi;
  dcl-s i int(10);
  dcl-s e pointer;
  dcl-s msg varchar(256);

  clear m;
  nM = lstCount(blob);
  if nM > IMOQ_MAXP;
    setErr(err : 'IMQ0014' : 'At most 64 argument matchers are allowed');
    return *off;
  endif;
  for i = 1 to nM;
    e = lstEntry(blob : i);
    m(i).parmNo = int2At(e + 2);
    m(i).matcher = charAt(e + 4 : 10);
    m(i).val = varyText(e + 14 : 256);
    if not imoq_parseField(charAt(e + 272 : 40) : m(i).field : msg);
      setErr(err : 'IMQ0014' : 'ARGS entry ' + %char(i) + ': ' + msg);
      return *off;
    endif;
  endfor;
  return *on;
end-proc;

// Validate one matcher against the target's layout
dcl-proc checkMatcher;
  dcl-pi *n ind;
    m likeds(imoq_matcher_t);
    what varchar(40) const;
    tgt likeds(target_t) const;
    err likeds(imoq_err_t);
  end-pi;
  dcl-s msg varchar(256);
  dcl-ds d likeds(imoq_def_t);
  dcl-s off int(10);
  dcl-s items varchar(1024) dim(64);
  dcl-s n int(10);
  dcl-s i int(10);

  m.matcher = %xlate(LOWER : UPPER : m.matcher);
  if m.parmNo = 0;
    setErr(err : 'IMQ0014' : what + ': parameter 0 is the return value, '
         + 'which arguments can''t be matched against');
    return *off;
  endif;
  if m.parmNo < 1 or m.parmNo > IMOQ_MAXP;
    setErr(err : 'IMQ0014' : what + ': parameter number must be 1 to 64');
    return *off;
  endif;
  if not imoq_validMatcher(m.matcher);
    setErr(err : 'IMQ0014' : what + ': ' + %trim(m.matcher)
         + ' is not a valid matcher');
    return *off;
  endif;

  if m.field <> '';
    if not findField(tgt.obj : tgt.proc : m.parmNo : m.field : d : off
                     : err);
      setErr(err : 'IMQ0014' : what + ': ' + %trimr(err.text));
      return *off;
    endif;
  else;
    if m.matcher = '*ANY' or m.matcher = '*OMIT'
       or m.matcher = '*NOTPASSED';
      return *on;
    endif;
    if m.parmNo > tgt.nDefs;
      setErr(err : 'IMQ0014' : what + ': parameter ' + %char(m.parmNo)
           + ' of ' + tgt.lbl + ' is not declared. '
           + 'Declare its layout with PARMS so values can be compared');
      return *off;
    endif;
    d = tgt.defs(m.parmNo);
  endif;

  // *IN value,value,... and *BETWEEN low,high
  if m.matcher = '*IN' or m.matcher = '*BETWEEN';
    if %len(m.val) - %len(%scanrpl(',' : '' : m.val)) >= %elem(items);
      setErr(err : 'IMQ0014' : what + ': ' + %trim(m.matcher)
           + ' takes at most 64 values');
      return *off;
    endif;
    n = imoq_splitList(m.val : items);
    if m.matcher = '*BETWEEN' and n <> 2;
      setErr(err : 'IMQ0014' : what + ': *BETWEEN takes two values '
           + 'separated by a comma, low,high; not ''' + m.val + '''');
      return *off;
    endif;
    if imoq_isNumeric(d.type);
      for i = 1 to n;
        if not canEncode(d : items(i) : msg);
          setErr(err : 'IMQ0014' : what + ': ' + %trim(m.matcher)
               + ' value ' + %char(i) + ': ' + msg);
          return *off;
        endif;
      endfor;
    endif;
    if m.matcher = '*BETWEEN'
       and not imoq_match('*LE' : items(2) : 'P' : items(1) : d);
      setErr(err : 'IMQ0014' : what + ': *BETWEEN low value '''
           + items(1) + ''' is greater than high value '''
           + items(2) + '''');
      return *off;
    endif;
    return *on;
  endif;

  if imoq_isNumeric(d.type)
     and m.matcher <> '*BLANK' and m.matcher <> '*LIKE'
     and m.matcher <> '*ANY' and m.matcher <> '*OMIT'
     and m.matcher <> '*NOTPASSED';
    if not canEncode(d : m.val : msg);
      setErr(err : 'IMQ0014' : what + ': ' + msg);
      return *off;
    endif;
  endif;
  return *on;
end-proc;

dcl-proc checkMatchers;
  dcl-pi *n ind;
    m likeds(imoq_matcher_t) dim(64);
    nM int(10) const;
    tgt likeds(target_t) const;
    err likeds(imoq_err_t);
  end-pi;
  dcl-s i int(10);
  for i = 1 to nM;
    if not checkMatcher(m(i) : 'ARGS entry ' + %char(i) : tgt : err);
      return *off;
    endif;
  endfor;
  return *on;
end-proc;

dcl-proc describeMatchers;
  dcl-pi *n varchar(1024);
    m likeds(imoq_matcher_t) dim(64) const;
    nM int(10) const;
  end-pi;
  dcl-s t varchar(1024);
  dcl-s i int(10);
  if nM = 0;
    return 'any arguments';
  endif;
  for i = 1 to nM;
    if i > 1;
      t += ', ';
    endif;
    t += refText(m(i).parmNo : m(i).field) + ' ' + %trim(m(i).matcher);
    if m(i).matcher <> '*ANY' and m(i).matcher <> '*OMIT'
       and m(i).matcher <> '*NOTPASSED' and m(i).matcher <> '*BLANK';
      t += ' ''' + %trimr(m(i).val) + '''';
    endif;
  endfor;
  return '(' + t + ')';
end-proc;

// ==================================================================
// Recorded calls
// ==================================================================

// Whole-parameter arguments of a call (subfield rows are left out)
dcl-proc loadCallArgs;
  dcl-pi *n;
    callId int(10) const;
    st char(1) dim(64);
    vals varchar(1024) dim(64);
    nArgs int(10);
  end-pi;
  dcl-s parmNo int(5);
  dcl-s state char(1);
  dcl-s v varchar(1024);

  st = 'N';
  vals = '';
  nArgs = 0;
  exec sql declare cCarg cursor for
    select parmno, state, val from qtemp.imoq_carg
     where callid = :callId and field = '' order by parmno;
  exec sql open cCarg;
  dow sqlcode = 0;
    exec sql fetch next from cCarg into :parmNo, :state, :v;
    if sqlcode <> 0;
      leave;
    endif;
    if parmNo >= 1 and parmNo <= IMOQ_MAXP;
      st(parmNo) = state;
      vals(parmNo) = v;
      if parmNo > nArgs;
        nArgs = parmNo;
      endif;
    endif;
  enddo;
  exec sql close cCarg;
end-proc;

// A recorded subfield value: state P, or the whole parameter's
// state (O, N) when it wasn't recorded
dcl-proc loadCallField;
  dcl-pi *n;
    callId int(10) const;
    parmNo int(10) const;
    field varchar(40) const;
    state char(1);
    val varchar(1024);
  end-pi;
  dcl-s p5 int(5);
  dcl-s fld varchar(40);
  p5 = parmNo;
  fld = field;
  val = '';
  exec sql select state, val into :state, :val from qtemp.imoq_carg
            where callid = :callId and parmno = :p5 and field = :fld;
  if sqlcode = 0;
    return;
  endif;
  state = 'N';
  exec sql select state into :state from qtemp.imoq_carg
            where callid = :callId and parmno = :p5 and field = '';
  if sqlcode <> 0 or state = 'P';
    state = 'N';
  endif;
end-proc;

dcl-proc describeCall;
  dcl-pi *n varchar(512);
    callId int(10) const;
  end-pi;
  dcl-s st char(1) dim(64);
  dcl-s vals varchar(1024) dim(64);
  dcl-s nArgs int(10);
  dcl-s t varchar(512);
  dcl-s v varchar(1024);
  dcl-s i int(10);

  loadCallArgs(callId : st : vals : nArgs);
  for i = 1 to nArgs;
    if st(i) = 'N';
      leave;
    endif;
    if i > 1;
      t += ', ';
    endif;
    if st(i) = 'O';
      v = '*OMIT';
    else;
      v = %trimr(vals(i));
      if %len(v) > 30;
        v = %subst(v : 1 : 27) + '...';
      endif;
      v = '''' + v + '''';
    endif;
    if %len(t) + %len(v) > 400;
      t += '...';
      leave;
    endif;
    t += v;
  endfor;
  return '#' + %char(callId) + '(' + t + ')';
end-proc;

dcl-proc callMatches;
  dcl-pi *n ind;
    callId int(10) const;
    m likeds(imoq_matcher_t) dim(64) const;
    nM int(10) const;
    tgt likeds(target_t) const;
  end-pi;
  dcl-s st char(1) dim(64);
  dcl-s vals varchar(1024) dim(64);
  dcl-s nArgs int(10);
  dcl-s i int(10);
  dcl-ds d likeds(imoq_def_t);
  dcl-ds err likeds(imoq_err_t);
  dcl-s off int(10);
  dcl-s fst char(1);
  dcl-s fval varchar(1024);

  if nM = 0;
    return *on;
  endif;
  loadCallArgs(callId : st : vals : nArgs);
  for i = 1 to nM;
    clear d;
    d.type = '*CHAR';
    if m(i).field <> '';
      findField(tgt.obj : tgt.proc : m(i).parmNo : m(i).field : d : off
                : err);
      loadCallField(callId : m(i).parmNo : m(i).field : fst : fval);
      if not imoq_match(m(i).matcher : m(i).val : fst : fval : d);
        return *off;
      endif;
      iter;
    endif;
    if m(i).parmNo <= tgt.nDefs;
      d = tgt.defs(m(i).parmNo);
    endif;
    if not imoq_match(m(i).matcher : m(i).val : st(m(i).parmNo)
                      : vals(m(i).parmNo) : d);
      return *off;
    endif;
  endfor;
  return *on;
end-proc;

dcl-proc loadCallIds;
  dcl-pi *n int(10);
    obj char(10) const;
    proc varchar(4096) const;
    ids int(10) dim(5000);
  end-pi;
  dcl-s n int(10);
  dcl-s id int(10);
  exec sql declare cCall cursor for
    select callid from qtemp.imoq_call
     where obj = :obj and proc = :proc order by callid;
  exec sql open cCall;
  dow sqlcode = 0 and n < MAXCALLS;
    exec sql fetch next from cCall into :id;
    if sqlcode <> 0;
      leave;
    endif;
    n += 1;
    ids(n) = id;
  enddo;
  exec sql close cCall;
  return n;
end-proc;

// ==================================================================
// CL command entry points (called by the command processing pgms)
// ==================================================================

// IMOQPGM -----------------------------------------------------------
dcl-proc imoq_cl_defPgm export;
  dcl-pi *n;
    obj char(10) const;
    behavior char(7) const;
    parms char(1) options(*varsize);
    realLib char(10) const;
    mockLib char(10) const;
    err likeds(imoq_err_t);
  end-pi;
  dcl-ds defs likeds(imoq_def_t) dim(64);
  dcl-s p pointer;
  dcl-s n int(10);
  dcl-s i int(10);
  dcl-s msg varchar(512);
  dcl-s m256 varchar(256);

  clearErr(err);
  ensureTables();
  p = %addr(parms);
  n = lstCount(p);
  if n > IMOQ_MAXP;
    setErr(err : 'IMQ0014' : 'At most 64 parameters can be declared');
    return;
  endif;
  for i = 1 to n;
    readDef(lstEntry(p : i) : defs(i) : *off);
    if not imoq_normDef(defs(i) : m256);
      setErr(err : 'IMQ0014' : 'PARMS entry ' + %char(i) + ': ' + m256);
      return;
    endif;
  endfor;

  forgetObj(obj);
  exec sql insert into qtemp.imoq_obj
    values(:obj, '*PGM', :behavior, :realLib, 'N', 'PGM', '', :mockLib);
  if sqlcode < 0;
    setErr(err : 'IMQ0015' : sqlFailText('Register mock'));
    return;
  endif;
  exec sql insert into qtemp.imoq_proc
    values(:obj, '*PGM', 1, 'PROC', 0, 'Y');
  for i = 1 to n;
    insertSig(obj : '*PGM' : i : defs(i));
  endfor;

  if not imoq_genPgm(obj : n : msg);
    setErr(err : 'IMQ0015' : msg);
    return;
  endif;
  err.text = %char(n) + ' parameter(s) declared';
end-proc;

// IMOQSRVPGM --------------------------------------------------------
dcl-proc imoq_cl_defSrv export;
  dcl-pi *n;
    obj char(10) const;
    behavior char(7) const;
    realLib char(10) const;
    mockLib char(10) const;
    srcFile char(10) const;
    signature char(16) const;
    err likeds(imoq_err_t);
  end-pi;
  dcl-s names varchar(4096) dim(2000);
  dcl-s n int(10);
  dcl-s i int(10);
  dcl-s msg varchar(512);
  dcl-s nm varchar(4096);
  dcl-s kind char(4);
  dcl-s size int(10);
  dcl-s nData int(10);
  dcl-s sig varchar(16);

  clearErr(err);
  ensureTables();

  // SRCFILE(*NONE): the exports are the procedures declared with IMOQPROC
  if srcFile = '*NONE';
    sig = %trim(signature);
    if %scan('''' : sig) > 0 or %scan('"' : sig) > 0;
      setErr(err : 'IMQ0014' : 'SIGNATURE cannot contain quotes');
      return;
    endif;
    forgetObj(obj);
    exec sql insert into qtemp.imoq_obj
      values(:obj, '*SRVPGM', :behavior, :realLib, 'N', 'PROC', :sig,
             :mockLib);
    if sqlcode < 0;
      setErr(err : 'IMQ0015' : sqlFailText('Register mock'));
      return;
    endif;
    err.text = 'no exports yet; every procedure declared with IMOQPROC '
             + 'becomes an export';
    return;
  endif;

  if not imoq_readExports(obj : names : n : msg);
    setErr(err : 'IMQ0013' : msg);
    return;
  endif;
  if n = 0;
    setErr(err : 'IMQ0013' : 'No exports found in the binder source for '
         + %trim(obj));
    return;
  endif;

  forgetObj(obj);
  exec sql insert into qtemp.imoq_obj
    values(:obj, '*SRVPGM', :behavior, :realLib, 'N', 'SRC', '', :mockLib);
  if sqlcode < 0;
    setErr(err : 'IMQ0015' : sqlFailText('Register mock'));
    return;
  endif;

  for i = 1 to n;
    nm = names(i);
    kind = 'PROC';
    size = 0;
    if realLib <> '*NONE';
      exec sql select data_item_size into :size
                 from qsys2.program_export_import_info
                where program_library = :realLib
                  and program_name = :obj
                  and object_type = '*SRVPGM'
                  and symbol_usage = '*DATAEXP'
                  and cast(symbol_name as varchar(4096)) = :nm
                fetch first 1 row only;
      if sqlcode = 0;
        kind = 'DATA';
        nData += 1;
        if size < 1;
          size = 1;
        endif;
      else;
        size = 0;
      endif;
    endif;
    exec sql insert into qtemp.imoq_proc
      values(:obj, :nm, :i, :kind, :size, 'N');
  endfor;
  err.text = %char(n) + ' export(s) found (' + %char(nData) + ' data)';
end-proc;

// IMOQPROC ----------------------------------------------------------
dcl-proc imoq_cl_defProc export;
  dcl-pi *n;
    obj char(10) const;
    procVary char(258);
    rtn char(1) options(*varsize);
    parms char(1) options(*varsize);
    err likeds(imoq_err_t);
  end-pi;
  dcl-s objType char(7);
  dcl-s behavior char(7);
  dcl-s built char(1);
  dcl-s realLib char(10);
  dcl-s proc varchar(4096);
  dcl-s kind char(4);
  dcl-s declared char(1);
  dcl-ds defs likeds(imoq_def_t) dim(64);
  dcl-ds rtnDef likeds(imoq_def_t);
  dcl-s hasRtn ind;
  dcl-s p pointer;
  dcl-s n int(10);
  dcl-s i int(10);
  dcl-s m256 varchar(256);

  clearErr(err);
  ensureTables();
  if not objInfo(obj : objType : behavior : built : realLib);
    setErr(err : 'IMQ0011' : 'Mock ' + %trim(obj) + ' does not exist. '
         + 'Create it with IMOQSRVPGM first');
    return;
  endif;
  if objType <> '*SRVPGM';
    setErr(err : 'IMQ0012' : 'IMOQPROC applies to service program mocks; '
         + %trim(obj) + ' is a program mock (use IMOQPGM PARMS)');
    return;
  endif;
  if not addExport(obj : varyText(%addr(procVary) : 256) : err);
    return;
  endif;
  if not resolveProc(obj : objType : varyText(%addr(procVary) : 256)
                     : proc : kind : declared : err);
    return;
  endif;
  if kind = 'DATA';
    setErr(err : 'IMQ0012' : proc + ' is a data export, not a procedure');
    return;
  endif;

  p = %addr(rtn);
  hasRtn = *off;
  if lstCount(p) > 0;
    readDef(p : rtnDef : *off);
    rtnDef.type = %xlate(LOWER : UPPER : rtnDef.type);
    if rtnDef.type <> '*NONE' and rtnDef.type <> ' ';
      if not imoq_normDef(rtnDef : m256);
        setErr(err : 'IMQ0014' : 'RTNTYPE: ' + m256);
        return;
      endif;
      hasRtn = *on;
    endif;
  endif;

  p = %addr(parms);
  n = lstCount(p);
  if n > IMOQ_MAXP;
    setErr(err : 'IMQ0014' : 'At most 64 parameters can be declared');
    return;
  endif;
  for i = 1 to n;
    readDef(lstEntry(p : i) : defs(i) : *on);
    if not imoq_normDef(defs(i) : m256);
      setErr(err : 'IMQ0014' : 'PARMS entry ' + %char(i) + ': ' + m256);
      return;
    endif;
  endfor;

  exec sql delete from qtemp.imoq_sig where obj = :obj and proc = :proc;
  exec sql delete from qtemp.imoq_fld where obj = :obj and proc = :proc;
  if hasRtn;
    insertSig(obj : proc : 0 : rtnDef);
  endif;
  for i = 1 to n;
    insertSig(obj : proc : i : defs(i));
  endfor;
  exec sql update qtemp.imoq_proc set declared = 'Y'
            where obj = :obj and proc = :proc;
  exec sql update qtemp.imoq_obj set built = 'N' where obj = :obj;
  err.text = proc;
end-proc;

// IMOQFIELD ---------------------------------------------------------
// FIELDS entries: name (30), position (int4, 0 = *NEXT), type (10),
// length (int4), decimals (int4), dim (int4, 0 = not an array)
dcl-proc imoq_cl_defField export;
  dcl-pi *n;
    obj char(10) const;
    procVary char(258);
    parmNo int(5) const;
    fields char(1) options(*varsize);
    err likeds(imoq_err_t);
  end-pi;
  dcl-ds tgt likeds(target_t);
  dcl-ds parent likeds(imoq_def_t);
  dcl-ds fd likeds(imoq_def_t) dim(64);
  dcl-s names varchar(30) dim(64);
  dcl-s poss int(10) dim(64);
  dcl-s dims int(10) dim(64);
  dcl-s p pointer;
  dcl-s e pointer;
  dcl-s n int(10);
  dcl-s i int(10);
  dcl-s j int(10);
  dcl-s nm varchar(30);
  dcl-s pos int(10);
  dcl-s dim int(10);
  dcl-s size int(10);
  dcl-s parentSize int(10);
  dcl-s last int(10);
  dcl-s nextPos int(10) inz(1);
  dcl-s what varchar(60);
  dcl-s place varchar(80);
  dcl-s m256 varchar(256);
  dcl-s proc varchar(4096);
  dcl-s p5 int(5);
  dcl-s seq int(10);
  dcl-s type char(10);
  dcl-s len int(10);
  dcl-s dec int(10);

  clearErr(err);
  ensureTables();
  if not openTarget(obj : varyText(%addr(procVary) : 256) : tgt : err);
    return;
  endif;
  if parmNo = 0;
    place = tgt.lbl + ' return value';
    if not tgt.hasRtn;
      setErr(err : 'IMQ0014' : tgt.lbl + ' has no declared return value. '
           + 'Declare RTNTYPE with IMOQPROC first');
      return;
    endif;
    parent = tgt.rtnDef;
  else;
    place = tgt.lbl + ' parameter ' + %char(parmNo);
    if parmNo > tgt.nDefs;
      setErr(err : 'IMQ0014' : 'Parameter ' + %char(parmNo) + ' of '
           + tgt.lbl + ' is not declared. Declare it with PARMS first');
      return;
    endif;
    parent = tgt.defs(parmNo);
  endif;
  if parent.type <> '*CHAR';
    setErr(err : 'IMQ0014' : place + ' is ' + imoq_rpgType(parent)
         + '. Declare a data structure or array as (*CHAR size) to '
         + 'give it fields');
    return;
  endif;
  parentSize = imoq_byteSize(parent);

  p = %addr(fields);
  n = lstCount(p);
  if n < 1 or n > %elem(names);
    setErr(err : 'IMQ0014' : 'Declare 1 to 64 fields');
    return;
  endif;
  for i = 1 to n;
    e = lstEntry(p : i);
    nm = %xlate(LOWER : UPPER : %trim(charAt(e + 2 : 30)));
    what = 'FIELDS entry ' + %char(i) + ' (' + nm + ')';
    if nm = '' or %check(NAMECHARS : nm) > 0;
      setErr(err : 'IMQ0014' : what + ': not a valid field name');
      return;
    endif;
    for j = 1 to i - 1;
      if names(j) = nm;
        setErr(err : 'IMQ0014' : what + ': ' + nm + ' is declared twice');
        return;
      endif;
    endfor;
    pos = int4At(e + 32);
    clear fd(i);
    fd(i).type = %xlate(LOWER : UPPER : charAt(e + 36 : 10));
    fd(i).len = int4At(e + 46);
    fd(i).dec = int4At(e + 50);
    fd(i).passing = '*REF';
    dim = int4At(e + 54);
    if not imoq_normDef(fd(i) : m256);
      setErr(err : 'IMQ0014' : what + ': ' + m256);
      return;
    endif;
    if dim < 0 or dim > 999;
      setErr(err : 'IMQ0014' : what + ': DIM must be 0 to 999');
      return;
    endif;
    if pos = 0;
      pos = nextPos;
    endif;
    size = imoq_byteSize(fd(i));
    last = pos - 1 + size;
    if dim > 0;
      last = pos - 1 + size * dim;
    endif;
    if pos < 1 or last > parentSize;
      setErr(err : 'IMQ0014' : what + ': positions ' + %char(pos) + ' to '
           + %char(last) + ' don''t fit in ' + place + ', which is '
           + %char(parentSize) + ' bytes');
      return;
    endif;
    names(i) = nm;
    poss(i) = pos;
    dims(i) = dim;
    nextPos = last + 1;
  endfor;

  // replace the parameter's fields
  proc = tgt.proc;
  p5 = parmNo;
  exec sql delete from qtemp.imoq_fld
            where obj = :obj and proc = :proc and parmno = :p5;
  for i = 1 to n;
    seq = i;
    nm = names(i);
    pos = poss(i);
    type = fd(i).type;
    len = fd(i).len;
    dec = fd(i).dec;
    dim = dims(i);
    exec sql insert into qtemp.imoq_fld
      values(:obj, :proc, :p5, :seq, :nm, :pos, :type, :len, :dec, :dim);
    if sqlcode < 0;
      setErr(err : 'IMQ0015' : sqlFailText('Save fields'));
      return;
    endif;
  endfor;
  err.text = %char(n) + ' field(s) declared for ' + place;
end-proc;

// IMOQBUILD ---------------------------------------------------------
dcl-proc imoq_cl_genSrv export;
  dcl-pi *n;
    obj char(10) const;
    err likeds(imoq_err_t);
  end-pi;
  dcl-s objType char(7);
  dcl-s behavior char(7);
  dcl-s built char(1);
  dcl-s realLib char(10);
  dcl-s msg varchar(512);

  clearErr(err);
  ensureTables();
  if not objInfo(obj : objType : behavior : built : realLib);
    setErr(err : 'IMQ0011' : 'Mock ' + %trim(obj) + ' does not exist. '
         + 'Create it with IMOQSRVPGM first');
    return;
  endif;
  if objType <> '*SRVPGM';
    setErr(err : 'IMQ0012' : 'IMOQBUILD applies to service program mocks; '
         + %trim(obj) + ' is a program mock');
    return;
  endif;
  if not imoq_genSrv(obj : msg);
    setErr(err : 'IMQ0015' : msg);
  endif;
end-proc;

dcl-proc imoq_cl_setBuilt export;
  dcl-pi *n;
    obj char(10) const;
    err likeds(imoq_err_t);
  end-pi;
  clearErr(err);
  ensureTables();
  exec sql update qtemp.imoq_obj set built = 'Y' where obj = :obj;
end-proc;

// Record a failure detected by a command processing program
dcl-proc imoq_cl_fail export;
  dcl-pi *n;
    msgId char(7) const;
    text char(512) const;
    err likeds(imoq_err_t);
  end-pi;
  setErr(err : msgId : %trimr(text));
end-proc;

// IMOQWHEN ----------------------------------------------------------
dcl-proc imoq_cl_when export;
  dcl-pi *n;
    obj char(10) const;
    procVary char(258);
    args char(1) options(*varsize);
    rtns char(1) options(*varsize);
    sets char(1) options(*varsize);
    thr char(1) options(*varsize);
    times int(10) const;
    err likeds(imoq_err_t);
  end-pi;
  dcl-ds stub likeds(imoq_stub_t);
  dcl-s p pointer;
  dcl-s e pointer;
  dcl-s i int(10);
  dcl-s msg varchar(256);

  clearErr(err);
  clear stub;
  stub.obj = obj;
  stub.proc = varyText(%addr(procVary) : 256);
  stub.times = times;

  if not unpackMatchers(%addr(args) : stub.m : stub.nM : err);
    return;
  endif;

  // RETURN values
  p = %addr(rtns);
  stub.nRtn = lstCount(p);
  if stub.nRtn > %elem(stub.rtn);
    setErr(err : 'IMQ0014' : 'At most 32 RETURN values are allowed');
    return;
  endif;
  for i = 1 to stub.nRtn;
    stub.rtn(i) = varyText(p + 2 + (i - 1) * 258 : 256);
  endfor;

  // SETPARM values
  p = %addr(sets);
  stub.nSet = lstCount(p);
  if stub.nSet > IMOQ_MAXP;
    setErr(err : 'IMQ0014' : 'At most 64 SETPARM entries are allowed');
    return;
  endif;
  for i = 1 to stub.nSet;
    e = lstEntry(p : i);
    stub.setNo(i) = int2At(e + 2);
    stub.setVal(i) = varyText(e + 4 : 256);
    if not imoq_parseField(charAt(e + 262 : 40) : stub.setFld(i) : msg);
      setErr(err : 'IMQ0014' : 'SETPARM entry ' + %char(i) + ': ' + msg);
      return;
    endif;
  endfor;

  // THROW
  p = %addr(thr);
  if lstCount(p) > 0;
    stub.thrId = charAt(p + 2 : 7);
    stub.thrMsgf = charAt(p + 9 : 10);
    stub.thrLib = charAt(p + 19 : 10);
    stub.thrDta = varyText(p + 29 : 256);
  endif;

  imoq_stubSave(stub : err);
end-proc;

// ------------------------------------------------------------------
// imoq_stubSave - validate a stub and save it. Used by IMOQWHEN and
// by the RPG API (IMOQAPI), which saves again after every change.
// ------------------------------------------------------------------
dcl-proc imoq_stubSave export;
  dcl-pi *n ind;
    stub likeds(imoq_stub_t);
    err likeds(imoq_err_t);
  end-pi;
  dcl-ds tgt likeds(target_t);
  dcl-s i int(10);
  dcl-s n int(10);
  dcl-s id int(10);
  dcl-s obj char(10);
  dcl-s proc varchar(4096);
  dcl-s times int(10);
  dcl-s thrId char(7);
  dcl-s thrMsgf char(10);
  dcl-s thrLib char(10);
  dcl-s thrDta varchar(512);
  dcl-s nRtn int(10);
  dcl-s seq int(10);
  dcl-s parmNo int(5);
  dcl-s mt char(10);
  dcl-s v varchar(1024);
  dcl-s m256 varchar(256);
  dcl-s fld varchar(40);
  dcl-s what varchar(60);
  dcl-ds fd likeds(imoq_def_t);
  dcl-s off int(10);

  clearErr(err);
  ensureTables();
  if not openTarget(stub.obj : stub.proc : tgt : err);
    return *off;
  endif;
  stub.proc = tgt.proc;
  if tgt.kind = 'DATA';
    setErr(err : 'IMQ0012' : tgt.proc + ' is a data export and cannot be '
         + 'stubbed');
    return *off;
  endif;

  if not checkMatchers(stub.m : stub.nM : tgt : err);
    return *off;
  endif;

  // RETURN values
  if stub.nRtn > %elem(stub.rtn);
    setErr(err : 'IMQ0014' : 'At most 32 RETURN values are allowed');
    return *off;
  endif;
  if stub.nRtn > 0 and not tgt.hasRtn;
    setErr(err : 'IMQ0014' : tgt.lbl + ' has no declared return value. '
         + 'Declare RTNTYPE with IMOQPROC');
    return *off;
  endif;
  for i = 1 to stub.nRtn;
    if not canEncode(tgt.rtnDef : stub.rtn(i) : m256);
      setErr(err : 'IMQ0014' : 'RETURN value ' + %char(i) + ': ' + m256);
      return *off;
    endif;
  endfor;

  // SETPARM values
  if stub.nSet > IMOQ_MAXP;
    setErr(err : 'IMQ0014' : 'At most 64 SETPARM entries are allowed');
    return *off;
  endif;
  for i = 1 to stub.nSet;
    what = 'SETPARM entry ' + %char(i);
    if stub.setNo(i) = 0;
      if stub.setFld(i) = '';
        setErr(err : 'IMQ0014' : what + ': parameter 0 is the return '
             + 'value; set all of it with RETURN, or one of its fields '
             + 'with 0.FIELD');
        return *off;
      endif;
      if not tgt.hasRtn;
        setErr(err : 'IMQ0014' : what + ': ' + tgt.lbl + ' has no '
             + 'declared return value. Declare RTNTYPE with IMOQPROC');
        return *off;
      endif;
    else;
      if stub.setNo(i) < 1 or stub.setNo(i) > tgt.nDefs;
        setErr(err : 'IMQ0014' : what + ': parameter '
             + %char(stub.setNo(i)) + ' of ' + tgt.lbl + ' is not declared');
        return *off;
      endif;
      if tgt.defs(stub.setNo(i)).passing = '*VALUE';
        setErr(err : 'IMQ0014' : what + ': parameter '
             + %char(stub.setNo(i)) + ' is passed by value and cannot be set');
        return *off;
      endif;
    endif;
    if stub.setFld(i) = '';
      fd = tgt.defs(stub.setNo(i));
    elseif not findField(tgt.obj : tgt.proc : stub.setNo(i)
                         : stub.setFld(i) : fd : off : err);
      setErr(err : 'IMQ0014' : what + ': ' + %trimr(err.text));
      return *off;
    endif;
    if not canEncode(fd : stub.setVal(i) : m256);
      setErr(err : 'IMQ0014' : what + ': ' + m256);
      return *off;
    endif;
  endfor;

  // THROW: fill in the defaults (saving again leaves them unchanged)
  stub.thrId = %xlate(LOWER : UPPER : stub.thrId);
  if stub.thrId = '*NONE' or stub.thrId = ' ';
    stub.thrId = ' ';
    stub.thrMsgf = ' ';
    stub.thrLib = ' ';
    stub.thrDta = '';
  else;
    stub.thrMsgf = %xlate(LOWER : UPPER : stub.thrMsgf);
    stub.thrLib = %xlate(LOWER : UPPER : stub.thrLib);
    if stub.thrId = '*MOCK';
      stub.thrId = 'IMQ0101';
    endif;
    if stub.thrMsgf = '*MOCK' or stub.thrMsgf = ' ';
      stub.thrMsgf = 'IMOQMSGF';
      stub.thrLib = psds.lib;
    endif;
    if stub.thrLib = ' ';
      stub.thrLib = '*LIBL';
    endif;
  endif;

  if stub.times < -1 or stub.times = 0;
    setErr(err : 'IMQ0014' : 'TIMES must be *ALWAYS or a positive number');
    return *off;
  endif;

  // Save. Stub numbers are never reused within the job, so a handle
  // to a stub that IMOQRESET removed can't point at a newer stub.
  obj = stub.obj;
  proc = stub.proc;
  times = stub.times;
  thrId = stub.thrId;
  thrMsgf = stub.thrMsgf;
  thrLib = stub.thrLib;
  thrDta = stub.thrDta;
  nRtn = stub.nRtn;
  if stub.id = 0;
    exec sql select coalesce(max(stubid), 0) into :id
               from qtemp.imoq_stub;
    if id < gLastStub;
      id = gLastStub;
    endif;
    id += 1;
    exec sql insert into qtemp.imoq_stub
      values(:id, :obj, :proc, :times, 0, :thrId, :thrMsgf, :thrLib,
             :thrDta, :nRtn);
    if sqlcode < 0;
      setErr(err : 'IMQ0015' : sqlFailText('Save stub'));
      return *off;
    endif;
    gLastStub = id;
    stub.id = id;
  else;
    id = stub.id;
    exec sql select count(*) into :n from qtemp.imoq_stub
              where stubid = :id and obj = :obj;
    if n = 0;
      setErr(err : 'IMQ0014' : 'Stub ' + %char(id) + ' of ' + tgt.lbl
           + ' no longer exists. IMOQRESET removed it');
      return *off;
    endif;
    // calls already answered count against a new TIMES
    exec sql update qtemp.imoq_stub
                set proc = :proc,
                    timesleft = case when :times < 0 then -1
                                     when :times > used then :times - used
                                     else 0 end,
                    thrid = :thrId, thrmsgf = :thrMsgf, thrlib = :thrLib,
                    thrdta = :thrDta, rtncnt = :nRtn
              where stubid = :id;
    if sqlcode < 0;
      setErr(err : 'IMQ0015' : sqlFailText('Save stub'));
      return *off;
    endif;
    exec sql delete from qtemp.imoq_sarg where stubid = :id;
    exec sql delete from qtemp.imoq_srtn where stubid = :id;
    exec sql delete from qtemp.imoq_sset where stubid = :id;
  endif;

  for i = 1 to stub.nM;
    parmNo = stub.m(i).parmNo;
    mt = stub.m(i).matcher;
    v = stub.m(i).val;
    fld = stub.m(i).field;
    exec sql insert into qtemp.imoq_sarg
      values(:id, :parmNo, :mt, :v, :fld);
  endfor;
  for i = 1 to stub.nRtn;
    seq = i;
    v = stub.rtn(i);
    exec sql insert into qtemp.imoq_srtn values(:id, :seq, :v);
  endfor;
  for i = 1 to stub.nSet;
    parmNo = stub.setNo(i);
    v = stub.setVal(i);
    fld = stub.setFld(i);
    exec sql insert into qtemp.imoq_sset values(:id, :parmNo, :v, :fld);
  endfor;
  return *on;
end-proc;

// ------------------------------------------------------------------
// imoq_stubLoad - read a saved stub back (for the RPG API handles)
// ------------------------------------------------------------------
dcl-proc imoq_stubLoad export;
  dcl-pi *n ind;
    id int(10) const;
    stub likeds(imoq_stub_t);
    err likeds(imoq_err_t);
  end-pi;
  dcl-s obj char(10);
  dcl-s proc varchar(4096);
  dcl-s left int(10);
  dcl-s used int(10);
  dcl-s thrId char(7);
  dcl-s thrMsgf char(10);
  dcl-s thrLib char(10);
  dcl-s thrDta varchar(512);
  dcl-s parmNo int(5);
  dcl-s mt char(10);
  dcl-s v varchar(1024);
  dcl-s fld varchar(40);

  clearErr(err);
  ensureTables();
  clear stub;
  exec sql select obj, proc, timesleft, used, thrid, thrmsgf, thrlib,
                  thrdta
             into :obj, :proc, :left, :used, :thrId, :thrMsgf, :thrLib,
                  :thrDta
             from qtemp.imoq_stub where stubid = :id;
  if sqlcode <> 0;
    setErr(err : 'IMQ0014' : 'Stub ' + %char(id) + ' no longer exists. '
         + 'IMOQRESET removed it');
    return *off;
  endif;
  stub.id = id;
  stub.obj = obj;
  stub.proc = proc;
  if left < 0;
    stub.times = -1;
  else;
    stub.times = left + used;
  endif;
  stub.thrId = thrId;
  stub.thrMsgf = thrMsgf;
  stub.thrLib = thrLib;
  stub.thrDta = thrDta;

  exec sql declare cLdArg cursor for
    select parmno, matcher, val, field from qtemp.imoq_sarg
     where stubid = :id order by parmno;
  exec sql open cLdArg;
  dow sqlcode = 0 and stub.nM < IMOQ_MAXP;
    exec sql fetch next from cLdArg into :parmNo, :mt, :v, :fld;
    if sqlcode <> 0;
      leave;
    endif;
    stub.nM += 1;
    stub.m(stub.nM).parmNo = parmNo;
    stub.m(stub.nM).matcher = mt;
    stub.m(stub.nM).val = v;
    stub.m(stub.nM).field = fld;
  enddo;
  exec sql close cLdArg;

  exec sql declare cLdRtn cursor for
    select val from qtemp.imoq_srtn where stubid = :id order by seq;
  exec sql open cLdRtn;
  dow sqlcode = 0 and stub.nRtn < %elem(stub.rtn);
    exec sql fetch next from cLdRtn into :v;
    if sqlcode <> 0;
      leave;
    endif;
    stub.nRtn += 1;
    stub.rtn(stub.nRtn) = v;
  enddo;
  exec sql close cLdRtn;

  exec sql declare cLdSet cursor for
    select parmno, val, field from qtemp.imoq_sset
     where stubid = :id order by parmno;
  exec sql open cLdSet;
  dow sqlcode = 0 and stub.nSet < IMOQ_MAXP;
    exec sql fetch next from cLdSet into :parmNo, :v, :fld;
    if sqlcode <> 0;
      leave;
    endif;
    stub.nSet += 1;
    stub.setNo(stub.nSet) = parmNo;
    stub.setVal(stub.nSet) = v;
    stub.setFld(stub.nSet) = fld;
  enddo;
  exec sql close cLdSet;
  return *on;
end-proc;

// IMOQVERIFY --------------------------------------------------------
dcl-proc imoq_cl_verify export;
  dcl-pi *n;
    obj char(10) const;
    procVary char(258);
    args char(1) options(*varsize);
    timesBlob char(1) options(*varsize);
    err likeds(imoq_err_t);
  end-pi;
  dcl-ds m likeds(imoq_matcher_t) dim(64);
  dcl-s nM int(10);
  dcl-s mode char(9);
  dcl-s want int(10);
  dcl-s cnt int(10);
  dcl-s p pointer;

  clearErr(err);
  if not unpackMatchers(%addr(args) : m : nM : err);
    return;
  endif;
  p = %addr(timesBlob);
  mode = '*EXACTLY';
  want = 1;
  if lstCount(p) > 0;
    mode = charAt(p + 2 : 9);
    want = int4At(p + 11);
  endif;
  imoq_verifyCalls(obj : varyText(%addr(procVary) : 256) : m : nM
                   : mode : want : cnt : err);
end-proc;

// ------------------------------------------------------------------
// imoq_verifyCalls - count the recorded calls that match, and check
// the count unless mode is *COUNT. Used by IMOQVERIFY, IMOQCOUNT and
// the RPG API. Returns *off on an error or a failed verification.
// ------------------------------------------------------------------
dcl-proc imoq_verifyCalls export;
  dcl-pi *n ind;
    obj char(10) const;
    procIn varchar(4096) const;
    mIn likeds(imoq_matcher_t) dim(64) const;
    nM int(10) const;
    modeIn char(9) const;
    wantIn int(10) const;
    count int(10);
    err likeds(imoq_err_t);
  end-pi;
  dcl-ds tgt likeds(target_t);
  dcl-ds m likeds(imoq_matcher_t) dim(64);
  dcl-s ids int(10) dim(5000);
  dcl-s hit ind dim(5000);
  dcl-s nIds int(10);
  dcl-s mode char(9);
  dcl-s want int(10);
  dcl-s ok ind;
  dcl-s i int(10);
  dcl-s id int(10);
  dcl-s modeText varchar(40);
  dcl-s txt varchar(2000);

  clearErr(err);
  ensureTables();
  count = 0;
  if not openTarget(obj : procIn : tgt : err);
    return *off;
  endif;
  for i = 1 to nM;
    m(i) = mIn(i);
  endfor;
  if not checkMatchers(m : nM : tgt : err);
    return *off;
  endif;

  mode = %xlate(LOWER : UPPER : modeIn);
  want = wantIn;
  if mode = '*ONCE';
    mode = '*EXACTLY';
    want = 1;
  elseif mode = '*NEVER';
    mode = '*EXACTLY';
    want = 0;
  endif;
  if want < 0;
    setErr(err : 'IMQ0014' : 'TIMES count cannot be negative');
    return *off;
  endif;

  nIds = loadCallIds(obj : tgt.proc : ids);
  for i = 1 to nIds;
    hit(i) = callMatches(ids(i) : m : nM : tgt);
    if hit(i);
      count += 1;
    endif;
  endfor;

  select;
  when mode = '*COUNT';
    return *on;
  when mode = '*ATLEAST';
    ok = count >= want;
    modeText = 'at least ' + %char(want) + ' time(s)';
  when mode = '*ATMOST';
    ok = count <= want;
    modeText = 'at most ' + %char(want) + ' time(s)';
  other;
    ok = count = want;
    modeText = 'exactly ' + %char(want) + ' time(s)';
  endsl;

  if ok;
    for i = 1 to nIds;
      if hit(i);
        id = ids(i);
        exec sql update qtemp.imoq_call set verified = 'Y'
                  where callid = :id;
      endif;
    endfor;
    return *on;
  endif;

  txt = 'Verification failed: expected ' + tgt.lbl + ' to be called '
      + modeText + ' with ' + describeMatchers(m : nM)
      + ' but it matched ' + %char(count) + ' time(s). Recorded calls: ';
  if nIds = 0;
    txt += 'none';
  endif;
  for i = 1 to nIds;
    if i > 5;
      txt += ' ... (' + %char(nIds) + ' total)';
      leave;
    endif;
    if i > 1;
      txt += ' ';
    endif;
    txt += describeCall(ids(i));
  endfor;
  if %len(txt) > 512;
    txt = %subst(txt : 1 : 509) + '...';
  endif;
  setErr(err : 'IMQ0200' : txt);
  return *off;
end-proc;

// IMOQORDER ---------------------------------------------------------
dcl-proc imoq_cl_order export;
  dcl-pi *n;
    obj char(10) const;
    procVary char(258);
    args char(1) options(*varsize);
    after char(6) const;
    err likeds(imoq_err_t);
  end-pi;
  dcl-ds m likeds(imoq_matcher_t) dim(64);
  dcl-s nM int(10);

  clearErr(err);
  if not unpackMatchers(%addr(args) : m : nM : err);
    return;
  endif;
  imoq_verifyOrder(obj : varyText(%addr(procVary) : 256) : m : nM
                   : after = '*START' : err);
end-proc;

// ------------------------------------------------------------------
// imoq_verifyOrder - a matching call came after the call the previous
// order check matched (or anywhere, with fromStart). The earliest such
// call becomes the new position and is marked verified. Used by
// IMOQORDER and imoq_calledInOrder. IMQ0200 on failure.
// ------------------------------------------------------------------
dcl-proc imoq_verifyOrder export;
  dcl-pi *n ind;
    obj char(10) const;
    procIn varchar(4096) const;
    mIn likeds(imoq_matcher_t) dim(64) const;
    nM int(10) const;
    fromStart ind const;
    err likeds(imoq_err_t);
  end-pi;
  dcl-ds tgt likeds(target_t);
  dcl-ds m likeds(imoq_matcher_t) dim(64);
  dcl-s ids int(10) dim(5000);
  dcl-s nIds int(10);
  dcl-s i int(10);
  dcl-s n int(10);
  dcl-s id int(10);
  dcl-s o char(10);
  dcl-s proc varchar(4096);
  dcl-s txt varchar(2000);

  clearErr(err);
  ensureTables();
  if not openTarget(obj : procIn : tgt : err);
    return *off;
  endif;
  for i = 1 to nM;
    m(i) = mIn(i);
  endfor;
  if not checkMatchers(m : nM : tgt : err);
    return *off;
  endif;
  if fromStart;
    gOrderPos = 0;
  endif;

  nIds = loadCallIds(obj : tgt.proc : ids);
  for i = 1 to nIds;
    if ids(i) > gOrderPos and callMatches(ids(i) : m : nM : tgt);
      id = ids(i);
      exec sql update qtemp.imoq_call set verified = 'Y'
                where callid = :id;
      gOrderPos = id;
      return *on;
    endif;
  endfor;

  // Say where the sequence stood and when the matching calls happened
  txt = 'Order verification failed: expected ' + tgt.lbl
      + ' to be called with ' + describeMatchers(m : nM);
  if gOrderPos > 0;
    id = gOrderPos;
    exec sql select obj, proc into :o, :proc from qtemp.imoq_call
              where callid = :id;
    txt += ' after ' + label(o : proc) + describeCall(id)
         + ', but no matching call came after it. Matching calls:';
  else;
    txt += ', but no call matched. Matching calls:';
  endif;
  for i = 1 to nIds;
    if callMatches(ids(i) : m : nM : tgt);
      n += 1;
      if n > 5;
        txt += ' ...';
        leave;
      endif;
      txt += ' ' + describeCall(ids(i));
    endif;
  endfor;
  if n = 0;
    txt += ' none';
  endif;
  if %len(txt) > 512;
    txt = %subst(txt : 1 : 509) + '...';
  endif;
  setErr(err : 'IMQ0200' : txt);
  return *off;
end-proc;

// imoq_startOrder() - the next order check may match any call
dcl-proc imoq_startOrder export;
  gOrderPos = 0;
end-proc;

// IMOQNOMORE --------------------------------------------------------
dcl-proc imoq_cl_noMore export;
  dcl-pi *n;
    obj char(10) const;
    err likeds(imoq_err_t);
  end-pi;
  dcl-s id int(10);
  dcl-s o char(10);
  dcl-s proc varchar(4096);
  dcl-s n int(10);
  dcl-s txt varchar(2000);

  clearErr(err);
  ensureTables();
  exec sql declare cUnv cursor for
    select callid, obj, proc from qtemp.imoq_call
     where verified <> 'Y' and (obj = :obj or :obj = '*ALL')
     order by callid;
  exec sql open cUnv;
  dow sqlcode = 0;
    exec sql fetch next from cUnv into :id, :o, :proc;
    if sqlcode <> 0;
      leave;
    endif;
    n += 1;
    if n <= 5;
      txt += ' ' + label(o : proc) + describeCall(id);
    endif;
  enddo;
  exec sql close cUnv;

  if n > 0;
    txt = 'Unverified interactions (' + %char(n) + '):' + txt;
    if %len(txt) > 512;
      txt = %subst(txt : 1 : 509) + '...';
    endif;
    setErr(err : 'IMQ0201' : txt);
  endif;
end-proc;

// IMOQUNUSED --------------------------------------------------------
// Fails with IMQ0203 while a stub (of obj) has answered no call
dcl-proc imoq_cl_unused export;
  dcl-pi *n;
    obj char(10) const;
    err likeds(imoq_err_t);
  end-pi;
  dcl-ds stub likeds(imoq_stub_t);
  dcl-ds lerr likeds(imoq_err_t);
  dcl-s id int(10);
  dcl-s o char(10);
  dcl-s proc varchar(4096);
  dcl-s n int(10);
  dcl-s txt varchar(2000);

  clearErr(err);
  ensureTables();
  exec sql declare cUnused cursor for
    select stubid, obj, proc from qtemp.imoq_stub
     where used = 0 and (obj = :obj or :obj = '*ALL')
     order by stubid;
  exec sql open cUnused;
  dow sqlcode = 0;
    exec sql fetch next from cUnused into :id, :o, :proc;
    if sqlcode <> 0;
      leave;
    endif;
    n += 1;
    if n <= 5;
      txt += ' stub ' + %char(id) + ' ' + label(o : proc) + ' with ';
      if imoq_stubLoad(id : stub : lerr);
        txt += describeMatchers(stub.m : stub.nM);
      endif;
      txt += ';';
    endif;
  enddo;
  exec sql close cUnused;

  if n > 0;
    txt = 'Unused stubs (' + %char(n) + '), no call matched:' + txt;
    if n > 5;
      txt += ' ...';
    endif;
    if %len(txt) > 512;
      txt = %subst(txt : 1 : 509) + '...';
    endif;
    setErr(err : 'IMQ0203' : txt);
  endif;
end-proc;

// IMOQGETARG --------------------------------------------------------
dcl-proc imoq_getArg export;
  dcl-pi *n ind;
    obj char(10) const;
    procIn varchar(4096) const;
    callNo int(10) const;
    parmNo int(10) const;
    field varchar(40) const;
    val varchar(1024);
    err likeds(imoq_err_t);
  end-pi;
  dcl-s objType char(7);
  dcl-s behavior char(7);
  dcl-s built char(1);
  dcl-s realLib char(10);
  dcl-s proc varchar(4096);
  dcl-s kind char(4);
  dcl-s declared char(1);
  dcl-s id int(10);
  dcl-s offs int(10);
  dcl-s state char(1);
  dcl-s p5 int(5);
  dcl-ds fd likeds(imoq_def_t);
  dcl-s off int(10);

  val = '';
  if not objInfo(obj : objType : behavior : built : realLib);
    setErr(err : 'IMQ0011' : 'Mock ' + %trim(obj) + ' does not exist');
    return *off;
  endif;
  if not resolveProc(obj : objType : procIn : proc : kind : declared
                     : err);
    return *off;
  endif;
  if field <> ''
     and not findField(obj : proc : parmNo : field : fd : off : err);
    return *off;
  endif;

  id = 0;
  if callNo = -1;
    exec sql select coalesce(max(callid), 0) into :id
               from qtemp.imoq_call where obj = :obj and proc = :proc;
  else;
    offs = callNo - 1;
    if offs < 0;
      offs = 0;
    endif;
    exec sql select callid into :id from qtemp.imoq_call
              where obj = :obj and proc = :proc order by callid
              offset :offs rows fetch first 1 row only;
    if sqlcode <> 0;
      id = 0;
    endif;
  endif;
  if id = 0;
    setErr(err : 'IMQ0202' : label(obj : proc) + ' has no call number '
         + %char(callNo) + ' (it was called '
         + %char(countCalls(obj : proc)) + ' time(s))');
    return *off;
  endif;

  if field <> '';
    loadCallField(id : parmNo : field : state : val);
  else;
    p5 = parmNo;
    exec sql select state, val into :state, :val from qtemp.imoq_carg
              where callid = :id and parmno = :p5 and field = '';
    if sqlcode <> 0;
      state = 'N';
    endif;
  endif;
  if state = 'N';
    val = '*NOTPASSED';
  elseif state = 'O';
    val = '*OMIT';
  endif;
  return *on;
end-proc;

dcl-proc countCalls;
  dcl-pi *n int(10);
    obj char(10) const;
    proc varchar(4096) const;
  end-pi;
  dcl-s n int(10);
  exec sql select count(*) into :n from qtemp.imoq_call
            where obj = :obj and proc = :proc;
  return n;
end-proc;

dcl-proc imoq_cl_getArg export;
  dcl-pi *n;
    obj char(10) const;
    procVary char(258);
    callNo int(10) const;
    parmNo int(5) const;
    fieldIn char(40) const;
    rtn char(256);
    err likeds(imoq_err_t);
  end-pi;
  dcl-s v varchar(1024);
  dcl-s field varchar(40);
  dcl-s msg varchar(256);
  clearErr(err);
  ensureTables();
  rtn = ' ';
  if not imoq_parseField(fieldIn : field : msg);
    setErr(err : 'IMQ0014' : 'FIELD: ' + msg);
    return;
  endif;
  if imoq_getArg(obj : varyText(%addr(procVary) : 256) : callNo : parmNo
            : field : v : err);
    rtn = v;
  endif;
end-proc;

// IMOQCOUNT ---------------------------------------------------------
dcl-proc imoq_cl_count export;
  dcl-pi *n;
    obj char(10) const;
    procVary char(258);
    args char(1) options(*varsize);
    count packed(10:0);
    err likeds(imoq_err_t);
  end-pi;
  dcl-ds m likeds(imoq_matcher_t) dim(64);
  dcl-s nM int(10);
  dcl-s cnt int(10);

  clearErr(err);
  count = 0;
  if not unpackMatchers(%addr(args) : m : nM : err);
    return;
  endif;
  if imoq_verifyCalls(obj : varyText(%addr(procVary) : 256) : m : nM
                      : '*COUNT' : 0 : cnt : err);
    count = cnt;
  endif;
end-proc;

// IMOQRESET ---------------------------------------------------------
dcl-proc imoq_cl_reset export;
  dcl-pi *n;
    obj char(10) const;
    scope char(7) const;
    err likeds(imoq_err_t);
  end-pi;
  clearErr(err);
  ensureTables();
  if scope = '*CALLS' or scope = '*ALL';
    deleteCalls(obj);
  endif;
  if scope = '*STUBS' or scope = '*ALL';
    deleteStubs(obj);
  endif;
end-proc;

// IMOQRMV -----------------------------------------------------------
dcl-proc imoq_cl_list export;
  dcl-pi *n;
    obj char(10) const;
    list char(5400);
    count int(10);
    err likeds(imoq_err_t);
  end-pi;
  dcl-s o char(10);
  dcl-s t char(7);
  dcl-s l char(10);

  clearErr(err);
  ensureTables();
  list = ' ';
  count = 0;
  exec sql declare cObj cursor for
    select obj, objtype, mocklib from qtemp.imoq_obj
     where obj = :obj or :obj = '*ALL' order by obj;
  exec sql open cObj;
  dow sqlcode = 0 and count < 200;
    exec sql fetch next from cObj into :o, :t, :l;
    if sqlcode <> 0;
      leave;
    endif;
    %subst(list : count * 27 + 1 : 27) = o + t + l;
    count += 1;
  enddo;
  exec sql close cObj;
end-proc;

// Library a mock object was created in
dcl-proc imoq_cl_mockLib export;
  dcl-pi *n;
    obj char(10) const;
    lib char(10);
    err likeds(imoq_err_t);
  end-pi;
  clearErr(err);
  ensureTables();
  lib = 'QTEMP';
  exec sql select mocklib into :lib from qtemp.imoq_obj where obj = :obj;
end-proc;

dcl-proc imoq_cl_forget export;
  dcl-pi *n;
    obj char(10) const;
    err likeds(imoq_err_t);
  end-pi;
  clearErr(err);
  if obj = '*ALL';
    dropTables();
    return;
  endif;
  ensureTables();
  forgetObj(obj);
end-proc;

// IMOQCHK -----------------------------------------------------------
dcl-proc findObj;
  dcl-pi *n char(10);
    lib char(10) const;
    obj char(10) const;
    type char(10) const;
  end-pi;
  dcl-s rcv char(90);
  dcl-ds ec likeds(apiErr_t);
  ec.bytesProv = %size(ec);
  ec.bytesAvail = 0;
  qusrobjd(rcv : %size(rcv) : 'OBJD0100' : obj + lib : type : ec);
  if ec.bytesAvail > 0;
    return ' ';
  endif;
  return %subst(rcv : 39 : 10);
end-proc;

dcl-proc imoq_cl_check export;
  dcl-pi *n;
    pgmQ char(20) const;
    outLines char(5000);
    count int(10);
    err likeds(imoq_err_t);
  end-pi;
  dcl-s o char(10);
  dcl-s t char(7);
  dcl-s built char(1);
  dcl-s hit char(10);
  dcl-s pgm char(10);
  dcl-s pgmLib char(10);
  dcl-s pgmType char(10);
  dcl-s bLib char(10);
  dcl-s bSrv char(10);
  dcl-s mlib char(10);

  clearErr(err);
  ensureTables();
  outLines = ' ';
  count = 0;

  exec sql declare cChk cursor for
    select obj, objtype, built, mocklib from qtemp.imoq_obj order by obj;
  exec sql open cChk;
  dow sqlcode = 0;
    exec sql fetch next from cChk into :o, :t, :built, :mlib;
    if sqlcode <> 0;
      leave;
    endif;
    hit = findObj('*LIBL' : o : t);
    if hit = ' ';
      addLine(outLines : count : 'Mock ' + %trim(o) + ' ' + %trim(t)
            + ' was not found in the library list (run IMOQBUILD or '
            + 're-create the mock)');
    elseif hit <> mlib;
      addLine(outLines : count : 'Mock ' + %trim(mlib) + '/' + %trim(o)
            + ' is hidden by ' + %trim(hit) + '/' + %trim(o)
            + ', which comes first in the library list');
    endif;
    if t = '*SRVPGM' and built <> 'Y';
      addLine(outLines : count : 'Service program mock ' + %trim(o)
            + ' has changes that are not built (run IMOQBUILD)');
    endif;
  enddo;
  exec sql close cChk;

  pgm = %subst(pgmQ : 1 : 10);
  pgmLib = %subst(pgmQ : 11 : 10);
  if pgm = '*NONE' or pgm = ' ';
    return;
  endif;
  pgmType = '*PGM';
  hit = findObj(pgmLib : pgm : pgmType);
  if hit = ' ';
    pgmType = '*SRVPGM';
    hit = findObj(pgmLib : pgm : pgmType);
  endif;
  if hit = ' ';
    addLine(outLines : count : 'Program ' + %trim(pgmLib) + '/' + %trim(pgm)
          + ' was not found');
    return;
  endif;
  pgmLib = hit;

  exec sql declare cBnd cursor for
    select b.bound_service_program_library, b.bound_service_program
      from qsys2.bound_srvpgm_info b
      join qtemp.imoq_obj m on m.obj = b.bound_service_program
     where b.program_library = :pgmLib and b.program_name = :pgm
       and b.bound_service_program_library <> '*LIBL';
  exec sql open cBnd;
  dow sqlcode = 0;
    exec sql fetch next from cBnd into :bLib, :bSrv;
    if sqlcode <> 0;
      leave;
    endif;
    addLine(outLines : count : %trim(pgmLib) + '/' + %trim(pgm) + ' binds '
          + %trim(bSrv) + ' from library ' + %trim(bLib)
          + ' instead of *LIBL, so the mock will not be used. Rebind '
          + 'with BNDSRVPGM((*LIBL/' + %trim(bSrv) + '))');
  enddo;
  exec sql close cBnd;
end-proc;

dcl-proc addLine;
  dcl-pi *n;
    outLines char(5000);
    count int(10);
    text varchar(512) const;
  end-pi;
  if count >= 20;
    return;
  endif;
  %subst(outLines : count * 250 + 1 : 250) = text;
  count += 1;
end-proc;

// ==================================================================
// imoq_invoke - runtime entry used by every generated stub
//   returns 1 when the stub must send thr as an escape message
// ==================================================================
dcl-proc imoq_invoke export;
  dcl-pi *n int(10);
    obj char(10) const;
    proc varchar(4096) const;
    parmCount int(10) value;
    parmPtrs pointer value;
    rtnPtr pointer value;
    thr likeds(imoq_throw_t);
  end-pi;

  dcl-s ptrs pointer dim(64) based(parmPtrs);
  dcl-s objType char(7);
  dcl-s behavior char(7);
  dcl-s built char(1);
  dcl-s realLib char(10);
  dcl-ds defs likeds(imoq_def_t) dim(64);
  dcl-ds rtnDef likeds(imoq_def_t);
  dcl-s hasRtn ind;
  dcl-s nDefs int(10);
  dcl-s st char(1) dim(64);
  dcl-s vals varchar(1024) dim(64);
  dcl-s nPassed int(10);
  dcl-s nCap int(10);
  dcl-s i int(10);
  dcl-s callId int(10);
  dcl-s parmNo int(5);
  dcl-s state char(1);
  dcl-s v varchar(1024);
  dcl-s stubIds int(10) dim(500);
  dcl-s stubLeft int(10) dim(500);
  dcl-s stubUsed int(10) dim(500);
  dcl-s nStubs int(10);
  dcl-s sid int(10);
  dcl-s sleft int(10);
  dcl-s sused int(10);
  dcl-s chosen int(10);
  dcl-s thrId char(7);
  dcl-s thrMsgf char(10);
  dcl-s thrLib char(10);
  dcl-s thrDta varchar(512);
  dcl-s rtnCnt int(10);
  dcl-s seq int(10);
  dcl-s m256 varchar(256);
  dcl-s args varchar(512);
  // declared subfields (IMOQFIELD) and their values in this call
  dcl-ds flds likeds(fields_t);
  dcl-s nX int(10);
  dcl-s xParm int(10) dim(MAXFVALS);
  dcl-s xKey varchar(40) dim(MAXFVALS);
  dcl-s xVal varchar(1024) dim(MAXFVALS);
  dcl-s xF int(10) dim(MAXFVALS);
  dcl-s j int(10);
  dcl-s e int(10);
  dcl-s nE int(10);
  dcl-s size int(10);
  dcl-s fld varchar(40);
  dcl-ds fd likeds(imoq_def_t);
  dcl-s off int(10);
  dcl-s nRf int(10);
  dcl-s rfFld varchar(40) dim(64);
  dcl-s rfVal varchar(1024) dim(64);

  clear thr;
  monitor;
    ensureTables();
    if not objInfo(obj : objType : behavior : built : realLib);
      return 0;
    endif;
    loadSig(obj : proc : defs : nDefs : rtnDef : hasRtn);

    nPassed = parmCount;
    if nPassed < 0;
      nPassed = nDefs;
    endif;
    if nPassed > IMOQ_MAXP;
      nPassed = IMOQ_MAXP;
    endif;
    nCap = nPassed;
    if nDefs > nCap;
      nCap = nDefs;
    endif;

    // capture arguments as they arrived
    for i = 1 to nCap;
      if i > nPassed;
        st(i) = 'N';
        vals(i) = '';
      elseif parmPtrs = *null or ptrs(i) = *null;
        st(i) = 'O';
        vals(i) = '';
      elseif i <= nDefs;
        st(i) = 'P';
        vals(i) = imoq_decode(ptrs(i) : defs(i));
      else;
        st(i) = 'P';
        vals(i) = '*UNDECLARED';
      endif;
    endfor;

    // and every declared subfield (element) of the passed parameters
    loadFields(obj : proc : flds);
    for j = 1 to flds.n;
      i = flds.parm(j);
      if i < 1 or i > nPassed or i > nDefs or st(i) <> 'P';
        iter;
      endif;
      size = imoq_byteSize(flds.def(j));
      nE = flds.dim(j);
      if nE = 0;
        nE = 1;
      endif;
      for e = 1 to nE;
        if nX >= MAXFVALS;
          leave;
        endif;
        nX += 1;
        xParm(nX) = i;
        xF(nX) = j;
        xKey(nX) = flds.name(j);
        if flds.dim(j) > 0;
          xKey(nX) += '(' + %char(e) + ')';
        endif;
        xVal(nX) = imoq_decode(ptrs(i) + flds.pos(j) - 1 + (e - 1) * size
                               : flds.def(j));
      endfor;
    endfor;

    exec sql select coalesce(max(callid), 0) + 1 into :callId
               from qtemp.imoq_call;
    exec sql insert into qtemp.imoq_call
      values(:callId, :obj, :proc, :nPassed, 0, 'N', current timestamp);
    for i = 1 to nCap;
      parmNo = i;
      state = st(i);
      v = vals(i);
      exec sql insert into qtemp.imoq_carg
        values(:callId, :parmNo, :state, :v, '');
    endfor;
    for i = 1 to nX;
      parmNo = xParm(i);
      v = xVal(i);
      fld = xKey(i);
      exec sql insert into qtemp.imoq_carg
        values(:callId, :parmNo, 'P', :v, :fld);
    endfor;

    // newest matching stub with uses left wins
    exec sql declare cStub cursor for
      select stubid, timesleft, used from qtemp.imoq_stub
       where obj = :obj and proc = :proc order by stubid desc;
    exec sql open cStub;
    dow sqlcode = 0 and nStubs < MAXSTUBS;
      exec sql fetch next from cStub into :sid, :sleft, :sused;
      if sqlcode <> 0;
        leave;
      endif;
      nStubs += 1;
      stubIds(nStubs) = sid;
      stubLeft(nStubs) = sleft;
      stubUsed(nStubs) = sused;
    enddo;
    exec sql close cStub;

    for i = 1 to nStubs;
      if stubLeft(i) = 0;
        iter;
      endif;
      if stubMatches(stubIds(i) : defs : nDefs : st : vals
                     : flds : nX : xParm : xKey : xVal : xF);
        chosen = i;
        leave;
      endif;
    endfor;

    if chosen = 0;
      if behavior = '*STRICT';
        callMatchesText(callId : args);
        thr.msgId = 'IMQ0100';
        thr.msgf = 'IMOQMSGF';
        thr.msgfLib = psds.lib;
        thr.msgDta = 'Unexpected call to ' + label(obj : proc) + args
                   + ' (strict mock has no matching IMOQWHEN)';
        gLastErr = thr.msgDta;
        return 1;
      endif;
      return 0;
    endif;

    sid = stubIds(chosen);
    exec sql update qtemp.imoq_stub
                set used = used + 1,
                    timesleft = case when timesleft > 0
                                     then timesleft - 1
                                     else timesleft end
              where stubid = :sid;
    exec sql update qtemp.imoq_call set stubid = :sid
              where callid = :callId;

    exec sql select thrid, thrmsgf, thrlib, thrdta, rtncnt
               into :thrId, :thrMsgf, :thrLib, :thrDta, :rtnCnt
               from qtemp.imoq_stub where stubid = :sid;
    if thrId <> ' ';
      thr.msgId = thrId;
      thr.msgf = thrMsgf;
      thr.msgfLib = thrLib;
      thr.msgDta = thrDta;
      return 1;
    endif;

    // SETPARM (fields of the return value wait until after RETURN)
    exec sql declare cSet cursor for
      select parmno, val, field from qtemp.imoq_sset
       where stubid = :sid order by parmno;
    exec sql open cSet;
    dow sqlcode = 0;
      exec sql fetch next from cSet into :parmNo, :v, :fld;
      if sqlcode <> 0;
        leave;
      endif;
      if parmNo = 0;
        if fld <> '' and nRf < %elem(rfFld);
          nRf += 1;
          rfFld(nRf) = fld;
          rfVal(nRf) = v;
        endif;
      elseif parmNo <= nDefs and parmNo <= nPassed and st(parmNo) = 'P';
        if fld = '';
          imoq_encode(ptrs(parmNo) : defs(parmNo) : v : m256);
        elseif fieldAt(flds : parmNo : fld : fd : off);
          imoq_encode(ptrs(parmNo) + off : fd : v : m256);
        endif;
      endif;
    enddo;
    exec sql close cSet;

    // RETURN (consecutive values, the last one repeats)
    if rtnCnt > 0 and hasRtn and rtnPtr <> *null;
      seq = stubUsed(chosen) + 1;
      if seq > rtnCnt;
        seq = rtnCnt;
      endif;
      exec sql select val into :v from qtemp.imoq_srtn
                where stubid = :sid and seq = :seq;
      if sqlcode = 0;
        imoq_encode(rtnPtr : rtnDef : v : m256);
      endif;
    endif;

    // Fields of a data structure return value. Without RETURN, the
    // rest of the value starts out blank, with zero numbers.
    if nRf > 0 and hasRtn and rtnPtr <> *null;
      if rtnCnt = 0;
        clearReturn(rtnPtr : rtnDef : flds);
      endif;
      for i = 1 to nRf;
        if fieldAt(flds : 0 : rfFld(i) : fd : off);
          imoq_encode(rtnPtr + off : fd : rfVal(i) : m256);
        endif;
      endfor;
    endif;
  on-error;
    return 0;
  endmon;
  return 0;
end-proc;

dcl-proc callMatchesText;
  dcl-pi *n;
    callId int(10) const;
    text varchar(512);
  end-pi;
  dcl-s d varchar(512);
  dcl-s p int(10);
  d = describeCall(callId);
  p = %scan('(' : d);
  if p > 0;
    text = %subst(d : p);
  else;
    text = '()';
  endif;
end-proc;

dcl-proc stubMatches;
  dcl-pi *n ind;
    stubId int(10) const;
    defs likeds(imoq_def_t) dim(64) const;
    nDefs int(10) const;
    st char(1) dim(64) const;
    vals varchar(1024) dim(64) const;
    flds likeds(fields_t) const;
    nX int(10) const;
    xParm int(10) dim(MAXFVALS) const;
    xKey varchar(40) dim(MAXFVALS) const;
    xVal varchar(1024) dim(MAXFVALS) const;
    xF int(10) dim(MAXFVALS) const;
  end-pi;
  dcl-s parmNo int(5);
  dcl-s matcher char(10);
  dcl-s v varchar(1024);
  dcl-s fld varchar(40);
  dcl-s ok ind inz(*on);
  dcl-s k int(10);
  dcl-s hit int(10);
  dcl-ds d likeds(imoq_def_t);

  exec sql declare cSarg cursor for
    select parmno, matcher, val, field from qtemp.imoq_sarg
     where stubid = :stubId order by parmno;
  exec sql open cSarg;
  dow sqlcode = 0;
    exec sql fetch next from cSarg into :parmNo, :matcher, :v, :fld;
    if sqlcode <> 0;
      leave;
    endif;
    clear d;
    d.type = '*CHAR';
    if fld <> '';
      hit = 0;
      for k = 1 to nX;
        if xParm(k) = parmNo and xKey(k) = fld;
          hit = k;
          leave;
        endif;
      endfor;
      if hit = 0;
        ok = imoq_match(matcher : v : 'N' : '' : d);
      else;
        d = flds.def(xF(hit));
        ok = imoq_match(matcher : v : 'P' : xVal(hit) : d);
      endif;
    else;
      if parmNo <= nDefs;
        d = defs(parmNo);
      endif;
      ok = imoq_match(matcher : v : st(parmNo) : vals(parmNo) : d);
    endif;
    if not ok;
      leave;
    endif;
  enddo;
  exec sql close cSarg;
  return ok;
end-proc;

// ------------------------------------------------------------------
// Subfields of one procedure, for imoq_invoke
// ------------------------------------------------------------------
dcl-proc loadFields;
  dcl-pi *n;
    obj char(10) const;
    proc varchar(4096) const;
    flds likeds(fields_t);
  end-pi;
  dcl-s p5 int(5);
  dcl-s nm varchar(30);
  dcl-s pos int(10);
  dcl-s type char(10);
  dcl-s len int(10);
  dcl-s dec int(10);
  dcl-s dim int(10);

  flds.n = 0;
  exec sql declare cFld cursor for
    select parmno, name, pos, type, len, dec, dim from qtemp.imoq_fld
     where obj = :obj and proc = :proc order by parmno, seq;
  exec sql open cFld;
  dow sqlcode = 0 and flds.n < MAXFIELDS;
    exec sql fetch next from cFld
      into :p5, :nm, :pos, :type, :len, :dec, :dim;
    if sqlcode <> 0;
      leave;
    endif;
    flds.n += 1;
    flds.parm(flds.n) = p5;
    flds.name(flds.n) = nm;
    flds.pos(flds.n) = pos;
    flds.dim(flds.n) = dim;
    clear flds.def(flds.n);
    flds.def(flds.n).type = type;
    flds.def(flds.n).len = len;
    flds.def(flds.n).dec = dec;
    flds.def(flds.n).passing = '*REF';
  enddo;
  exec sql close cFld;
end-proc;

// Layout and offset of NAME or NAME(i) in a loaded field list
dcl-proc fieldAt;
  dcl-pi *n ind;
    flds likeds(fields_t) const;
    parmNo int(10) const;
    field varchar(40) const;
    def likeds(imoq_def_t);
    offset int(10);
  end-pi;
  dcl-s name varchar(30);
  dcl-s idx int(10);
  dcl-s j int(10);
  splitField(field : name : idx);
  if idx = 0;
    idx = 1;
  endif;
  for j = 1 to flds.n;
    if flds.parm(j) = parmNo and flds.name(j) = name;
      if flds.dim(j) > 0 and idx > flds.dim(j);
        return *off;
      endif;
      def = flds.def(j);
      offset = flds.pos(j) - 1 + (idx - 1) * imoq_byteSize(def);
      return *on;
    endif;
  endfor;
  return *off;
end-proc;

// Blank a data structure return value, then zero its numeric and
// date/time fields so the caller never sees decimal data errors
dcl-proc clearReturn;
  dcl-pi *n;
    rtnPtr pointer value;
    rtnDef likeds(imoq_def_t) const;
    flds likeds(fields_t) const;
  end-pi;
  dcl-s q pointer;
  dcl-s chunk char(32767) based(q);
  dcl-s left int(10);
  dcl-s n int(10);
  dcl-s j int(10);
  dcl-s e int(10);
  dcl-s nE int(10);
  dcl-s size int(10);
  dcl-s zero varchar(32);
  dcl-s m256 varchar(256);

  q = rtnPtr;
  left = imoq_byteSize(rtnDef);
  dow left > 0;
    n = left;
    if n > %size(chunk);
      n = %size(chunk);
    endif;
    %subst(chunk : 1 : n) = *blanks;
    q += n;
    left -= n;
  enddo;

  for j = 1 to flds.n;
    if flds.parm(j) <> 0;
      iter;
    endif;
    select;
    when imoq_isNumeric(flds.def(j).type);
      zero = '0';
    when flds.def(j).type = '*DATE';
      zero = '0001-01-01';
    when flds.def(j).type = '*TIME';
      zero = '00.00.00';
    when flds.def(j).type = '*TIMESTAMP';
      zero = '0001-01-01-00.00.00.000000';
    when flds.def(j).type = '*IND';
      zero = '0';
    when flds.def(j).type = '*VARCHAR';
      zero = '';
    when flds.def(j).type = '*PTR';
      zero = '*NULL';
    other;
      iter;
    endsl;
    size = imoq_byteSize(flds.def(j));
    nE = flds.dim(j);
    if nE = 0;
      nE = 1;
    endif;
    for e = 1 to nE;
      imoq_encode(rtnPtr + flds.pos(j) - 1 + (e - 1) * size
                  : flds.def(j) : zero : m256);
    endfor;
  endfor;
end-proc;

// ==================================================================
// Public API for test programs
// ==================================================================
dcl-proc runCmd;
  dcl-pi *n ind;
    cmd varchar(3000) const;
  end-pi;
  gLastErr = '';
  monitor;
    qcmdexc(cmd : %len(cmd));
  on-error;
    if gLastErr = '';
      gLastErr = psds.excType + psds.excNum + ' running: ' + cmd;
      if %len(gLastErr) > 500;
        gLastErr = %subst(gLastErr : 1 : 500);
      endif;
    endif;
    return *off;
  endmon;
  return *on;
end-proc;

dcl-proc imoq_run export;
  dcl-pi *n;
    cmd varchar(3000) const;
  end-pi;
  dcl-s key char(4);
  dcl-ds ec likeds(apiErr_t);
  dcl-s dta char(512);
  if runCmd(cmd);
    return;
  endif;
  ec.bytesProv = 0;
  dta = gLastErr;
  qmhsndpm('IMQ0300' : 'IMOQMSGF  ' + psds.lib : dta : %len(gLastErr)
          : '*ESCAPE' : '*' : 1 : key : ec);
end-proc;

dcl-proc imoq_ok export;
  dcl-pi *n ind;
    cmd varchar(3000) const;
  end-pi;
  return runCmd(cmd);
end-proc;

dcl-proc imoq_lastError export;
  dcl-pi *n varchar(512) end-pi;
  return gLastErr;
end-proc;

dcl-proc imoq_arg export;
  dcl-pi *n varchar(1024);
    obj char(10) const;
    proc varchar(4096) const;
    callNo int(10) const;
    parmNo int(10) const;
    fieldIn varchar(40) const options(*nopass);
  end-pi;
  dcl-ds err likeds(imoq_err_t);
  dcl-s v varchar(1024);
  dcl-s field varchar(40);
  dcl-s msg varchar(256);
  clearErr(err);
  ensureTables();
  if %parms() >= %parmnum(fieldIn);
    if not imoq_parseField(fieldIn : field : msg);
      return '*ERROR ' + msg;
    endif;
  endif;
  if not imoq_getArg(obj : proc : callNo : parmNo : field : v : err);
    return '*ERROR ' + %trimr(err.text);
  endif;
  return v;
end-proc;

dcl-proc imoq_count export;
  dcl-pi *n int(10);
    obj char(10) const;
    proc varchar(4096) const;
  end-pi;
  dcl-ds err likeds(imoq_err_t);
  dcl-s objType char(7);
  dcl-s behavior char(7);
  dcl-s built char(1);
  dcl-s realLib char(10);
  dcl-s p varchar(4096);
  dcl-s kind char(4);
  dcl-s declared char(1);
  clearErr(err);
  ensureTables();
  if not objInfo(obj : objType : behavior : built : realLib);
    return -1;
  endif;
  if not resolveProc(obj : objType : proc : p : kind : declared : err);
    return -1;
  endif;
  return countCalls(obj : p);
end-proc;

// ==================================================================
// Engine core for the RPG API (IMOQAPI)
// ==================================================================
dcl-proc imoq_resolveTarget export;
  dcl-pi *n ind;
    obj char(10) const;
    procIn varchar(4096) const;
    procOut varchar(4096);
    err likeds(imoq_err_t);
  end-pi;
  dcl-ds tgt likeds(target_t);
  clearErr(err);
  ensureTables();
  procOut = '';
  if not openTarget(obj : procIn : tgt : err);
    return *off;
  endif;
  procOut = tgt.proc;
  return *on;
end-proc;

dcl-proc imoq_checkMatcher export;
  dcl-pi *n ind;
    obj char(10) const;
    proc varchar(4096) const;
    m likeds(imoq_matcher_t);
    what varchar(40) const;
    err likeds(imoq_err_t);
  end-pi;
  dcl-ds tgt likeds(target_t);
  clearErr(err);
  ensureTables();
  if not openTarget(obj : proc : tgt : err);
    return *off;
  endif;
  return checkMatcher(m : what : tgt : err);
end-proc;

dcl-proc imoq_setLastError export;
  dcl-pi *n;
    text varchar(512) const;
  end-pi;
  gLastErr = text;
end-proc;
