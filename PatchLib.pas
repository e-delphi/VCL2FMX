{$I InnovaLibDefs.inc}

unit PatchLib;

interface

uses
  System.Classes, System.UITypes,
  System.SyncObjs,
  System.IOUtils,
  System.Win.ComObj,
  System.Win.Registry,
  Winapi.Windows,
  Winapi.ShlObj,
  Winapi.ShellAPI,
  System.SysUtils;

type
  TArrayOfStrings = array of String;
  ArrayOfStrings = TArrayOfStrings;
  TArrayOfUnicodeStrings = array of UnicodeString;
  TArrayOfReal = array of real;
  TArrayofInteger = array of Integer;
  TArrayofLongWord = array of Longword;
  TArrayofObjects = array of TObject;
  TTwoDArrayofInteger = array of TArrayofInteger;
  TTwoDArrayOfString = array of ArrayOfStrings;

  StrCodeInfoRec = record
    CodePage: Word;
    ElementLength: Word;
    RefCount: Integer;
    Length: Integer;
  end;

function GetArrayFromString(const S: String; SepVal: Char; ARemoveQuote: Boolean = false; ATrim: Boolean = True; ADropNulls: Boolean = false): TArrayOfStrings; overload;
function FieldSep(var ss: PChar; SepVal: Char): String; overload;
function ReadLineFrmStream(AStream: TStream): String;
function PosNoCase(const ASubstr: String; AFullString: String): Integer; overload;
procedure PopulateStringsFromArray(AStrings: TStrings; AArray: TArrayOfStrings; AObjArray: TArrayofObjects = nil);
function CompressedUnicode(const AUCode: UnicodeString): String;
function StrCodeInfo(const S: UnicodeString): StrCodeInfoRec; overload; inline;
function StrCodeInfo(const S: RawByteString): StrCodeInfoRec; overload; inline;
function ShellExecuteDocument(const Command, Parameters, Directory: String; Visiblity: DWord = SW_RESTORE; Action: String = 'open'): Boolean;

const
  NullStrCodeInfo: StrCodeInfoRec = (CodePage: 0; ElementLength: 0; RefCount: 0;
    Length: 0);

type
  PStrCodeInfoRec = ^StrCodeInfoRec;

