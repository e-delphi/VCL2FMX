{**********************************************}
{                                              }
{              Eduardo Rodrigues               }
{                 18/09/2019                   }
{                                              }
{**********************************************}
unit ImageList;

interface

uses
  System.Classes,
  Vcl.ImgList;

type
  TCustomImageListAccess = class(Vcl.ImgList.TCustomImageList)
  end;

function ProcessImageList(sData, APad: String): String;
function ImageListDFMtoFMX(sData: String): String;
function StreamToHex(ms: TMemoryStream; LineLen:integer): String;

implementation

uses
  FMX.ImgList,
  Vcl.Graphics,
  System.SysUtils;

var
  FPad: String;

function ProcessImageList(sData, APad: String): String;
begin
  FPad := APad;
  Result :=    APad +'  Source = <'+
  sLineBreak + APad +'    item '+
  sLineBreak + APad +'      Name = '+ QuotedStr('Item 0') +
  sLineBreak + APad +'      MultiResBitmap = < '+
  sLineBreak + APad +'        item '+
  sLineBreak + APad +'          PNG = {'+ ImageListDFMtoFMX(sData) +'}'+
  sLineBreak + APad +'        end>'+
  sLineBreak + APad +'    end> '+
  sLineBreak + APad +'  Destination = < '+
  sLineBreak + APad +'    item '+
  sLineBreak + APad +'      Layers = < '+
  sLineBreak + APad +'        item '+
  sLineBreak + APad +'          Name = '+ QuotedStr('Item 0') +
  sLineBreak + APad +'        end>'+
  sLineBreak + APad +'    end>';
end;

function ImageListDFMtoFMX(sData: String): String;
var
  Linput: String;
  Loutput: TMemoryStream;
  Lgraphic: TCustomImageListAccess;
  img1: FMX.ImgList.TImageList;
  stream: TMemoryStream;
  stream2: TMemoryStream;
  bmp: TBitmap;
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

    Lgraphic := TCustomImageListAccess.Create(nil);
    try
      // Carrega dados para imagem VCL
      TCustomImageListAccess(Lgraphic).ReadData(Loutput);

      bmp := TBitmap.Create;
      Lgraphic.GetBitmap(0, bmp);

      // Converte de VCL para FMX
      stream := TMemoryStream.Create;
      try
        bmp.SaveToStream(stream);
        stream.Position := 0;

        // Cria imagem FMX
        img1 := FMX.ImgList.TImageList.Create(nil);
        try
          img1.Source.Add.MultiResBitmap.Add.Bitmap.LoadFromStream(stream);

          stream2 := TMemoryStream.Create;
          try
            img1.Source.Items[0].MultiResBitmap.Items[0].Bitmap.SaveToStream(stream2);
            Result := StreamToHex(stream2, 64);
          finally
            stream2.Free;
          end;
        finally
          img1.Free;
        end;

      finally
        stream.Free;
      end;
    finally
      Lgraphic.Free;
    end;
  finally
    Loutput.Free;
  end;
end;

function StreamToHex(ms:TMemoryStream; LineLen:integer): String;
var
  s: String;
  t: Ansistring;
begin
  SetLength(t, ms.Size * 2);
  BinToHex(ms.Memory^, Pansichar(t), ms.Size);
  repeat
    s := Copy(String(t), 1, LineLen);
    Result := Result + sLineBreak + FPad +'            '+ s;
    Delete(t, 1, LineLen);
  until t = '';
end;

end.
