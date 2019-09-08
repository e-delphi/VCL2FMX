unit DFMToFMXFM;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  System.Win.Registry,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Dialogs,
  FMX.Layouts,
  FMX.Memo,
  CvtrObj,
  FMX.StdCtrls,
  FMX.ScrollBox,
  FMX.Controls.Presentation,
  FMX.Objects;

type
  TDFMtoFMXConvert = class(TForm)
    dlgAbrir: TOpenDialog;
    BtnOpenFile: TButton;
    mmOutput: TMemo;
    dlgSalvar: TSaveDialog;
    BtnProcess: TButton;
    BtnEditIniFile: TButton;
    BtnSaveIni: TButton;
    BtnSaveFMX: TButton;
    mmInput: TMemo;
    procedure BtnOpenFileClick(Sender: TObject);
    procedure BtnProcessClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure BtnEditIniFileClick(Sender: TObject);
    procedure BtnSaveIniClick(Sender: TObject);
    procedure BtnSaveFMXClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    DFMObj: TDfmToFmxObject;
    FIniFileName: String;
    FInPasFileName: String;
    FInDfmFileName: String;
    FOutPasFileName: String;
    FOutFmxFileName: String;
    function GetRegFile: TRegistryIniFile;
    Procedure RegIniLoad;
    Procedure RegIniSave;
    Procedure UpdateForm;
  end;

var
  DFMtoFMXConvert: TDFMtoFMXConvert;

implementation

{$R *.fmx}

uses
  PatchLib;

