**free
// ------------------------------------------------------------------
// IMOQENG_T - iMoq engine unit tests: codec, layouts, matchers,
//             number text for the RPG API, subfield sizes and names.
// Run with IMOQTEST.
// ------------------------------------------------------------------
ctl-opt main(runTests) option(*srcstmt:*nodebugio) decprec(63);

/copy QTEMP/IMOQINC,IMOQENG_H

dcl-s buf char(64);

/copy QTEMP/IMOQINC,IMOQTST_H

dcl-proc runTests;
  dcl-pi *n;
    report char(8000);
    failures int(10);
  end-pi;
  tst_init(report);
  test_normDef();
  test_roundTrips();
  test_encodeErrors();
  test_invalidPacked();
  test_matchers();
  test_listMatchers();
  test_numText();
  test_byteSize();
  test_parseField();
  tst_summary(failures);
end-proc;

// encode then decode through the codec
dcl-proc rt;
  dcl-pi *n varchar(1024);
    type char(10) const;
    len int(10) const;
    dec int(10) const;
    text varchar(1024) const;
  end-pi;
  dcl-ds def likeds(imoq_def_t);
  dcl-s msg varchar(256);
  def.type = type;
  def.len = len;
  def.dec = dec;
  def.passing = '*REF';
  if not imoq_normDef(def : msg);
    return '*DEF ' + msg;
  endif;
  buf = *allx'00';
  if not imoq_encode(%addr(buf) : def : text : msg);
    return '*ERR ' + msg;
  endif;
  return imoq_decode(%addr(buf) : def);
end-proc;

dcl-proc mdef;
  dcl-pi *n likeds(imoq_def_t);
    type char(10) const;
    len int(10) const;
    dec int(10) const;
  end-pi;
  dcl-ds def likeds(imoq_def_t);
  dcl-s msg varchar(256);
  def.type = type;
  def.len = len;
  def.dec = dec;
  imoq_normDef(def : msg);
  return def;
end-proc;

dcl-proc test_normDef;
  dcl-ds def likeds(imoq_def_t);
  dcl-s msg varchar(256);
  tst_begin('layouts are validated and defaulted');
  def.type = '*int';
  def.len = 0;
  tst_check(imoq_normDef(def : msg) : msg);
  tst_eqNum(10 : def.len : '*INT default length');
  tst_eqChar('*REF' : def.passing : 'default passing');
  def.type = '*INT';
  def.len = 7;
  tst_check(not imoq_normDef(def : msg) : '*INT 7 accepted');
  def.type = '*PACKED';
  def.len = 5;
  def.dec = 6;
  tst_check(not imoq_normDef(def : msg) : 'packed 5,6 accepted');
  def.type = '*CHAR';
  def.len = 0;
  tst_check(not imoq_normDef(def : msg) : 'char 0 accepted');
  def.type = '*BOGUS';
  tst_check(not imoq_normDef(def : msg) : 'unknown type accepted');
  tst_end();
end-proc;

