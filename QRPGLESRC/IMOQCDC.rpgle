**free
// ------------------------------------------------------------------
// IMOQCDC - iMoq codec: typed buffer <-> text, argument matchers
// Module of service program IMOQENG.
// ------------------------------------------------------------------
ctl-opt nomain option(*srcstmt:*nodebugio) decprec(63);

/copy QTEMP/IMOQINC,IMOQENG_H

dcl-c DIGITS '0123456789';
dcl-c HEXCH '0123456789ABCDEF';
dcl-c ZEROS '000000000000000000000000000000000000000000000000000000000000000';
dcl-c LOWER 'abcdefghijklmnopqrstuvwxyz';
dcl-c UPPER 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

// ==================================================================
// imoq_normDef - validate a layout and apply default lengths
// ==================================================================
dcl-proc imoq_normDef export;
  dcl-pi *n ind;
    def likeds(imoq_def_t);
    msg varchar(256);
  end-pi;

  msg = '';
  def.type = %xlate(LOWER : UPPER : def.type);
  def.passing = %xlate(LOWER : UPPER : def.passing);
  if def.passing = ' ';
    def.passing = '*REF';
  endif;
  if def.passing <> '*REF' and def.passing <> '*CONST'
     and def.passing <> '*VALUE';
    msg = 'Passing must be *REF, *CONST or *VALUE';
    return *off;
  endif;

  select;
  when def.type = '*CHAR' or def.type = '*VARCHAR';
    if def.len < 1 or def.len > 16000000;
      msg = %trim(def.type) + ' needs a length between 1 and 16000000';
      return *off;
    endif;
    def.dec = 0;
  when def.type = '*PACKED' or def.type = '*ZONED';
    if def.len < 1 or def.len > 63;
      msg = %trim(def.type) + ' needs 1 to 63 digits';
      return *off;
    endif;
    if def.dec < 0 or def.dec > def.len;
      msg = %trim(def.type) + ' decimal positions must be 0 to '
          + %char(def.len);
      return *off;
    endif;
  when def.type = '*INT' or def.type = '*UNS';
    if def.len = 0;
      def.len = 10;
    endif;
    if def.len <> 3 and def.len <> 5 and def.len <> 10 and def.len <> 20;
      msg = %trim(def.type) + ' length must be 3, 5, 10 or 20';
      return *off;
    endif;
    def.dec = 0;
  when def.type = '*FLOAT';
    if def.len = 0;
      def.len = 8;
    endif;
    if def.len <> 4 and def.len <> 8;
      msg = '*FLOAT length must be 4 or 8';
      return *off;
    endif;
    def.dec = 0;
  when def.type = '*IND';
    def.len = 1;
    def.dec = 0;
  when def.type = '*DATE';
    def.len = 10;
    def.dec = 0;
  when def.type = '*TIME';
    def.len = 8;
    def.dec = 0;
  when def.type = '*TIMESTAMP';
    def.len = 26;
    def.dec = 0;
  when def.type = '*PTR';
    def.len = 16;
    def.dec = 0;
  other;
    msg = 'Unknown type ' + %trim(def.type);
    return *off;
  endsl;

  if def.passing = '*VALUE' and def.type = '*VARCHAR';
    msg = '*VARCHAR cannot be passed *VALUE by iMoq stubs';
    return *off;
  endif;
  return *on;
end-proc;

// ==================================================================
// imoq_isNumeric
// ==================================================================
dcl-proc imoq_isNumeric export;
  dcl-pi *n ind;
    type char(10) const;
  end-pi;
  return type = '*PACKED' or type = '*ZONED' or type = '*INT'
      or type = '*UNS' or type = '*FLOAT';
end-proc;