procedure TDFMtoFMXConvert.BtnEditIniFileClick(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.FileName := ExtractFileName(FIniFileName);
    Dlg.InitialDir := ExtractFilePath(FIniFileName);
    Dlg.DefaultExt := '.ini';
    Dlg.Filter := 'Arquivos INI|*.ini|All Files|*.*';
    if Dlg.Execute then
    begin
      mmInput.Lines.Clear;
      mmInput.Lines.LoadFromFile(Dlg.FileName);
      FIniFileName := Dlg.FileName;
      BtnSaveIni.Enabled := True;
      BtnProcess.Enabled := False;
    end;
    UpdateForm;
  finally
    Dlg.Free;
  end;
end;

procedure TDFMtoFMXConvert.BtnOpenFileClick(Sender: TObject);
begin
  BtnSaveIni.Enabled := False;
  BtnProcess.Enabled := False;
  FreeAndNil(DFMObj);
  if FInDfmFileName <> EmptyStr then
    dlgAbrir.InitialDir := ExtractFileDir(FInDfmFileName);
  if dlgAbrir.Execute then
  begin
    FInPasFileName := ChangeFileExt(dlgAbrir.FileName, '.pas');
    FInDfmFileName := ChangeFileExt(FInPasFileName, '.dfm');
    if FileExists(FInDfmFileName) then
      if TDfmToFmxObject.DFMIsTextBased(FInDfmFileName) then
      begin
        mmInput.Lines.Clear;
        mmInput.Lines.LoadFromFile(FInDfmFileName);
        BtnSaveIni.Enabled := False;
        BtnProcess.Enabled := True;
      end
      else
        raise Exception.Create('Arquivo dfm incompatível:' + FInDfmFileName);
  end;
  UpdateForm;
end;

procedure TDFMtoFMXConvert.BtnProcessClick(Sender: TObject);
var
  Data: String;
  Stm: TStringStream;
begin
  if mmInput.Text <> EmptyStr then
  begin
    FreeAndNil(DFMObj);
    Data := mmInput.Text;
    Stm := TStringStream.Create;
    Stm.LoadFromFile(FInDfmFileName);
    Stm.Seek(0,soFromBeginning);
    try
      Data := Trim(ReadLineFrmStream(Stm));
      if Pos('object', Data) = 1 then
        DFMObj := TDfmToFmxObject.Create(Data, Stm, 0);
    finally
      Stm.Free;
    end;
  end;

  DFMObj.LiveBindings;

  DFMObj.LoadInfileDefs(FIniFileName);
  mmOutput.Text := EmptyStr;
  mmOutput.Text := DFMObj.FMXFile;
  BtnSaveIni.Enabled := False;
  BtnProcess.Enabled := False;
  UpdateForm;
end;

procedure TDFMtoFMXConvert.BtnSaveFMXClick(Sender: TObject);
begin
  if DFMObj = nil then
    UpdateForm
  else
  begin
    FOutPasFileName := ExtractFilePath(FOutPasFileName) + ChangeFileExt(ExtractFileName(FInDfmFileName), 'FMX.pas');

    if not FOutPasFileName.IsEmpty then
    begin
      dlgSalvar.InitialDir := ExtractFileDir(FOutPasFileName);
      dlgSalvar.FileName   := ExtractFileName(ChangeFileExt(FOutPasFileName, '.fmx'));
    end;

    if dlgSalvar.Execute then
    begin
      FOutPasFileName := ChangeFileExt(dlgSalvar.FileName, '.pas');
      FOutFmxFileName := ChangeFileExt(FOutPasFileName, '.fmx');

      if FileExists(FOutFmxFileName) or FileExists(FOutPasFileName) then
      begin
        if MessageDlg('Substituir Arquivos Existentes: '+ FOutFmxFileName +' e/ou '+ FOutPasFileName, TMsgDlgType.mtWarning, [TMsgDlgBtn.mbOK, TMsgDlgBtn.mbCancel], 0) = mrOk then
        begin
          DeleteFile(FOutFmxFileName);
          DeleteFile(FOutPasFileName);
        end;
      end;

      if FileExists(FOutFmxFileName) then
        raise Exception.Create(FOutFmxFileName + 'Já existe');

      DFMObj.WriteFMXToFile(FOutFmxFileName);

      if FileExists(FOutPasFileName) then
        raise Exception.Create(FOutPasFileName + 'Já existe');

      DFMObj.WritePasToFile(FOutPasFileName, FInPasFileName);
    end;
  end;
end;

procedure TDFMtoFMXConvert.BtnSaveIniClick(Sender: TObject);
begin
  FreeAndNil(DFMObj);
  if FileExists(FIniFileName) then
    DeleteFile(FIniFileName);
  mmInput.Lines.SaveToFile(FIniFileName);
  UpdateForm;
end;

procedure TDFMtoFMXConvert.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  RegIniSave;
end;

procedure TDFMtoFMXConvert.FormCreate(Sender: TObject);
begin
  BtnSaveIni.Enabled := false;
  RegIniLoad;
  if not FileExists(FIniFileName) then
    FIniFileName := ChangeFileExt(ParamStr(0), '.ini');
  UpdateForm;
end;

function TDFMtoFMXConvert.GetRegFile: TRegistryIniFile;
begin
  Result := TRegistryIniFile.Create('DFMtoFMXConvertor');
end;

procedure TDFMtoFMXConvert.RegIniLoad;
var
  RegFile: TRegistryIniFile;
begin
  RegFile := GetRegFile;
  try
    FIniFileName    := RegFile.ReadString('Files', 'Inifile',   EmptyStr);
    FInDfmFileName  := RegFile.ReadString('Files', 'Inputdfm',  EmptyStr);
    FOutPasFileName := RegFile.ReadString('Files', 'Outputpas', EmptyStr);
    if FInDfmFileName <> EmptyStr then
      FInPasFileName := ChangeFileExt(FInDfmFileName, '.pas');
    if FOutPasFileName <> EmptyStr then
    begin
      FOutFmxFileName := ChangeFileExt(FOutPasFileName, '.fmx');
      dlgAbrir.InitialDir := ExtractFileDir(FOutPasFileName);
    end;
    if FileExists(FInDfmFileName) then
      if TDfmToFmxObject.DFMIsTextBased(FInDfmFileName) then
      begin
        mmInput.Lines.Clear;
        mmInput.Lines.LoadFromFile(FInDfmFileName);
      end;
  finally
    RegFile.Free;
  end;
end;

procedure TDFMtoFMXConvert.RegIniSave;
Var
  RegFile: TRegistryIniFile;
begin
  RegFile := GetRegFile;
  try
    RegFile.WriteString('Files', 'inifile', FIniFileName);
    RegFile.WriteString('Files', 'InputDFm', FInDfmFileName);
    RegFile.WriteString('Files', 'OutputPas', FOutPasFileName);
  finally
    RegFile.Free;
  end;
end;

procedure TDFMtoFMXConvert.UpdateForm;
begin
  BtnSaveFMX.Visible := DFMObj <> nil;
end;

end.