dcl-proc test_roundTrips;
  tst_begin('values round-trip through every type');
  tst_eqChar('-123.45' : rt('*PACKED' : 7 : 2 : '-123.45') : 'packed 7,2');
  tst_eqChar('123456' : rt('*PACKED' : 6 : 0 : '123456') : 'packed 6,0');
  tst_eqChar('0.50' : rt('*PACKED' : 5 : 2 : '.5') : 'packed .5');
  tst_eqChar('0' : rt('*PACKED' : 3 : 0 : '-0') : 'packed -0');
  tst_eqChar('-1.50' : rt('*ZONED' : 5 : 2 : '-1.5') : 'zoned 5,2');
  tst_eqChar('99999' : rt('*ZONED' : 5 : 0 : '+99999') : 'zoned max');
  tst_eqChar('-128' : rt('*INT' : 3 : 0 : '-128') : 'int 3');
  tst_eqChar('-9000000000' : rt('*INT' : 20 : 0 : '-9000000000')
           : 'int 20');
  tst_eqChar('65535' : rt('*UNS' : 5 : 0 : '65535') : 'uns 5');
  tst_check(%float(rt('*FLOAT' : 8 : 0 : '1.5')) = 1.5
          : 'float 8 was ' + rt('*FLOAT' : 8 : 0 : '1.5'));
  tst_eqChar('AB' : rt('*CHAR' : 5 : 0 : 'AB') : 'char');
  tst_eqChar('ABCDE' : rt('*CHAR' : 5 : 0 : 'ABCDEFG') : 'char trunc');
  tst_eqChar('hello' : rt('*VARCHAR' : 10 : 0 : 'hello') : 'varchar');
  tst_eqChar('1' : rt('*IND' : 0 : 0 : '*ON') : 'ind *ON');
  tst_eqChar('2026-09-13' : rt('*DATE' : 0 : 0 : '2026-09-13') : 'date');
  tst_eqChar('12.30.00' : rt('*TIME' : 0 : 0 : '12.30.00') : 'time');
  tst_eqChar('2026-09-13-12.30.00.000000'
           : rt('*TIMESTAMP' : 0 : 0 : '2026-09-13-12.30.00.000000')
           : 'timestamp');
  tst_eqChar('*NULL' : rt('*PTR' : 0 : 0 : '*NULL') : 'pointer');
  tst_end();
end-proc;

dcl-proc test_encodeErrors;
  tst_begin('values that do not fit are rejected');
  tst_check(%scan('*ERR' : rt('*PACKED' : 5 : 2 : '1234.5')) = 1
          : 'packed overflow accepted');
  tst_check(%scan('*ERR' : rt('*PACKED' : 5 : 2 : '12a')) = 1
          : 'non-numeric accepted');
  tst_check(%scan('*ERR' : rt('*INT' : 3 : 0 : '200')) = 1
          : 'int 3 overflow accepted');
  tst_check(%scan('*ERR' : rt('*IND' : 0 : 0 : 'X')) = 1
          : 'bad indicator accepted');
  tst_check(%scan('*ERR' : rt('*DATE' : 0 : 0 : '2026-13-45')) = 1
          : 'bad date accepted');
  tst_end();
end-proc;

dcl-proc test_invalidPacked;
  dcl-ds def likeds(imoq_def_t);
  tst_begin('decimal data errors decode as *INVALID');
  def = mdef('*PACKED' : 5 : 0);
  buf = *blanks;
  tst_eqChar('*INVALID' : imoq_decode(%addr(buf) : def) : 'packed');
  def = mdef('*ZONED' : 3 : 0);
  buf = 'ABC';
  tst_eqChar('*INVALID' : imoq_decode(%addr(buf) : def) : 'zoned');
  tst_eqChar('*NULL' : imoq_decode(*null : def) : 'null address');
  tst_end();
end-proc;

dcl-proc test_matchers;
  dcl-ds n likeds(imoq_def_t);
  dcl-ds c likeds(imoq_def_t);
  tst_begin('matchers');
  n = mdef('*PACKED' : 7 : 2);
  c = mdef('*CHAR' : 10 : 0);
  tst_check(imoq_match('*EQ' : '100' : 'P' : '100.00' : n) : 'num eq');
  tst_check(imoq_match('*GT' : '99.99' : 'P' : '100.00' : n) : 'num gt');
  tst_check(not imoq_match('*LT' : '5' : 'P' : '10' : n) : 'num lt');
  tst_check(imoq_match('*LE' : '10' : 'P' : '10' : n) : 'num le');
  tst_check(imoq_match('*NE' : 'B' : 'P' : 'A' : c) : 'char ne');
  tst_check(imoq_match('*EQ' : 'ABC' : 'P' : 'ABC   ' : c)
          : 'char eq ignores trailing blanks');
  tst_check(imoq_match('*LIKE' : 'C%1' : 'P' : 'CXX1' : c) : 'like %');
  tst_check(imoq_match('*LIKE' : 'C_1' : 'P' : 'CX1' : c) : 'like _');
  tst_check(not imoq_match('*LIKE' : 'C_1' : 'P' : 'CXX1' : c)
          : 'like _ is one character');
  tst_check(imoq_match('*LIKE' : '%' : 'P' : '' : c) : 'like % empty');
  tst_check(imoq_match('*BLANK' : '' : 'P' : '' : c) : 'blank char');
  tst_check(imoq_match('*BLANK' : '' : 'P' : '0.00' : n) : 'blank num');
  tst_check(imoq_match('*OMIT' : '' : 'O' : '' : c) : 'omit');
  tst_check(not imoq_match('*EQ' : '' : 'O' : '' : c) : 'omit vs eq');
  tst_check(imoq_match('*NOTPASSED' : '' : 'N' : '' : c) : 'notpassed');
  tst_check(imoq_match('*ANY' : '' : 'N' : '' : c) : 'any');
  tst_check(not imoq_match('*EQ' : 'x' : 'P' : 'abc' : n)
          : 'non-numeric compare is false');
  tst_end();