// ==================================================================
// imoq_byteSize - storage bytes of a (normalized) layout
// ==================================================================
dcl-proc imoq_byteSize export;
  dcl-pi *n int(10);
    def likeds(imoq_def_t) const;
  end-pi;

  select;
  when def.type = '*CHAR';
    return def.len;
  when def.type = '*VARCHAR';
    if def.len > 65535;
      return def.len + 4;
    endif;
    return def.len + 2;
  when def.type = '*PACKED';
    return %div(def.len : 2) + 1;
  when def.type = '*ZONED';
    return def.len;
  when def.type = '*INT' or def.type = '*UNS';
    select;
    when def.len = 3;
      return 1;
    when def.len = 5;
      return 2;
    when def.len = 10;
      return 4;
    endsl;
    return 8;
  when def.type = '*FLOAT';
    return def.len;
  when def.type = '*IND';
    return 1;
  when def.type = '*DATE';
    return 10;
  when def.type = '*TIME';
    return 8;
  when def.type = '*TIMESTAMP';
    return 26;
  when def.type = '*PTR';
    return 16;
  endsl;
  return 0;
end-proc;

// ==================================================================
// imoq_validMatcher
// ==================================================================
dcl-proc imoq_validMatcher export;
  dcl-pi *n ind;
    matcher char(10) const;
  end-pi;
  return matcher = '*ANY' or matcher = '*EQ' or matcher = '*NE'
      or matcher = '*GT' or matcher = '*GE' or matcher = '*LT'
      or matcher = '*LE' or matcher = '*LIKE' or matcher = '*BLANK'
      or matcher = '*OMIT' or matcher = '*NOTPASSED';
end-proc;

// ==================================================================
// imoq_rpgType - RPG free-form data type keyword for a layout
// ==================================================================
dcl-proc imoq_rpgType export;
  dcl-pi *n varchar(64);
    def likeds(imoq_def_t) const;
  end-pi;

  select;
  when def.type = '*CHAR';
    return 'char(' + %char(def.len) + ')';
  when def.type = '*VARCHAR';
    if def.len > 65535;
      return 'varchar(' + %char(def.len) + ':4)';
    endif;
    return 'varchar(' + %char(def.len) + ')';
  when def.type = '*PACKED';
    return 'packed(' + %char(def.len) + ':' + %char(def.dec) + ')';
  when def.type = '*ZONED';
    return 'zoned(' + %char(def.len) + ':' + %char(def.dec) + ')';
  when def.type = '*INT';
    return 'int(' + %char(def.len) + ')';
  when def.type = '*UNS';
    return 'uns(' + %char(def.len) + ')';
  when def.type = '*FLOAT';
    return 'float(' + %char(def.len) + ')';
  when def.type = '*IND';
    return 'ind';
  when def.type = '*DATE';
    return 'date(*iso)';
  when def.type = '*TIME';
    return 'time(*iso)';
  when def.type = '*TIMESTAMP';
    return 'timestamp';
  when def.type = '*PTR';
    return 'pointer';
  endsl;
  return 'char(1)';
end-proc;

// ==================================================================
// imoq_decode - render the value at ptr as text
// ==================================================================
dcl-proc imoq_decode export;
  dcl-pi *n varchar(1024);
    ptr pointer value;
    def likeds(imoq_def_t) const;
  end-pi;

  dcl-s chr char(1024) based(ptr);
  dcl-s dataPtr pointer;
  dcl-s data char(1024) based(dataPtr);
  dcl-s len2 uns(5) based(ptr);
  dcl-s len4 uns(10) based(ptr);
  dcl-s i3 int(3) based(ptr);
  dcl-s i5 int(5) based(ptr);
  dcl-s i10 int(10) based(ptr);
  dcl-s i20 int(20) based(ptr);
  dcl-s u3 uns(3) based(ptr);
  dcl-s u5 uns(5) based(ptr);
  dcl-s u10 uns(10) based(ptr);
  dcl-s u20 uns(20) based(ptr);
  dcl-s f4 float(4) based(ptr);
  dcl-s f8 float(8) based(ptr);
  dcl-s pp pointer based(ptr);
  dcl-s n int(10);

  if ptr = *null;
    return '*NULL';
  endif;

  monitor;
    select;
    when def.type = '*CHAR' or def.type = '*IND' or def.type = '*DATE'
         or def.type = '*TIME' or def.type = '*TIMESTAMP';
      n = def.len;
      if n > 1024;
        n = 1024;
      endif;
      return %trimr(%subst(chr : 1 : n));

    when def.type = '*VARCHAR';
      if def.len > 65535;
        n = len4;
        dataPtr = ptr + 4;
      else;
        n = len2;
        dataPtr = ptr + 2;
      endif;
      if n > def.len;
        return '*INVALID';
      endif;
      if n > 1024;
        n = 1024;
      endif;
      if n = 0;
        return '';
      endif;
      return %subst(data : 1 : n);

    when def.type = '*PACKED';
      return decodePacked(ptr : def);

    when def.type = '*ZONED';
      return decodeZoned(ptr : def);

    when def.type = '*INT';
      select;
      when def.len = 3;
        return %char(i3);
      when def.len = 5;
        return %char(i5);
      when def.len = 10;
        return %char(i10);
      other;
        return %char(i20);
      endsl;

    when def.type = '*UNS';
      select;
      when def.len = 3;
        return %char(u3);
      when def.len = 5;
        return %char(u5);
      when def.len = 10;
        return %char(u10);
      other;
        return %char(u20);
      endsl;

    when def.type = '*FLOAT';
      if def.len = 4;
        return %char(f4);
      endif;
      return %char(f8);

    when def.type = '*PTR';
      if pp = *null;
        return '*NULL';
      endif;
      return '*NOTNULL';
    endsl;
  on-error;
    return '*INVALID';
  endmon;

  return '*UNDECLARED';
