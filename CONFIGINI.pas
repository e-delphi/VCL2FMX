{**********************************************}
{                                              }
{              Eduardo Rodrigues               }
{                 11/09/2019                   }
{                                              }
{**********************************************}
unit CONFIGINI;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.TreeView,
  FMX.Layouts,
  FMX.Controls.Presentation,
  FMX.StdCtrls,
  FMX.Edit;

type
  TINI = class(TForm)
    tvINI: TTreeView;
    pnlTop: TPanel;
    btnAdicionar: TButton;
    edtVCL: TEdit;
    edtFMX: TEdit;
    lbEqual: TLabel;
    btnRemover: TButton;
    btnSalvar: TButton;
    btnAbrir: TButton;
    edtINI: TEdit;
    procedure FormCreate(Sender: TObject);
    procedure btnAdicionarClick(Sender: TObject);
    procedure btnRemoverClick(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
    procedure btnAbrirClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  end;

implementation

uses
  System.Win.Registry,
  System.IniFiles,
  System.StrUtils;

{$R *.fmx}

procedure TINI.btnAbrirClick(Sender: TObject);
var
  Dlg: TOpenDialog;
  RegFile: TRegistryIniFile;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.FileName := ExtractFileName(edtINI.Text);
    Dlg.InitialDir := ExtractFilePath(edtINI.Text);
    Dlg.DefaultExt := '.ini';
    Dlg.Filter := 'Arquivos INI|*.ini|All Files|*.*';
    if Dlg.Execute then
    begin
      RegFile := TRegistryIniFile.Create('DFMtoFMXConvertor');
      try
        RegFile.WriteString('Files', 'inifile', Dlg.FileName);
      finally
        RegFile.Free;
      end;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TINI.btnAdicionarClick(Sender: TObject);
var
  tvSec: TTreeViewItem;
begin
  if not Assigned(tvINI.Selected) then
    Exit;
  tvSec := TTreeViewItem.Create(tvINI);
  tvSec.Text := edtVCL.Text +'='+ edtFMX.Text;
  if tvINI.Selected.Level = 1 then
    tvINI.Selected.AddObject(tvSec)
  else
    tvINI.Selected.ParentItem.AddObject(tvSec);
end;

procedure TINI.btnRemoverClick(Sender: TObject);
begin
  if not Assigned(tvINI.Selected) then
    Exit;

  if tvINI.Selected.Level = 1 then
    tvINI.RemoveObject(tvINI.Selected)
  else
    tvINI.Selected.ParentItem.RemoveObject(tvINI.Selected);
end;

procedure TINI.btnSalvarClick(Sender: TObject);
var
  RegFile: TRegistryIniFile;
  Ini: TIniFile;
  sIniFile: String;
  IniObjectTranslations: TStringList;
  sKey: String;
  sValue: String;
  I: Integer;
  J: Integer;
begin
  tvINI.Sorted := True;
  RegFile := TRegistryIniFile.Create('DFMtoFMXConvertor');;
  try
    sIniFile := RegFile.ReadString('Files', 'Inifile', EmptyStr);
    DeleteFile(ChangeFileExt(sIniFile, '.bkp'));
    RenameFile(sIniFile, ChangeFileExt(sIniFile, '.bkp'));
    Ini := TIniFile.Create(sIniFile);
    try
      IniObjectTranslations := TStringList.Create;
      try
        for I := 0 to Pred(tvINI.Count) do
        begin
          if (tvINI.Items[I].Count = 0) or tvINI.Items[I].Text.Trim.IsEmpty then
            Continue;
          for J := 0 to Pred(tvINI.Items[I].Count) do
          begin
            sKey := Copy(tvINI.Items[I].Items[J].Text, 1, Pred(Pos('=', tvINI.Items[I].Items[J].Text)));
            sValue := Copy(tvINI.Items[I].Items[J].Text, Succ(Pos('=', tvINI.Items[I].Items[J].Text)));
            Ini.WriteString(tvINI.Items[I].Text, sKey, sValue);
          end;
        end;
      finally
        IniObjectTranslations.Free;
      end;
    finally
      Ini.Free;
    end;
  finally
    RegFile.Free;
  end;
end;

procedure TINI.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := TCloseAction.caFree;
end;

procedure TINI.FormCreate(Sender: TObject);
var
  RegFile: TRegistryIniFile;
  Ini: TIniFile;
  sIniFile: String;
  IniObjectTranslations: TStringList;
  IniSectionValues: TStringList;
  sClass: String;
  sItem: String;
  tvObj: TTreeViewItem;
  tvSec: TTreeViewItem;
begin
  RegFile := TRegistryIniFile.Create('DFMtoFMXConvertor');;
  try
    sIniFile := RegFile.ReadString('Files', 'Inifile', EmptyStr)
  finally
    RegFile.Free;
  end;
  edtINI.Text := sIniFile;
  Ini := TIniFile.Create(sIniFile);
  try
    IniObjectTranslations := TStringList.Create;
    try
      Ini.ReadSections(IniObjectTranslations);
      for sClass in IniObjectTranslations do
      begin
        tvObj := TTreeViewItem.Create(tvINI);
        tvObj.Text := sClass;
        IniSectionValues := TStringList.Create;
        try
          Ini.ReadSectionValues(sClass, IniSectionValues);
          for sItem in IniSectionValues do
          begin
            tvSec := TTreeViewItem.Create(tvObj);
            tvSec.Text := sItem;
            tvObj.AddObject(tvSec);
          end;
        finally
          FreeAndNil(IniSectionValues);
        end;
        tvINI.AddObject(tvObj);
      end;
    finally
      IniObjectTranslations.Free;
    end;
  finally
    Ini.Free;
  end;
end;

end.
