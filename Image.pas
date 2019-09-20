{**********************************************}
{                                              }
{              Eduardo Rodrigues               }
{                 18/09/2019                   }
{                                              }
{**********************************************}
unit Image;

interface

uses
  Vcl.Graphics,
  FMX.Objects;

type
  TGraphicAccess = class(Vcl.Graphics.TGraphic)
  end;

function ProcessImage(sData, APad: String): String;

function ImageDFMtoFMX(sData: String): String;

function ImageToHex(Image:FMX.Objects.TImage; LineLen:integer): String;

implementation

uses
  System.Classes,
  Vcl.ExtCtrls,
  System.SysUtils,
  Vcl.Imaging.Jpeg,
  Vcl.Imaging.GIFImg,
  Vcl.Imaging.PngImage;

var
  FPad: String;

function ProcessImage(sData, APad: String): String;
begin
  FPad := APad;
  Result :=    APad +'  MultiResBitmap = <'+
  sLineBreak + APad +'    item '+
  sLineBreak + APad +'      PNG = { '+ ImageDFMtoFMX(sData) +'} '+
  sLineBreak + APad +'    end>';
end;

function ImageDFMtoFMX(sData: String): String;
var
  Linput: String;
  Loutput: TMemoryStream;
  LclsName: ShortString;
  Lgraphic: TGraphic;
  img2: Vcl.ExtCtrls.TImage;
  img1: FMX.Objects.TImage;
  stream: TMemoryStream;
begin
  // Remove caracteres
  sData := StringReplace(sData, '{', EmptyStr, []);
  sData := StringReplace(sData, '}', EmptyStr, []);

  // Inicializa
  Linput  := sData;
  Loutput := TMemoryStream.Create;
  try
    // Carrega dados para memoria
    Loutput.Size := Length(Linput) div 2;
    HexToBin(PChar(Linput), Loutput.Memory^, Loutput.Size);
    LclsName := PShortString(Loutput.Memory)^;

    // Cria imagem FMX
    img1 := FMX.Objects.TImage.Create(nil);
    // Cria imagem VCL
    Lgraphic := TGraphicClass(FindClass(UTF8ToString(LclsName))).Create;
    try
      // Carrega dados para imagem VCL
      Loutput.Position := 1 + Length(LclsName);
      TGraphicAccess(Lgraphic).ReadData(Loutput);
      img2 := TImage.Create(nil);
      img2.Picture.Assign(Lgraphic);

      // Converte de VCL para FMX
      stream:= TMemoryStream.Create;
      try
        img2.Picture.SaveToStream(stream);
        stream.Position := 0;
        img1.Bitmap.LoadFromStream(stream);
      finally
        stream.Free;
      end;

      // Retorna imagem convertida de FMX para texto
      Result := ImageToHex(img1, 64);
    finally
      img1.Free;
      Lgraphic.Free;
    end;
  finally
    Loutput.Free;
  end;
end;

function ImageToHex(Image:FMX.Objects.TImage; LineLen:integer): String;
var
  ms:TMemoryStream;
  s:String;
  t:Ansistring;
begin
  ms := TMemoryStream.Create;
  try
    image.Bitmap.SaveToStream(ms);
    SetLength(t, ms.Size * 2);
    BinToHex(ms.Memory^, Pansichar(t), ms.Size);
    repeat
      s := Copy(String(t), 1, LineLen);
      Result := Result + sLineBreak + FPad +'        '+ s;
      Delete(t, 1, LineLen);
    until t = '';
  finally
    ms.Free;
  end;
end;

initialization
  System.Classes.RegisterClass(TMetafile);
  System.Classes.RegisterClass(TIcon);
  System.Classes.RegisterClass(TBitmap);
  System.Classes.RegisterClass(TWICImage);
  System.Classes.RegisterClass(TJpegImage);
  System.Classes.RegisterClass(TGifImage);
  System.Classes.RegisterClass(TPngImage);

end.
