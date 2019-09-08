program VCL2FMX;

uses
  System.StartUpCopy,
  FMX.Forms,
  CvtrObj in 'CvtrObj.pas',
  DFMToFMXFM in 'DFMToFMXFM.pas' {DFMtoFMXConvert},
  PatchLib in 'PatchLib.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TDFMtoFMXConvert, DFMtoFMXConvert);
  Application.Run;
end.
