unit CvtrObj;

interface

uses
  PatchLib,
  System.Classes,
  System.Types,
  System.SysUtils,
  System.StrUtils,
  Contnrs,
  Winapi.Windows,
  inifiles,
  FMX.Objects,
  System.Generics.Collections,
  Image,
  ImageList;

type
  TLinkControl = record
    DataSource : String;
    FieldName : String;
    Control : String;
  end;

  TLinkGridColumn = record
    Caption : String;
    FieldName : String;
    Width : String;
  end;

  TLinkGrid = record
    DataSource : String;
    GridControl : String;
    Columns : TArray<TLinkGridColumn>;
  end;

  TDfmToFmxObject = class(TObject)
  private
    FLinkControlList: TArray<TLinkControl>;
    FLinkGridList: TArray<TLinkGrid>;
    FDFMClass: String;
    FObjName: String;
    FOwnedObjs: TObjectList;
    FOwnedItems: TObjectList;
    FDepth: integer;
    F2DPropertyArray: TTwoDArrayOfString;
    FPropertyArraySz, FPropertyMax: integer;
    FIniReplaceValues,
    FIniIncludeValues,
    FIniSectionValues,
    FIniAddProperties,
    FUsesTranslation,
    FIniObjectTranslations: TStringlist;
    function OwnedObjs: TObjectList;
    function IniObjectTranslations: TStringList;
    function IniSectionValues: TStringlist;
    function UsesTranslation: TStringlist;
    function IniReplaceValues: TStringlist;
    function IniIncludeValues: TStringlist;
    function IniAddProperties: TStringlist;
    function PropertyArray(ARow: integer): TArrayOfStrings;
    procedure UpdateUsesStringList(AUsesList: TStrings);
    procedure ReadProperties(AData: String; AStm: TStream; var AIdx: Integer);
    function ProcessUsesString(AOrigUsesArray: TArrayOfStrings): String;
    function ProcessCodeBody(const ACodeBody: String): String;
    procedure IniFileLoad(AIni: TIniFile);
    procedure ReadItems(Prop: TTwoDArrayOfString; APropertyIdx: integer; AStm: TStream);
    function FMXClass: String;
    function TransformProperty(ACurrentName, ACurrentValue: String; APad: String = ''): String;
    function AddArrayOfItemProperties(APropertyIdx: Integer; APad: String): String;
    function FMXProperties(APad: String): String;
    function FMXSubObjects(APad: String): String;
    procedure ReadData(Prop: TTwoDArrayOfString; APropertyIdx: integer; AStm: TStream);
    function GetFMXLiveBindings: String;
    function GetPASLiveBindings: String;
    procedure ReadText(Prop: TTwoDArrayOfString; APropertyIdx: integer; AStm: TStream);
  public
    constructor Create(ACreateText: String; AStm: TStream; ADepth: integer);
    destructor Destroy; override;
    procedure LoadInfileDefs(AIniFileName: String);
    class function DFMIsTextBased(ADfmFileName: String): Boolean;
    function GenPasFile(const APascalSourceFileName: String): AnsiString;
    function FMXFile(APad: String = ''): String;
    function WriteFMXToFile(const AFmxFileName: String): Boolean;
    function WritePasToFile(const APasOutFileName, APascalSourceFileName: String): Boolean;
    procedure LiveBindings(DfmObject: TObjectList = nil);
  end;

  TDfmToFmxListItem = class(TDfmToFmxObject)
    FHasMore:Boolean;
    FPropertyIndex:Integer;
    FOwner:TDfmToFmxObject;
    public
      constructor Create(AOwner:TDfmToFmxObject;APropertyIdx: integer; AStm: TStream;ADepth: integer);
      property HasMore: Boolean read FHasMore;
    end;

implementation

const
  ContinueCode: String = '#$Continue$#';

{ DfmToFmxObject }

{ Eduardo }
procedure TDfmToFmxObject.LiveBindings(DfmObject: TObjectList = nil);
var
  I,J,K,L,M: Integer;
  sProp: String;
  sFields: String;
  obj: TDfmToFmxObject;
  bItem: Boolean;
  sItem: String;
  slItem: TStringDynArray;
