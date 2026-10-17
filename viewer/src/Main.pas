unit Main;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Menus,
  Vcl.ComCtrls,
  Vcl.Dialogs,
  gdalcore,
  ogr,
  GeometryModel,
  MapView,
  VectorLayer,
  MapCanvas,
  IdentifyForm;

type
  TMainForm = class(TForm)
    MainMenu1: TMainMenu;
    miFile: TMenuItem;
    miFileOpen: TMenuItem;
    miFileExit: TMenuItem;
    miView: TMenuItem;
    miViewZoomIn: TMenuItem;
    miViewZoomOut: TMenuItem;
    miViewFit: TMenuItem;
    miViewRubber: TMenuItem;
    miHelp: TMenuItem;
    miHelpAbout: TMenuItem;
    StatusBar1: TStatusBar;
    OpenDialog1: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure miFileOpenClick(Sender: TObject);
    procedure miFileExitClick(Sender: TObject);
    procedure miViewZoomInClick(Sender: TObject);
    procedure miViewZoomOutClick(Sender: TObject);
    procedure miViewFitClick(Sender: TObject);
    procedure miViewRubberClick(Sender: TObject);
    procedure miHelpAboutClick(Sender: TObject);
  private
    FCanvas: TMapCanvas;
    FLayer: TVectorLayer;
    FIdentify: TIdentifyForm;
    FVersion: string;
    procedure CanvasMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure CanvasIdentify(Sender: TObject; ScreenX, ScreenY: Integer);
    procedure UpdateStatus;
    procedure OpenFile(const FileName: string);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FLayer := TVectorLayer.Create;
  FIdentify := TIdentifyForm.Create(Self);

  FCanvas := TMapCanvas.Create(Self);
  FCanvas.Parent := Self;
  FCanvas.Align := alClient;
  FCanvas.OnMouseMove := CanvasMouseMove;
  FCanvas.OnIdentify := CanvasIdentify;

  OpenDialog1.Filter :=
    'Archivos vectoriales|*.shp;*.geojson;*.json;*.kml;*.kmz;*.gpkg;*.tab;*.mif;*.gml|' +
    'Todos los archivos|*.*';

  StatusBar1.SimplePanel := True;
  OGRRegisterAll;
  FVersion := UTF8ToString(GDALVersionInfo('MDM-GDAL_beta'));
  UpdateStatus;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FLayer.Free;
end;

procedure TMainForm.UpdateStatus;
begin
  if FLayer.FeatureCount > 0 then
    StatusBar1.SimpleText := Format('GDAL %s | %s | %d entidades',
      [FVersion, FLayer.LayerName, FLayer.FeatureCount])
  else
    StatusBar1.SimpleText := Format('GDAL %s', [FVersion]);
end;

procedure TMainForm.OpenFile(const FileName: string);
begin
  try
    FLayer.Load(FileName);
    FCanvas.SetLayer(FLayer);
    Caption := 'MDM Viewer - ' + FLayer.LayerName;
    UpdateStatus;
  except
    on E: Exception do
      ShowMessage('Error al abrir el archivo:' + sLineBreak + E.Message);
  end;
end;

procedure TMainForm.CanvasMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  w: TPointD;
begin
  if FLayer.FeatureCount = 0 then
    Exit;
  w := FCanvas.View.ScreenToWorld(X, Y);
  StatusBar1.SimpleText := Format('GDAL %s | %s | %d entidades | X=%.3f Y=%.3f',
    [FVersion, FLayer.LayerName, FLayer.FeatureCount, w.X, w.Y]);
end;

procedure TMainForm.CanvasIdentify(Sender: TObject; ScreenX, ScreenY: Integer);
var
  w: TPointD;
  idx: Integer;
  tol, d: Double;
begin
  if FLayer.FeatureCount = 0 then
    Exit;
  w := FCanvas.View.ScreenToWorld(ScreenX, ScreenY);
  tol := 5 / FCanvas.View.Scale;
  d := FindNearestFeature(FLayer.Features, w, idx);
  if (idx >= 0) and (d <= tol) then begin
    FIdentify.ShowFeature(FLayer.Features[idx]);
    FIdentify.Show;
  end;
end;

procedure TMainForm.miFileOpenClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
    OpenFile(OpenDialog1.FileName);
end;

procedure TMainForm.miFileExitClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.miViewZoomInClick(Sender: TObject);
begin
  FCanvas.ZoomIn;
end;

procedure TMainForm.miViewZoomOutClick(Sender: TObject);
begin
  FCanvas.ZoomOut;
end;

procedure TMainForm.miViewFitClick(Sender: TObject);
begin
  FCanvas.ZoomToFit;
end;

procedure TMainForm.miViewRubberClick(Sender: TObject);
begin
  FCanvas.RubberBandMode := miViewRubber.Checked;
end;

procedure TMainForm.miHelpAboutClick(Sender: TObject);
begin
  ShowMessage('MDM-GDAL' + sLineBreak + sLineBreak +
    'Visor de datos vectoriales con GDAL ' + FVersion + sLineBreak +
    'Bindings Pascal adaptados de gdal-pascal (Alex Bruy).');
end;

end.