end-proc;

// ==================================================================
// imoq_encode - store text into the typed buffer at ptr
// ==================================================================
dcl-proc imoq_encode export;
  dcl-pi *n ind;
    ptr pointer value;
    def likeds(imoq_def_t) const;
    text varchar(1024) const;
    msg varchar(256);
  end-pi;

  dcl-s big char(16000000) based(ptr);
  dcl-s dataPtr pointer;
  dcl-s data char(16000000) based(dataPtr);
  dcl-s len2 uns(5) based(ptr);
  dcl-s len4 uns(10) based(ptr);
  dcl-s i3 int(3) based(ptr);
  dcl-s i5 int(5) based(ptr);
  dcl-s i10 int(10) based(ptr);
  dcl-s i20 int(20) based(ptr);
  dcl-s u3 uns(3) based(ptr);
  dcl-s u5 uns(5) based(ptr);
  dcl-s u10 uns(10) based(ptr);
  dcl-s u20 uns(20) based(ptr);
  dcl-s f4 float(4) based(ptr);
  dcl-s f8 float(8) based(ptr);
  dcl-s pp pointer based(ptr);
  dcl-s n int(10);
  dcl-s t varchar(1024);
  dcl-s wrkDate date;
  dcl-s wrkTime time;
  dcl-s wrkTs timestamp;
  dcl-s digs varchar(63);
  dcl-s neg ind;

  msg = '';
  if ptr = *null;
    msg = 'Parameter storage is not addressable';
    return *off;
  endif;
  t = %trim(text);

  monitor;
    select;
    when def.type = '*CHAR';
      n = %len(text);
      if n > def.len;
        n = def.len;
      endif;
      %subst(big : 1 : def.len) = *blanks;
      if n > 0;
        %subst(big : 1 : n) = %subst(text : 1 : n);
      endif;

    when def.type = '*VARCHAR';
      n = %len(text);
      if n > def.len;
        n = def.len;
      endif;
      if def.len > 65535;
        len4 = n;
        dataPtr = ptr + 4;
      else;
        len2 = n;
        dataPtr = ptr + 2;
      endif;
      if n > 0;
        %subst(data : 1 : n) = %subst(text : 1 : n);
      endif;

    when def.type = '*PACKED' or def.type = '*ZONED';
      if not parseNum(t : def.len : def.dec : digs : neg);
        msg = '''' + t + ''' is not valid for ' + imoq_rpgType(def);
        return *off;
      endif;
      if def.type = '*PACKED';
        encodePacked(ptr : def : digs : neg);
      else;
        encodeZoned(ptr : def : digs : neg);
      endif;

    when def.type = '*INT';
      select;
      when def.len = 3;
        i3 = %int(t);
      when def.len = 5;
        i5 = %int(t);
      when def.len = 10;
        i10 = %int(t);
      other;
        i20 = %int(t);
      endsl;

    when def.type = '*UNS';
      select;
      when def.len = 3;
        u3 = %uns(t);
      when def.len = 5;
        u5 = %uns(t);
      when def.len = 10;
        u10 = %uns(t);
      other;
        u20 = %uns(t);
      endsl;

    when def.type = '*FLOAT';
      if def.len = 4;
        f4 = %float(t);
      else;
        f8 = %float(t);
      endif;

    when def.type = '*IND';
      t = %xlate(LOWER : UPPER : t);
      if t = '1' or t = '*ON';
        %subst(big : 1 : 1) = '1';
      elseif t = '0' or t = '*OFF' or t = '';
        %subst(big : 1 : 1) = '0';
      else;
        msg = '''' + t + ''' is not a valid indicator (use 1/0)';
        return *off;
      endif;

    when def.type = '*DATE';
      wrkDate = %date(t : *iso);
      %subst(big : 1 : 10) = %char(wrkDate : *iso);

    when def.type = '*TIME';
      wrkTime = %time(t : *iso);
      %subst(big : 1 : 8) = %char(wrkTime : *iso);

    when def.type = '*TIMESTAMP';
      wrkTs = %timestamp(t : *iso);
      %subst(big : 1 : 26) = %char(wrkTs : *iso);

    when def.type = '*PTR';
      if %xlate(LOWER : UPPER : t) <> '*NULL';
        msg = 'Only *NULL can be assigned to a pointer';
        return *off;
      endif;
      pp = *null;

    other;
      msg = 'Unknown type ' + %trim(def.type);
      return *off;
    endsl;
  on-error;
    msg = '''' + t + ''' is not valid for ' + imoq_rpgType(def);
    return *off;
  endmon;

  return *on;