begin
  // Se não informou um objeto, obtem o inicial
  if DfmObject = nil then
    DfmObject := FOwnedObjs;

  // Passa por todos objetos filhos
  for I := 0 to Pred(DfmObject.Count) do
  begin
    // Se for de conversão
    if DfmObject[I] is TDfmToFmxObject then
    begin
      // Obtem o objeto
      obj := TDfmToFmxObject(DfmObject[I]);

      // Se for uma grid
      if obj.FDFMClass.Equals('TDBGrid') then
      begin
        // Inicializa
        sFields := EmptyStr;

        // Cria um novo item na lista de grids
        SetLength(FLinkGridList, Succ(Length(FLinkGridList)));

        // Insere o nome da grid
        FLinkGridList[Pred(Length(FLinkGridList))].GridControl := obj.FObjName;

        // Passa por todas propriedades da grid
        for J := Low(F2DPropertyArray) to High(F2DPropertyArray) do
        begin
          // Obtem os dados do DataSource
          if obj.F2DPropertyArray[J, 0].Equals('DataSource') then
            FLinkGridList[Pred(Length(FLinkGridList))].DataSource := obj.F2DPropertyArray[J, 1];

          // Se for as colunas
          if obj.F2DPropertyArray[J, 0].Equals('Columns') then
          begin
            // Obtem os dados dos fields
            bItem := False;
            sFields := obj.F2DPropertyArray[J, 1];

            slItem := SplitString(sFields, #13);
            for sItem in slItem do
            begin
              if sItem = 'item' then
                SetLength(FLinkGridList[Pred(Length(FLinkGridList))].Columns, Succ(Length(FLinkGridList[Pred(Length(FLinkGridList))].Columns)))
              else
              if Trim(SplitString(sItem, '=')[0]) = 'Title.Caption' then
                FLinkGridList[Pred(Length(FLinkGridList))].Columns[Pred(Length(FLinkGridList[Pred(Length(FLinkGridList))].Columns))].Caption := Trim(SplitString(sItem, '=')[1])
              else
              if Trim(SplitString(sItem, '=')[0]) = 'FieldName' then
                FLinkGridList[Pred(Length(FLinkGridList))].Columns[Pred(Length(FLinkGridList[Pred(Length(FLinkGridList))].Columns))].FieldName := Trim(SplitString(sItem, '=')[1])
              else
              if Trim(SplitString(sItem, '=')[0]) = 'Width' then
                FLinkGridList[Pred(Length(FLinkGridList))].Columns[Pred(Length(FLinkGridList[Pred(Length(FLinkGridList))].Columns))].Width := Trim(SplitString(sItem, '=')[1]);
            end;
          end;
          
          // Se ja encontrou tudo, sai do loop
          if not FLinkGridList[Pred(Length(FLinkGridList))].DataSource.IsEmpty and not sFields.IsEmpty then
            Break;
        end;
      end;

      // Se for um dbedit
      if obj.FDFMClass.Equals('TDBEdit') then
      begin
        // Cria um novo item na lista de dbedits
        SetLength(FLinkControlList, Succ(Length(FLinkControlList)));

        // Insere o nome do dbedit
        FLinkControlList[Pred(Length(FLinkControlList))].Control := obj.FObjName;

        // Passa por todas propriedades do dbedit
        for J := Low(F2DPropertyArray) to High(F2DPropertyArray) do
        begin
          // Obtem os dados do DataSource
          if obj.F2DPropertyArray[J, 0].Equals('DataSource') then
            FLinkControlList[Pred(Length(FLinkControlList))].DataSource := obj.F2DPropertyArray[J, 1];

          // Obtem os dados do field
          if obj.F2DPropertyArray[J, 0].Equals('DataField') then
            FLinkControlList[Pred(Length(FLinkControlList))].FieldName := GetArrayFromString(obj.F2DPropertyArray[J, 1], '=', True, True)[0];

          // Se ja encontrou tudo, sai do loop
          if not FLinkControlList[Pred(Length(FLinkControlList))].DataSource.IsEmpty and not FLinkControlList[Pred(Length(FLinkControlList))].FieldName.IsEmpty then
            Break;
        end;
      end;

      // Se o componente atual possui componentes nele, faz recursão
      if Assigned(obj.FOwnedObjs) and (obj.FOwnedObjs.Count > 0) then
        LiveBindings(obj.FOwnedObjs);
    end;
  end;
end;

{ Eduardo }
function TDfmToFmxObject.GetFMXLiveBindings: String;
var
  I: Integer;
  J: Integer;
begin
  if (Length(FLinkControlList) = 0) and (Length(FLinkGridList) = 0) then
    Exit(EmptyStr);

  // Adiciona BindingsList
  Result :=
        '  object BindingsList: TBindingsList '+
  CRLF +'    Methods = <> '+
  CRLF +'    OutputConverters = <> '+
  CRLF +'    Left = 20 '+
  CRLF +'    Top = 5 ';

  // Passa pela lista de controles
  for I := 0 to High(FLinkControlList) do
  begin
    Result := Result +
    CRLF +'    object LinkControlToField'+ I.ToString +': TLinkControlToField '+
    CRLF +'      Category = '+ QuotedStr('Quick Bindings') +
    CRLF +'      DataSource = '+ FLinkControlList[I].DataSource +
    CRLF +'      FieldName = '+ QuotedStr(FLinkControlList[I].FieldName) +
    CRLF +'      Control = '+ FLinkControlList[I].Control +
    CRLF +'      Track = False '+
    CRLF +'    end ';
  end;

  // Passa pela lista de grids
  for I := 0 to High(FLinkGridList) do
  begin
    Result := Result +
    CRLF +'    object LinkGridToDataSourceBindSourceDB'+ I.ToString +': TLinkGridToDataSource '+
    CRLF +'      Category = '+ QuotedStr('Quick Bindings') +
    CRLF +'      DataSource = '+ FLinkGridList[I].DataSource +
    CRLF +'      GridControl = '+ FLinkGridList[I].GridControl +
    CRLF +'      Columns = < ';

    // Passa pela lista de colunas da grid
    for J := 0 to High(FLinkGridList[I].Columns) do
    begin
      Result := Result +
      CRLF +'        item '+
      CRLF +'          MemberName = '+ FLinkGridList[I].Columns[J].FieldName;
      
      // Se tem Caption
      if not FLinkGridList[I].Columns[J].Caption.IsEmpty then
      begin
        Result := Result +
        CRLF +'          Header = '+ FLinkGridList[I].Columns[J].Caption;      
      end;
      
      // Se tem Width
      if not FLinkGridList[I].Columns[J].Width.IsEmpty then
      begin
        Result := Result +
        CRLF +'          Width = '+ FLinkGridList[I].Columns[J].Width;      
      end;
      
      Result := Result +
      CRLF +'        end ';
    end;

    Result := Result +
    CRLF +'        > '+
    CRLF +'    end ';
  end;

  Result := Result +
  CRLF +'  end ';
end;

{ Eduardo }
function TDfmToFmxObject.GetPASLiveBindings: String;
var
  I: Integer;
begin
  if (Length(FLinkControlList) = 0) and (Length(FLinkGridList) = 0) then
    Exit(EmptyStr);

  // Adiciona BindingsList
  Result := '    BindingsList: TBindingsList; ';

  // Passa pela lista de controles
  for I := 0 to High(FLinkControlList) do
  begin
    Result := Result +
    CRLF +'    LinkControlToField'+ I.ToString +': TLinkControlToField; ';
  end;

  // Passa pela lista de grids
  for I := 0 to High(FLinkGridList) do
  begin
    Result := Result +
    CRLF +'    LinkGridToDataSourceBindSourceDB'+ I.ToString +': TLinkGridToDataSource; ';
  end;
end;

function TDfmToFmxObject.AddArrayOfItemProperties(APropertyIdx: Integer; APad: String): String;
begin
  Result:=APad+'  item'+ CRLF +
  APad+ '  Prop1 = 6'+ CRLF +
  APad+ '  end>'+ CRLF;
  //Tempary patch
end;

constructor TDfmToFmxObject.Create(ACreateText: String; AStm: TStream; ADepth: integer);
var
  InputArray: TArrayOfStrings;
  Data: String;
  NxtChr: PChar;
  i: integer;
begin
  i := 0;
  FDepth := ADepth;
  if Pos(AnsiString('object'), Trim(ACreateText)) = 1 then
  begin
    InputArray := GetArrayFromString(ACreateText, ' ');
    NxtChr := @InputArray[1][1];
    FObjName := FieldSep(NxtChr, ':');
    FDFMClass := InputArray[2];
    Data := Trim(ReadLineFrmStream(AStm));
    while Data <> AnsiString('end') do
    begin
      if Pos(AnsiString('object'), Data) = 1 then
        OwnedObjs.Add(TDfmToFmxObject.Create(Data, AStm, FDepth + 1))
      else
        ReadProperties(Data,AStm,i);
      Data := Trim(ReadLineFrmStream(AStm));
    end
  end
  else
    raise Exception.Create('Bad Start::' + ACreateText);
  SetLength(F2DPropertyArray, FPropertyMax + 1);
end;

destructor TDfmToFmxObject.Destroy;
begin
  SetLength(F2DPropertyArray, 0);
  FOwnedObjs.Free;
  FOwnedItems.Free;
  FIniReplaceValues.Free;
  FIniIncludeValues.Free;
  FIniSectionValues.Free;
  FUsesTranslation.Free;
  FIniAddProperties.Free;
end;

class function TDfmToFmxObject.DFMIsTextBased(ADfmFileName: String): Boolean;
var
  Sz: Int64;
  Idx: integer;
  DFMFile: TFileStream;
  TestString: AnsiString;
begin
  Result := false;
  if not FileExists(ADfmFileName) then
    Exit;

  DFMFile := TFileStream.Create(ADfmFileName, fmOpenRead);
  try
    Sz := DFMFile.Size;
    if Sz > 20 then
    begin
      SetLength(TestString, 20);
      Idx := DFMFile.Read(TestString[1], 20);
      if Idx <> 20 then
        raise Exception.Create('Error Dfm file read');
      if PosNoCase('object', String(TestString)) > 0 then
        Result := true;
      if not Result then
      begin
        try
          TestString := AnsiString(CompressedUnicode(String(TestString)));
          if PosNoCase('object', String(TestString)) > 0 then
            Result := true;
        except
        end;
      end;
    end;
  finally
    DFMFile.Free;
  end;
end;

function TDfmToFmxObject.FMXClass: String;
begin
  Result := FDFMClass;
end;

function TDfmToFmxObject.FMXFile(APad: String = ''): String;
begin
  Result := APad +'object '+ FObjName +': '+ FMXClass + CRLF;
  Result := Result + FMXProperties(APad);
  Result := Result + FMXSubObjects(APad +' ');
  if APad = EmptyStr then
    Result := Result + GetFMXLiveBindings + CRLF + APad +'end' + CRLF
  else
    Result := Result + APad +'end' + CRLF;
end;

function TDfmToFmxObject.FMXProperties(APad: String): String;
var
  i: Integer;
  sProp: String;
begin
  Result := EmptyStr;
  for i := Low(F2DPropertyArray) to High(F2DPropertyArray) do
  begin
    if F2DPropertyArray[i, 1] = '<' then
      Result := Result + APad +'  '+ TransformProperty(F2DPropertyArray[i, 0], F2DPropertyArray[i, 1]) + CRLF + AddArrayOfItemProperties(i, APad +'  ') + CRLF
    else
    if F2DPropertyArray[i, 1][1] = '{' then
    begin
      sProp := TransformProperty(F2DPropertyArray[i, 0], F2DPropertyArray[i, 1], APad);
      if not sProp.IsEmpty then
        Result := Result + APad +'  '+ sProp + CRLF;
    end
    else
    if F2DPropertyArray[i, 0] <> EmptyStr then
    begin
      sProp := TransformProperty(F2DPropertyArray[i, 0], F2DPropertyArray[i, 1]);
      if not sProp.IsEmpty then
        Result := Result + APad +'  '+ sProp + CRLF;
    end;
  end;
  if IniAddProperties.Count > 0 then
    for i := 0 to Pred(FIniAddProperties.Count) do
      Result := Result + APad +'  '+ StringReplace(FIniAddProperties[i], '=', ' = ', []) + CRLF;
end;

function TDfmToFmxObject.FMXSubObjects(APad: String): String;
var
  I: integer;
begin
  Result := EmptyStr;
  if FOwnedObjs = nil then
    Exit;

  for I := 0 to Pred(FOwnedObjs.Count) do
    if FOwnedObjs[I] is TDfmToFmxObject then
      Result := Result + TDfmToFmxObject(FOwnedObjs[I]).FMXFile(APad +' ');
end;

function TDfmToFmxObject.GenPasFile(const APascalSourceFileName: String): AnsiString;
var
  PasFile: TFileStream;
  PreUsesString, PostUsesString, UsesString: AnsiString;
  UsesArray: TArrayOfStrings;
  StartChr, EndChar: PAnsiChar;
  Sz: integer;
  Idx: integer;
  s: String;
begin
  Result := '';
  PostUsesString := '';
  UsesString := '';
  if not FileExists(APascalSourceFileName) then
    Exit;

  PasFile := TFileStream.Create(APascalSourceFileName, fmOpenRead);
  try
    Sz := PasFile.Size;
    if Sz > 20 then
    begin
      SetLength(PreUsesString, Sz);
      Idx := PasFile.Read(PreUsesString[1], Sz);
      if Idx <> Sz then
        raise Exception.Create('Error Pas file read');
    end
    else
      PreUsesString := '';
  finally
    PasFile.Free;
  end;

  if Sz > 20 then
  begin
    Idx := PosNoCase('uses', String(PreUsesString));
    StartChr := @PreUsesString[Idx + 4];
    s := ';';
    EndChar := StrPos(StartChr, PAnsiChar(s));
    UsesArray := GetArrayFromString(StringReplace(Copy(String(PreUsesString), Idx + 4, EndChar - StartChr), CRLF, '', [rfReplaceAll]), ',');
    PostUsesString := Copy(PreUsesString, EndChar - StartChr + Idx + 4, Sz);
    PostUsesString := AnsiString(ProcessCodeBody(String(PostUsesString)));

    PostUsesString := AnsiString(Copy(String(PostUsesString), 1, Pos('TBindSourceDB', String(PostUsesString)) + 15) +
      GetPASLiveBindings +
      Copy(String(PostUsesString), Pos('TBindSourceDB', String(PostUsesString)) + 15));

    SetLength(PreUsesString, Pred(Idx));
    UsesString := AnsiString(ProcessUsesString(UsesArray));
  end;
  Result := PreUsesString + UsesString + PostUsesString;
end;

function TDfmToFmxObject.IniAddProperties: TStringlist;
begin
  if FIniAddProperties = nil then
    FIniAddProperties := TStringlist.Create;
  Result := FIniAddProperties;
end;

procedure TDfmToFmxObject.IniFileLoad(AIni: TIniFile);
var
  i: integer;
  NewClassName: String;
begin
  if AIni = nil then
    Exit;
  if FDepth < 1 then
  begin
    AIni.ReadSectionValues('ObjectChanges', IniObjectTranslations);
    AIni.ReadSectionValues('TForm', IniSectionValues);
    AIni.ReadSectionValues('TFormReplace', IniReplaceValues);
    AIni.ReadSection('TFormInclude', IniIncludeValues);
  end
  else
  begin
    NewClassName := AIni.ReadString('ObjectChanges', FDFMClass, EmptyStr);
    if NewClassName <> EmptyStr then
      FDFMClass := NewClassName;
    AIni.ReadSectionValues(FDFMClass, IniSectionValues);
    AIni.ReadSectionValues(FDFMClass + 'Replace', IniReplaceValues);
    AIni.ReadSection(FDFMClass + 'Include', IniIncludeValues);
    AIni.ReadSectionValues(FDFMClass + 'AddProperty', IniAddProperties);
  end;

  for i := 0 to Pred(OwnedObjs.Count) do
    if OwnedObjs[i] is TDfmToFmxObject then
      TDfmToFmxObject(OwnedObjs[i]).IniFileLoad(AIni);

  if FOwnedItems <> nil then
    for i := 0 to Pred(fOwnedItems.Count) do
     if fOwnedItems[i] is TDfmToFmxListItem then
       TDfmToFmxListItem(fOwnedItems[i]).IniFileLoad(AIni);

  if IniSectionValues.Count < 1 then
  begin
    AIni.WriteString(FDFMClass, 'Empty', 'Add Transformations');
    AIni.WriteString(FDFMClass, 'Top',   'Position.Y');
    AIni.WriteString(FDFMClass, 'Left',  'Position.X');
  end;

  if IniIncludeValues.Count < 1 then
    AIni.WriteString(FDFMClass + 'Include', 'FMX.Controls', 'Empty Include');
end;

function TDfmToFmxObject.IniIncludeValues: TStringlist;
begin
  if FIniIncludeValues = nil then
    FIniIncludeValues := TStringlist.Create;
  Result := FIniIncludeValues;
end;

function TDfmToFmxObject.IniObjectTranslations: TStringList;
begin
  if FIniObjectTranslations = nil then
    FIniObjectTranslations := TStringlist.Create;
  Result := FIniObjectTranslations;
end;

function TDfmToFmxObject.IniReplaceValues: TStringlist;
begin
  if FIniReplaceValues = nil then
    FIniReplaceValues := TStringlist.Create;
  Result := FIniReplaceValues;
end;

function TDfmToFmxObject.IniSectionValues: TStringlist;
begin
  if FIniSectionValues = nil then
    FIniSectionValues := TStringlist.Create;
  Result := FIniSectionValues;
end;

procedure TDfmToFmxObject.LoadInfileDefs(AIniFileName: String);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(AIniFileName);
  IniFileLoad(Ini);
end;

function TDfmToFmxObject.OwnedObjs: TObjectList;
begin
  if FOwnedObjs = nil then
  begin
    FOwnedObjs := TObjectList.Create;
    FOwnedObjs.OwnsObjects := true;
  end;
  Result := FOwnedObjs;
end;

function TDfmToFmxObject.ProcessCodeBody(const ACodeBody: String): String;
var
  BdyStr: String;
  Idx: Integer;
  TransArray: TArrayOfStrings;
begin
  BdyStr := StringReplace(ACodeBody, AnsiString('{$R *.DFM}'), AnsiString('{$R *.FMX}'), [rfIgnoreCase]);
  if FIniObjectTranslations <> nil then
  begin
    for Idx := 0 to FIniObjectTranslations.Count-1 do
    begin
      TransArray := GetArrayFromString(FIniObjectTranslations[Idx], '=');
      if Length(TransArray) > 1 then
        BdyStr := StringReplace(BdyStr, TransArray[0], TransArray[1], [rfReplaceAll,rfIgnoreCase]);
    end;
  end;
  Result := BdyStr;
end;

function TDfmToFmxObject.ProcessUsesString(AOrigUsesArray: TArrayOfStrings): String;
var
  i: integer;
begin
  PopulateStringsFromArray(UsesTranslation, AOrigUsesArray);
  UpdateUsesStringList(UsesTranslation);
  Result := 'uses ';
  for i := 0 to Pred(UsesTranslation.Count) do
    if Trim(FUsesTranslation[i]) <> EmptyStr then
      Result := Result + CRLF +'  '+ FUsesTranslation[i] + ',';
  SetLength(Result, Pred(Length(Result)));
end;

function TDfmToFmxObject.PropertyArray(ARow: integer): TArrayOfStrings;
begin
  while ARow >= FPropertyArraySz do
  begin
    inc(FPropertyArraySz, 5);
    SetLength(F2DPropertyArray, FPropertyArraySz);
  end;
  if ARow > FPropertyMax then
    FPropertyMax := ARow;
  Result := F2DPropertyArray[ARow];
end;

{ Eduardo }
procedure TDfmToFmxObject.ReadItems(Prop: TTwoDArrayOfString; APropertyIdx: integer; AStm: TStream);
var
  Data: String;
  saTemp: Array of String;
  sTemp: String;
begin
  Data := Trim(ReadLineFrmStream(AStm));
  while not (Pos(AnsiString('>'), Data) > 0) do
  begin
    SetLength(saTemp, Succ(Length(saTemp)));
    saTemp[Pred(Length(saTemp))] := Data;
    Data := Trim(ReadLineFrmStream(AStm));
  end;
  SetLength(saTemp, Succ(Length(saTemp)));
  saTemp[Pred(Length(saTemp))] := Data;
  
  for sTemp in saTemp do
    Prop[APropertyIdx, 1] := Prop[APropertyIdx, 1] + #13 + sTemp;
end;

{ Eduardo }
procedure TDfmToFmxObject.ReadData(Prop: TTwoDArrayOfString; APropertyIdx: integer; AStm: TStream);
var
  Data: String;
begin
  Data := Trim(ReadLineFrmStream(AStm));
  while not (Pos(AnsiString('}'), Data) > 0) do
  begin
    Prop[APropertyIdx, 1] := Prop[APropertyIdx, 1] + Data;
    Data := Trim(ReadLineFrmStream(AStm));
  end;
  Prop[APropertyIdx, 1] := Prop[APropertyIdx, 1] + Data;
end;

{ Eduardo }
procedure TDfmToFmxObject.ReadText(Prop: TTwoDArrayOfString; APropertyIdx: integer; AStm: TStream);
var
  Data: String;
begin
  Data := Trim(ReadLineFrmStream(AStm));
  while (Pos(AnsiString('+'), Data) > 0) do
  begin
    Prop[APropertyIdx, 1] := Prop[APropertyIdx, 1] + Data;
    Data := Trim(ReadLineFrmStream(AStm));
  end;
  Prop[APropertyIdx, 1] := Prop[APropertyIdx, 1] + Data;
end;

procedure TDfmToFmxObject.ReadProperties(AData: String; AStm: TStream; var AIdx: Integer);
begin
  PropertyArray(AIdx);
  F2DPropertyArray[AIdx] := GetArrayFromString(AData, '=');
  if High(F2DPropertyArray[AIdx]) < 1 then
  begin
    SetLength(F2DPropertyArray[AIdx], 2);
    F2DPropertyArray[AIdx, 0] := ContinueCode;
    F2DPropertyArray[AIdx, 1] := AData;
  end
  else
  if (F2DPropertyArray[AIdx,1] = '<') then
    ReadItems(F2DPropertyArray, AIdx, AStm)
  else
  if (F2DPropertyArray[AIdx,1] = '{') then
    ReadData(F2DPropertyArray, AIdx, AStm)
  else
  if (F2DPropertyArray[AIdx,1] = '') then
    ReadText(F2DPropertyArray, AIdx, AStm);
  Inc(AIdx);
end;

function TDfmToFmxObject.TransformProperty(ACurrentName, ACurrentValue: String; APad: String = ''): String;
var
  s: String;
begin
  if ACurrentName = ContinueCode then
    Result := ACurrentValue
  else
  begin
    s := FIniSectionValues.Values[ACurrentName];
    if s = EmptyStr then
      s := ACurrentName;
    if s = '#Delete#' then
      Result := EmptyStr
    else
    if Pos('#TAlign#', s) > 0 then
    begin
      ACurrentValue := StringReplace(ACurrentValue, 'al', EmptyStr, [rfReplaceAll]);
      Result := ACurrentName +' = '+ ACurrentValue;
    end
    else
    if Pos('#Class#', s) > 0 then
    begin
      if FDFMClass = 'TImage' then
        Result := StringReplace(s, '#Class#', ProcessImage(ACurrentValue, APad), [])
      else
      if FDFMClass = 'TImageList' then
        Result := StringReplace(s, '#Class#', ProcessImageList(ACurrentValue, APad), [])
    end
    else
      Result := s +' = '+ ACurrentValue;
  end;
end;

procedure TDfmToFmxObject.UpdateUsesStringList(AUsesList: TStrings);
var
  i: integer;
  Idx: integer;
begin
  if FIniReplaceValues <> nil then
  begin
    for i := 0 to Pred(AUsesList.Count) do
    begin
      Idx := FIniReplaceValues.IndexOfName(AUsesList[i]);
      if Idx >= 0 then
        AUsesList[i] := FIniReplaceValues.ValueFromIndex[Idx];
    end;
  end;

  for i := Pred(AUsesList.Count) downto 0 do
    if Trim(AUsesList[i]) = EmptyStr then
      AUsesList.Delete(i);

  if FIniIncludeValues <> nil then
  begin
    for i := 0 to Pred(FIniIncludeValues.Count) do
    begin
      Idx := AUsesList.IndexOf(FIniIncludeValues[i]);
      if Idx < 0 then
        AUsesList.add(FIniIncludeValues[i]);
    end;
  end;

  if FOwnedObjs = nil then
    Exit;

  for i := 0 to Pred(FOwnedObjs.Count) do
    if FOwnedObjs[i] is TDfmToFmxObject then
      TDfmToFmxObject(FOwnedObjs[i]).UpdateUsesStringList(AUsesList);
end;

function TDfmToFmxObject.UsesTranslation: TStringlist;
begin
  if FUsesTranslation = nil then
    FUsesTranslation := TStringlist.Create;
  Result := FUsesTranslation;
end;

function TDfmToFmxObject.WriteFMXToFile(const AFmxFileName: String): Boolean;
var
  OutFile: TFileStream;
  s: AnsiString;
begin
  s := AnsiString(FMXFile);
  if String(s).IsEmpty then
    raise Exception.Create('Não há dados para o arquivo FMX!');

  if FileExists(AFmxFileName) then
    RenameFile(AFmxFileName, ChangeFileExt(AFmxFileName, '.fbk'));

  OutFile := TFileStream.Create(AFmxFileName, fmCreate);
  try
    OutFile.Write(s[1], Length(s));
    Result := True;
  finally
    OutFile.Free;
  end;
end;

function TDfmToFmxObject.WritePasToFile(const APasOutFileName, APascalSourceFileName: String): Boolean;
var
  OutFile: TFileStream;
  s: AnsiString;
begin
  if not FileExists(APascalSourceFileName) then
    raise Exception.Create('Pascal Source:' + APascalSourceFileName +
      ' Does not Exist');

  s := GenPasFile(APascalSourceFileName);
  if s = '' then
    raise Exception.Create('No Data for Pas File');
  s := AnsiString(StringReplace(String(s), ChangeFileExt(ExtractFileName(APascalSourceFileName), EmptyStr), ChangeFileExt(ExtractFileName(APasOutFileName), ''), [rfIgnoreCase]));
  if FileExists(APasOutFileName) then
    RenameFile(APasOutFileName, ChangeFileExt(APasOutFileName, '.bak'));
  OutFile := TFileStream.Create(APasOutFileName, fmCreate);
  try
    OutFile.Write(s[1], Length(s));
    Result := true;
  finally
    OutFile.Free;
  end;
end;

{ TDfmToFmxListItem }

constructor TDfmToFmxListItem.Create(AOwner: TDfmToFmxObject; APropertyIdx: integer; AStm: TStream; ADepth: integer);
var
  Data: String;
  i,LoopCount: integer;
begin
  FPropertyIndex := APropertyIdx;
  FOwner := AOwner;
  i := 0;
  FDepth := ADepth;
  Data   := EmptyStr;
  LoopCount := 55;
  while (LoopCount > 0) and (Pos(AnsiString('end'),Data) <> 1)  do
  Begin
    Dec(LoopCount);
    if Pos(AnsiString('object'), Data) = 1 then
      OwnedObjs.Add(TDfmToFmxObject.Create(Data, AStm, FDepth + 1))
    else
      ReadProperties(Data,AStm,i);
    Data := Trim(ReadLineFrmStream(AStm));
    if (Data <> EmptyStr) then
      LoopCount := 55;
  end;
  SetLength(F2DPropertyArray, FPropertyMax + 1);
  FHasMore := (Pos(AnsiString('end'),Data)=1) and not (Pos(AnsiString('end>'),Data) = 1);
end;

end.
