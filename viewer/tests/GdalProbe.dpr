program GdalProbe;

{$APPTYPE CONSOLE}

uses
  gdalcore, ogr, SysUtils;

begin
  try
    OGRRegisterAll;
    WriteLn('GDAL version : ' + UTF8ToString(GDALVersionInfo('--version')));
    WriteLn('Release name : ' + UTF8ToString(GDALVersionInfo('RELEASE_NAME')));
    WriteLn('Version num  : ' + UTF8ToString(GDALVersionInfo('VERSION_NUM')));
  except
    on E: Exception do
      WriteLn('ERROR: ' + E.ClassName + ': ' + E.Message);
  end;
end.