end-proc;

// ==================================================================
// imoq_match - does an actual argument satisfy a matcher?
//   state: P = passed, O = *OMIT (null address), N = not passed
// ==================================================================
dcl-proc imoq_match export;
  dcl-pi *n ind;
    matcher char(10) const;
    expected varchar(1024) const;
    state char(1) const;
    actual varchar(1024) const;
    def likeds(imoq_def_t) const;
  end-pi;

  dcl-s rc int(10);

  select;
  when matcher = '*ANY';
    return *on;
  when matcher = '*OMIT';
    return state = 'O';
  when matcher = '*NOTPASSED';
    return state = 'N';
  endsl;

  if state <> 'P';
    return *off;
  endif;

  if matcher = '*LIKE';
    return likeMatch(%trimr(actual) : %trimr(expected));
  endif;

  if matcher = '*BLANK';
    if imoq_isNumeric(def.type);
      return compareNum(actual : '0' : def) = 0;
    endif;
    return %trim(actual) = '';
  endif;

  if imoq_isNumeric(def.type);
    rc = compareNum(actual : expected : def);
    if rc = -2;
      return *off;
    endif;
  else;
    if %trimr(actual) = %trimr(expected);
      rc = 0;
    elseif %trimr(actual) < %trimr(expected);
      rc = -1;
    else;
      rc = 1;
    endif;
  endif;

  select;
  when matcher = '*EQ';
    return rc = 0;
  when matcher = '*NE';
    return rc <> 0;
  when matcher = '*GT';
    return rc = 1;
  when matcher = '*GE';
    return rc >= 0;
  when matcher = '*LT';
    return rc = -1;
  when matcher = '*LE';
    return rc <= 0;
  endsl;
  return *off;
end-proc;

// ------------------------------------------------------------------
// compareNum - -1/0/1, or -2 when either side is not numeric
// ------------------------------------------------------------------
dcl-proc compareNum;
  dcl-pi *n int(10);
    a varchar(1024) const;
    b varchar(1024) const;
    def likeds(imoq_def_t) const;
  end-pi;

  dcl-s da packed(63:20);
  dcl-s db packed(63:20);
  dcl-s fa float(8);
  dcl-s fb float(8);

  monitor;
    if def.type = '*FLOAT';
      fa = %float(%trim(a));
      fb = %float(%trim(b));
      if fa = fb;
        return 0;
      elseif fa < fb;
        return -1;
      endif;
      return 1;
    endif;
    da = %dec(%trim(a) : 63 : 20);
    db = %dec(%trim(b) : 63 : 20);
  on-error;
    return -2;
  endmon;

  if da = db;
    return 0;
  elseif da < db;
    return -1;
  endif;
  return 1;
end-proc;

