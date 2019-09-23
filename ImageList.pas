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
procedure StreamToHex(ms:TMemoryStream; LineLen: Integer; var sResult: String);

implementation

uses
  FMX.ImgList,
  Vcl.Graphics,
  System.SysUtils ;

var
  FPad: String;

function ProcessImageList(sData, APad: String): String;
begin
  FPad := APad;
  Result := ImageListDFMtoFMX(sData);
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
  I: Integer;
  sTemp: String;
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

      // Cria imagem FMX
      img1 := FMX.ImgList.TImageList.Create(nil);
      try
        // Passa por todas imagens VCL
        for I := 0 to Pred(Lgraphic.Count) do
        begin
          // Converte de VCL para FMX
          stream := TMemoryStream.Create;
          try
            bmp := TBitmap.Create;
            try
              // Obtem imagem
              Lgraphic.GetBitmap(I, bmp);
              // Salva no Stream
              bmp.SaveToStream(stream);
              bmp.SaveToFile('D:\teste.bmp');
              // Adiciona imagem no FMX
              stream.Position := 0;
              img1.Source.Add.MultiResBitmap.Add.Bitmap.LoadFromStream(stream);
            finally
              FreeAndNil(bmp);
            end;
          finally
            stream.Free;
          end;
        end;

        Result := '  Source = <';

        // Adiciona as imagens
        for I := 0 to Pred(img1.Source.Count) do
        begin
          stream2 := TMemoryStream.Create;
          try
            img1.Source.Items[I].MultiResBitmap.Items[0].Bitmap.SaveToStream(stream2);

            sTemp := EmptyStr;
            StreamToHex(stream2, 64, sTemp);

            Result := Result +
            sLineBreak + FPad +'    item '+
            sLineBreak + FPad +'      MultiResBitmap.Height = '+ img1.Source.Items[I].MultiResBitmap.Items[0].Bitmap.Height.ToString +
            sLineBreak + FPad +'      MultiResBitmap.Width = '+ img1.Source.Items[I].MultiResBitmap.Items[0].Bitmap.Width.ToString +
            sLineBreak + FPad +'      MultiResBitmap = < '+
            sLineBreak + FPad +'        item '+
            sLineBreak + FPad +'          Width = 256 '+
            sLineBreak + FPad +'          Height = 256 '+
            sLineBreak + FPad +'          PNG = {'+ sTemp +'}'+
            sLineBreak + FPad +'          FileName = '+ QuotedStr('') +
            sLineBreak + FPad +'        end>'+
            sLineBreak + FPad +'      Name = '+ QuotedStr('Item '+ I.ToString) +
            sLineBreak + FPad +'    end';

            if Pred(img1.Source.Count) = I then
              Result := Result +'>';
          finally
            FreeAndNil(stream2);
          end;
        end;

        Result := Result +
        sLineBreak + FPad +'  Destination = < ';

        // Adiciona os itens
        for I := 0 to Pred(img1.Source.Count) do
        begin
          Result := Result +
          sLineBreak + FPad +'    item '+
          sLineBreak + FPad +'      Layers = < '+
          sLineBreak + FPad +'        item '+
          sLineBreak + FPad +'          Name = '+ QuotedStr('Item '+ I.ToString) +
          sLineBreak + FPad +'            SourceRect.Right = '+ img1.Source.Items[I].MultiResBitmap.Items[0].Bitmap.Width.ToString +
          sLineBreak + FPad +'            SourceRect.Bottom = '+ img1.Source.Items[I].MultiResBitmap.Items[0].Bitmap.Height.ToString +
          sLineBreak + FPad +'        end>'+
          sLineBreak + FPad +'    end';

          if Pred(img1.Source.Count) = I then
            Result := Result +'>';
        end;

      finally
        img1.Free;
      end;
    finally
      Lgraphic.Free;
    end;
  finally
    Loutput.Free;
  end;
end;

procedure StreamToHex(ms:TMemoryStream; LineLen: Integer; var sResult: String);
var
  s: String;
  t: AnsiString;
begin
  SetLength(t, ms.Size * 2);
  BinToHex(ms.Memory^, PAnsiChar(t), ms.Size);
  repeat
    s := Copy(String(t), 1, LineLen);
    sResult := sResult + sLineBreak + FPad +'            '+ s;
    Delete(t, 1, LineLen);
  until t = '';
end;

end.