end-proc;

dcl-proc test_listMatchers;
  dcl-ds n likeds(imoq_def_t);
  dcl-ds c likeds(imoq_def_t);
  dcl-ds d likeds(imoq_def_t);
  tst_begin('*IN and *BETWEEN');
  n = mdef('*PACKED' : 7 : 2);
  c = mdef('*CHAR' : 10 : 0);
  d = mdef('*DATE' : 0 : 0);
  tst_check(imoq_match('*IN' : 'PA,NJ,NY' : 'P' : 'NJ' : c) : 'in: middle');
  tst_check(imoq_match('*IN' : 'PA, NJ , NY' : 'P' : 'NY   ' : c)
          : 'in: blanks around items are ignored');
  tst_check(not imoq_match('*IN' : 'PA,NJ,NY' : 'P' : 'N' : c)
          : 'in: whole items only');
  tst_check(imoq_match('*IN' : 'PA' : 'P' : 'PA' : c) : 'in: one item');
  tst_check(imoq_match('*IN' : 'PA,,NY' : 'P' : '' : c)
          : 'in: an empty item matches blanks');
  tst_check(imoq_match('*IN' : '1,2.5,3' : 'P' : '2.50' : n)
          : 'in: numbers compare as numbers');
  tst_check(not imoq_match('*IN' : '1,2,3' : 'P' : '4.00' : n)
          : 'in: number not listed');
  tst_check(not imoq_match('*IN' : 'PA' : 'O' : '' : c)
          : 'in: omitted never matches');
  tst_check(imoq_match('*BETWEEN' : '10,20' : 'P' : '10.00' : n)
          : 'between: low included');
  tst_check(imoq_match('*BETWEEN' : '10,20' : 'P' : '20.00' : n)
          : 'between: high included');
  tst_check(imoq_match('*BETWEEN' : '10, 20' : 'P' : '15.50' : n)
          : 'between: inside');
  tst_check(not imoq_match('*BETWEEN' : '10,20' : 'P' : '9.99' : n)
          : 'between: below');
  tst_check(not imoq_match('*BETWEEN' : '10,20' : 'P' : '20.01' : n)
          : 'between: above');
  tst_check(imoq_match('*BETWEEN' : '-5,5' : 'P' : '-5.00' : n)
          : 'between: negative numbers');
  tst_check(imoq_match('*BETWEEN' : 'B,D' : 'P' : 'C9999' : c)
          : 'between: text');
  tst_check(imoq_match('*BETWEEN' : '2026-01-01,2026-12-31' : 'P'
                       : '2026-06-30' : d) : 'between: dates');
  tst_check(not imoq_match('*BETWEEN' : '10' : 'P' : '10.00' : n)
          : 'between: one value never matches');
  tst_end();
end-proc;