// ------------------------------------------------------------------
// likeMatch - SQL LIKE semantics: % any string, _ any character
// ------------------------------------------------------------------
dcl-proc likeMatch;
  dcl-pi *n ind;
    s varchar(1024) const;
    p varchar(1024) const;
  end-pi;

  dcl-s si int(10) inz(1);
  dcl-s px int(10) inz(1);
  dcl-s star int(10) inz(0);
  dcl-s mark int(10) inz(0);
  dcl-s sl int(10);
  dcl-s pl int(10);
  dcl-s pc char(1);

  sl = %len(s);
  pl = %len(p);

  dow si <= sl;
    if px <= pl;
      pc = %subst(p : px : 1);
    else;
      pc = x'00';
    endif;
    if px <= pl and pc <> '%'
       and (pc = '_' or pc = %subst(s : si : 1));
      si += 1;
      px += 1;
    elseif px <= pl and pc = '%';
      star = px;
      mark = si;
      px += 1;
    elseif star > 0;
      px = star + 1;
      mark += 1;
      si = mark;
    else;
      return *off;
    endif;
  enddo;

  dow px <= pl;
    if %subst(p : px : 1) <> '%';
      leave;
    endif;
    px += 1;
  enddo;
  return px > pl;
end-proc;

// ------------------------------------------------------------------
// parseNum - text -> right-aligned digit string of len digits
// ------------------------------------------------------------------
dcl-proc parseNum;
  dcl-pi *n ind;
    text varchar(1024) const;
    len int(10) const;
    dec int(10) const;
    digs varchar(63);
    neg ind;
  end-pi;

  dcl-s t varchar(1024);
  dcl-s ip varchar(1024);
  dcl-s fp varchar(1024);
  dcl-s p int(10);

  t = %trim(text);
  neg = *off;
  digs = '';
  if %len(t) = 0;
    return *off;
  endif;
  if %subst(t : 1 : 1) = '-';
    neg = *on;
    t = %subst(t : 2);
  elseif %subst(t : 1 : 1) = '+';
    t = %subst(t : 2);
  endif;
  if %len(t) = 0;
    return *off;
  endif;

  p = %scan('.' : t);
  if p > 0;
    if p > 1;
      ip = %subst(t : 1 : p - 1);
    else;
      ip = '';
    endif;
    if p < %len(t);
      fp = %subst(t : p + 1);
    else;
      fp = '';
    endif;
  else;
    ip = t;
    fp = '';
  endif;

  if (%len(ip) > 0 and %check(DIGITS : ip) > 0)
     or (%len(fp) > 0 and %check(DIGITS : fp) > 0)
     or (%len(ip) = 0 and %len(fp) = 0);
    return *off;
  endif;

  // strip leading zeros from the integer part
  p = %check('0' : ip);
  if p = 0;
    ip = '';
  elseif p > 1;
    ip = %subst(ip : p);
  endif;

  // fit the fraction to dec positions (truncate)
  if %len(fp) > dec;
    if dec = 0;
      fp = '';
    else;
      fp = %subst(fp : 1 : dec);
    endif;
  elseif %len(fp) < dec;
    fp += %subst(ZEROS : 1 : dec - %len(fp));
  endif;

  if %len(ip) > len - dec;
    return *off;
  endif;

  if len - dec - %len(ip) > 0;
    digs = %subst(ZEROS : 1 : len - dec - %len(ip));
  endif;
  digs += ip + fp;
  if %check('0' : digs) = 0;
    neg = *off;
  endif;
  return *on;
end-proc;

// ------------------------------------------------------------------
// formatNum - digit string -> display text (-123.45)
// ------------------------------------------------------------------
dcl-proc formatNum;
  dcl-pi *n varchar(1024);
    digs varchar(63) const;
    dec int(10) const;
    neg ind const;
  end-pi;

  dcl-s ip varchar(63);
  dcl-s fp varchar(63);
  dcl-s res varchar(1024);
  dcl-s intLen int(10);
  dcl-s p int(10);

  intLen = %len(digs) - dec;
  if intLen > 0;
    ip = %subst(digs : 1 : intLen);
  else;
    ip = '';
  endif;
  if dec > 0;
    fp = %subst(digs : intLen + 1 : dec);
  endif;

  p = %check('0' : ip);
  if p = 0;
    ip = '0';
  else;
    ip = %subst(ip : p);
  endif;

  res = ip;
  if dec > 0;
    res += '.' + fp;
  endif;
  if neg and %check('0' : digs) > 0;
    res = '-' + res;
  endif;
  return res;