const
  CRLF = AnsiChar(#13) + AnsiChar(#10);
  ZSISOffset = 0;
  CR = AnsiChar(#13);
  LF = AnsiChar(#10);
  TAB = AnsiChar(#9);
  CRP = AnsiChar(#141);
  LFP = AnsiChar(#138);
  FirstStrCharNo = 1;

implementation

function GetArrayFromString(const S: String; SepVal: Char; ARemoveQuote: Boolean = false; ATrim: Boolean = True; ADropNulls: Boolean = false): TArrayOfStrings;
var
  i: Integer;
  NextChar, SecondQuoteChar: PChar;
  CSepVal: Char;
  QuoteVal: String;
  ThisS, fs: String;
begin
  SetLength(Result, 0);
  if S = '' then
    exit;
  ThisS := S;
  NextChar := @ThisS[1];
  CSepVal := SepVal;
  i := 0;
  while Pointer(NextChar) <> nil do
  begin
    if NextChar[0] = CSepVal then
    begin
      inc(NextChar);
      fs := '';
    end
    else
    if ARemoveQuote and CharInSet(NextChar[0], ['''', '"', '[', '{', '(', '<']) then
    begin
      case Char(NextChar[0]) of
        '''', '"':
          QuoteVal := NextChar[0];
        '[':
          QuoteVal := ']';
        '{':
          QuoteVal := '}';
        '(':
          QuoteVal := ')';
        '<':
          QuoteVal := '>';
      else
        QuoteVal := NextChar[0];
      end;

      SecondQuoteChar := StrPos(PChar(NextChar + 1), PChar(QuoteVal));
      if (Pointer(SecondQuoteChar) <> nil) and ((SecondQuoteChar[1] = CSepVal) or (SecondQuoteChar[1] = #0)) then
      begin
        inc(NextChar);
        if NextChar = SecondQuoteChar then
        begin
          fs := '';
          inc(NextChar);
        end
        else
          fs := FieldSep(NextChar, QuoteVal[1 + ZSISOffset]);
        if SecondQuoteChar[1] = #0 then
          NextChar := nil
        else
          inc(NextChar);
      end
      else
        fs := FieldSep(NextChar, CSepVal);
    end
    else
      fs := FieldSep(NextChar, CSepVal);
    if i > high(Result) then
      SetLength(Result, i + 6);
    if ATrim then
      Result[i] := Trim(fs)
    else
      Result[i] := fs;
    if not (ADropNulls and (Result[i] = '')) then
      Inc(i);
  end;
  SetLength(Result, i);
end;

function FieldSep(var ss: PChar; SepVal: Char): String;
var
  CharPointer: PChar;
  j: Integer;
begin
  if ss <> nil then
  begin
    if (SepVal <> AnsiChar(0)) then
      while ss[0] = SepVal do
        ss := ss + 1;
    CharPointer := StrScan(ss, SepVal);
    if CharPointer = nil then
      Result := StrPas(ss) { Last Field }
    else
    begin
      j := CharPointer - ss;
      Result := Copy(ss, 0, j);
    end;
    if CharPointer = nil then
      ss := nil
    else
      ss := CharPointer + 1;
  end
  else
    Result := '';
end;

function ReadLineFrmStream(AStream: TStream): String;
var
  CurPos, EndPos: int64;
  i, EndSZ: Integer;
  Nxt: Char;
begin
  CurPos := AStream.Position;
  EndPos := AStream.Seek(0, soFromEnd);
  AStream.Seek(CurPos, soFromBeginning);

  if 256 > EndPos - CurPos then
    EndSZ := Word(EndPos - CurPos)
  else
    EndSZ := 256; // Max Line Size
  SetLength(Result, EndSZ);
  if EndSZ < 1 then
    exit;

  i := 0;
  AStream.Read(Nxt, 1);
  while not CharInSet(Nxt, [CR, LF, CRP, LFP]) and (i < EndSZ) do
  try
    inc(i);
    Result[i] := Nxt;
    AStream.Read(Nxt, 1);
  except
    Nxt := CR;
  end;
  SetLength(Result, i);
  while CharInSet(Nxt, [CR, LF, CRP, LFP]) and (AStream.Position < EndPos) do
    AStream.Read(Nxt, 1);
  CurPos := AStream.Position;
  if CurPos < EndPos then
    AStream.seek(CurPos - 1, soFromBeginning);
end;

function PosNoCase(const ASubstr: String; AFullString: String): Integer;
var
  Substr: String;
  S: String;
begin
  if (ASubstr = '') or (AFullString = '') then
  begin
    Result := -1;
    exit;
  end;
  Substr := Lowercase(ASubstr);
  S := Lowercase(AFullString);
  Result := Pos(Substr, S);
end;

procedure PopulateStringsFromArray(AStrings: TStrings; AArray: TArrayOfStrings; AObjArray: TArrayofObjects);
var
  i, ObjMx: Integer;
begin
  if AStrings = nil then
    raise Exception.Create('PopulateStringsFromArray');
  AStrings.Clear;
  if AObjArray = nil then
    ObjMx := -1
  else
    ObjMx := high(AObjArray);
  for i := 0 to high(AArray) do
    if i > ObjMx then
      AStrings.Add(AArray[i])
    else
      AStrings.AddObject(AArray[i], AObjArray[i]);
end;

function CompressedUnicode(const AUCode: UnicodeString): String;
var
  Ri, Ui: Integer;
  Nxt, Dest: PAnsiChar;
  R: StrCodeInfoRec;
begin
  R := StrCodeInfo(AUCode);
  if R.Length < 1 then
    Result := ''
  else
  begin
    if R.CodePage <> DefaultUnicodeCodePage then
      raise Exception.Create('Non Unicode Unicode');
    SetLength(Result, R.Length);
    Nxt := @AUCode[1];
    Dest := @Result[1];
    Ri := 0;
    Ui := 0;
    while (Nxt[Ui + 1] = AnsiChar(0)) and (Ri < R.Length) do
    begin
      Dest[Ri] := Nxt[Ui];
      inc(Ui, 2);
      inc(Ri);
    end;
    if Ri < R.Length then
      Result := '';
  end;
end;

function StrCodeInfo(const S: UnicodeString): StrCodeInfoRec; overload; inline;
var
  AtS: NativeInt;
begin
  AtS := NativeInt(S);
  if AtS = 0 then
    Result := NullStrCodeInfo
  else
    Result := PStrCodeInfoRec(AtS - 12)^
end;

function StrCodeInfo(const S: RawByteString): StrCodeInfoRec; overload; inline;
var
  AtS: NativeInt;
begin
  AtS := NativeInt(S);
  if AtS = 0 then
    Result := NullStrCodeInfo
  else
    Result := PStrCodeInfoRec(AtS - 12)^
end;

function ShellExecuteDocumentRetError(const Command, Parameters, Directory: String; Visiblity: DWord; Action: String): DWord;
var
  lpParameters, lpDirectory, lpOperation: PChar;
  LocalAction: String;
begin
  if Action = '' then
    LocalAction := 'open'
  else
    LocalAction := lowercase(Action);
  lpOperation := PChar(LocalAction);
  if Parameters = '' then
    lpParameters := nil
  else
    lpParameters := @Parameters[1];
  if Directory = '' then
    lpDirectory := nil
  else
    lpDirectory := @Directory[1];
  Result := ShellExecuteA(0,
    PAnsiChar(lpOperation),
    @Command[1],
    PAnsiChar(lpParameters),
    PAnsiChar(lpDirectory),
    Visiblity);
end;

function ShellExecuteDocument(const Command, Parameters, Directory: String; Visiblity: DWord; Action: String): Boolean;
var
  Return: DWord;
begin
  Return := ShellExecuteDocumentRetError(Command, Parameters, Directory, Visiblity, Action);
  Result := Return > 32;
end;

end.