dcl-proc test_numText;
  tst_begin('RPG API numbers become codec text');
  tst_eqChar('6' : imoq_numText(6) : 'whole number');
  tst_eqChar('6.5' : imoq_numText(6.50) : 'trailing zeros dropped');
  tst_eqChar('0.25' : imoq_numText(.25) : 'leading zero added');
  tst_eqChar('-0.25' : imoq_numText(-.25) : 'negative fraction');
  tst_eqChar('-100' : imoq_numText(-100) : 'negative whole number');
  tst_eqChar('0' : imoq_numText(0) : 'zero');
  tst_eqChar('0.000000001' : imoq_numText(.000000001) : 'nine decimals');
  tst_eqChar('6.50' : rt('*PACKED' : 7 : 2 : imoq_numText(6.5))
           : 'packed(7:2) accepts it');
  tst_eqChar('-3' : rt('*INT' : 10 : 0 : imoq_numText(-3))
           : 'int 10 accepts it');
  tst_eqChar('0.25' : rt('*ZONED' : 5 : 2 : imoq_numText(.25))
           : 'zoned(5:2) accepts it');
  tst_end();
end-proc;

dcl-proc test_byteSize;
  tst_begin('storage sizes of every type');
  tst_eqNum(10 : imoq_byteSize(mdef('*CHAR' : 10 : 0)) : 'char 10');
  tst_eqNum(12 : imoq_byteSize(mdef('*VARCHAR' : 10 : 0)) : 'varchar 10');
  tst_eqNum(4 : imoq_byteSize(mdef('*PACKED' : 7 : 2)) : 'packed 7,2');
  tst_eqNum(5 : imoq_byteSize(mdef('*PACKED' : 8 : 0)) : 'packed 8,0');
  tst_eqNum(9 : imoq_byteSize(mdef('*ZONED' : 9 : 2)) : 'zoned 9,2');
  tst_eqNum(1 : imoq_byteSize(mdef('*INT' : 3 : 0)) : 'int 3');
  tst_eqNum(2 : imoq_byteSize(mdef('*UNS' : 5 : 0)) : 'uns 5');
  tst_eqNum(4 : imoq_byteSize(mdef('*INT' : 10 : 0)) : 'int 10');
  tst_eqNum(8 : imoq_byteSize(mdef('*INT' : 20 : 0)) : 'int 20');
  tst_eqNum(8 : imoq_byteSize(mdef('*FLOAT' : 8 : 0)) : 'float 8');
  tst_eqNum(1 : imoq_byteSize(mdef('*IND' : 0 : 0)) : 'ind');
  tst_eqNum(10 : imoq_byteSize(mdef('*DATE' : 0 : 0)) : 'date');
  tst_eqNum(8 : imoq_byteSize(mdef('*TIME' : 0 : 0)) : 'time');
  tst_eqNum(26 : imoq_byteSize(mdef('*TIMESTAMP' : 0 : 0)) : 'timestamp');
  tst_eqNum(16 : imoq_byteSize(mdef('*PTR' : 0 : 0)) : 'pointer');
  tst_end();
end-proc;

dcl-proc test_parseField;
  dcl-s f varchar(40);
  dcl-s msg varchar(256);
  tst_begin('subfield references');
  tst_check(imoq_parseField('' : f : msg) and f = '' : 'blank: whole');
  tst_check(imoq_parseField('qty' : f : msg) and f = 'QTY'
          : 'name, uppercased: ' + f);
  tst_check(imoq_parseField(' amt( 3 ) ' : f : msg) and f = 'AMT(3)'
          : 'array element, blanks removed: ' + f);
  tst_check(imoq_parseField('CUST_NO#2' : f : msg) and f = 'CUST_NO#2'
          : 'name characters');
  tst_check(not imoq_parseField('AMT(0)' : f : msg) : 'element 0');
  tst_check(not imoq_parseField('AMT(X)' : f : msg) : 'element X');
  tst_check(not imoq_parseField('AMT(1' : f : msg) : 'unclosed');
  tst_check(not imoq_parseField('(1)' : f : msg) : 'no name');
  tst_check(not imoq_parseField('A-B' : f : msg) : 'bad character');
  tst_check(not imoq_parseField('2.QTY' : f : msg) : 'parameter prefix');
  tst_end();
end-proc;