end-proc;

// ------------------------------------------------------------------
// Packed decimal
// ------------------------------------------------------------------
dcl-proc decodePacked;
  dcl-pi *n varchar(1024);
    ptr pointer value;
    def likeds(imoq_def_t) const;
  end-pi;

  dcl-s bp pointer;
  dcl-s b uns(3) based(bp);
  dcl-s nib varchar(128);
  dcl-s digs varchar(128);
  dcl-s sign char(1);
  dcl-s bytes int(10);
  dcl-s i int(10);

  bytes = %div(def.len : 2) + 1;
  for i = 0 to bytes - 1;
    bp = ptr + i;
    nib += %subst(HEXCH : %div(b : 16) + 1 : 1)
         + %subst(HEXCH : %rem(b : 16) + 1 : 1);
  endfor;
  sign = %subst(nib : %len(nib) : 1);
  digs = %subst(nib : 1 : %len(nib) - 1);
  digs = %subst(digs : %len(digs) - def.len + 1);

  if %check(DIGITS : digs) > 0 or %scan(sign : 'ABCDEF') = 0;
    return '*INVALID';
  endif;
  return formatNum(digs : def.dec : sign = 'B' or sign = 'D');
end-proc;

dcl-proc encodePacked;
  dcl-pi *n;
    ptr pointer value;
    def likeds(imoq_def_t) const;
    digs varchar(63) const;
    neg ind const;
  end-pi;

  dcl-s bp pointer;
  dcl-s b uns(3) based(bp);
  dcl-s s varchar(128);
  dcl-s bytes int(10);
  dcl-s i int(10);
  dcl-s hi int(10);
  dcl-s lo int(10);

  s = digs;
  if %rem(def.len : 2) = 0;
    s = '0' + s;
  endif;
  if neg;
    s += 'D';
  else;
    s += 'F';
  endif;

  bytes = %div(def.len : 2) + 1;
  for i = 0 to bytes - 1;
    hi = %scan(%subst(s : i * 2 + 1 : 1) : HEXCH) - 1;
    lo = %scan(%subst(s : i * 2 + 2 : 1) : HEXCH) - 1;
    bp = ptr + i;
    b = hi * 16 + lo;
  endfor;
end-proc;

// ------------------------------------------------------------------
// Zoned decimal
// ------------------------------------------------------------------
dcl-proc decodeZoned;
  dcl-pi *n varchar(1024);
    ptr pointer value;
    def likeds(imoq_def_t) const;
  end-pi;

  dcl-s bp pointer;
  dcl-s b uns(3) based(bp);
  dcl-s digs varchar(63);
  dcl-s i int(10);
  dcl-s zone int(10);
  dcl-s dig int(10);
  dcl-s neg ind;

  for i = 0 to def.len - 1;
    bp = ptr + i;
    zone = %div(b : 16);
    dig = %rem(b : 16);
    if dig > 9;
      return '*INVALID';
    endif;
    digs += %subst(DIGITS : dig + 1 : 1);
    if i < def.len - 1;
      if zone <> 15;
        return '*INVALID';
      endif;
    else;
      if zone < 10;
        return '*INVALID';
      endif;
      neg = zone = 11 or zone = 13;
    endif;
  endfor;
  return formatNum(digs : def.dec : neg);
end-proc;

dcl-proc encodeZoned;
  dcl-pi *n;
    ptr pointer value;
    def likeds(imoq_def_t) const;
    digs varchar(63) const;
    neg ind const;
  end-pi;

  dcl-s bp pointer;
  dcl-s b uns(3) based(bp);
  dcl-s i int(10);
  dcl-s dig int(10);

  for i = 0 to def.len - 1;
    dig = %scan(%subst(digs : i + 1 : 1) : DIGITS) - 1;
    bp = ptr + i;
    if i = def.len - 1 and neg;
      b = 13 * 16 + dig;
    else;
      b = 15 * 16 + dig;
    endif;
  endfor;
end-proc;
