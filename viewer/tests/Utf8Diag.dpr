program Utf8Diag;

{$APPTYPE CONSOLE}

uses
  gdalcore, ogr, SysUtils;

procedure PrintBytes(p: PAnsiChar);
var
  i: Integer;
begin
  i := 0;
  while p[i] <> #0 do begin
    Write(Format('%02X ', [Byte(p[i])]));
    Inc(i);
  end;
  WriteLn;
end;

var
  utf8: UTF8String;
  ds: OGRDataSourceH;
  layer: OGRLayerH;
  feat: OGRFeatureH;
  fldName: PAnsiChar;
  s: string;
  i: Integer;
begin
  s := 'Polígono A';
  Write('literal code points : ');
  for i := 1 to Length(s) do
    Write(Format('U+%04X ', [Ord(s[i])]));
  WriteLn;

  OGRRegisterAll;
  utf8 := UTF8String('D:\AAB\DELPHI_GDAL\viewer\tests\data\sample.geojson');
  ds := OGROpen(PAnsiChar(utf8), 0, nil);
  if ds = nil then begin WriteLn('no ds'); Halt(1); end;
  layer := OGR_DS_GetLayer(ds, 0);
  feat := OGR_L_GetNextFeature(layer);
  fldName := OGR_F_GetFieldAsString(feat, 0);

  Write('raw bytes            : ');
  PrintBytes(fldName);

  s := UTF8ToString(fldName);
  Write('converted code points: ');
  for i := 1 to Length(s) do
    Write(Format('U+%04X ', [Ord(s[i])]));
  WriteLn;
  WriteLn('converted = "', s, '"');

  OGR_F_Destroy(feat);
  OGRReleaseDataSource(ds);
end.
