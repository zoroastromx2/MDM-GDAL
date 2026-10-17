unit Main;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.UITypes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Menus,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Dialogs,
  gdalcore,
  ogr,
  GeometryModel,
  MapView,
  VectorLayer,
  MapCanvas,
  IdentifyForm,
  LayerStyleForm,
  AttributesForm;

const
  { Paleta de colores por defecto para distinguir capas (TColor = $00BBGGRR). }
  LayerPalette: array[0..9] of TColor = (
    $00FF0000,  // azul
    $000000FF,  // rojo
    $0000FF00,  // verde
    $0000A5FF,  // naranja
    $00FF00FF,  // magenta
    $00A000A0,  // morado
    $0000FFFF,  // amarillo
    $00FFFF00,  // cian
    $00808000,  // teal
    $00000080   // granate
  );

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
    miViewIdentify: TMenuItem;
    miViewRubber: TMenuItem;
    miViewAttributes: TMenuItem;
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
    procedure miViewAttributesClick(Sender: TObject);
    procedure miHelpAboutClick(Sender: TObject);
  private
    FCanvas: TMapCanvas;
    FLayers: TObjectList<TVectorLayer>;
    FIdentify: TIdentifyForm;
    FStyleForm: TLayerStyleForm;
    FAttributes: TAttributesForm;
    FTree: TTreeView;
    FPopup: TPopupMenu;
    FVersion: string;
    FNextColor: Integer;
    procedure CanvasMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure CanvasIdentify(Sender: TObject; ScreenX, ScreenY: Integer);
    procedure TreeMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure TreeDblClick(Sender: TObject);
    procedure RemoveLayerClick(Sender: TObject);
    procedure PropertiesClick(Sender: TObject);
    procedure AttributesClick(Sender: TObject);
    procedure EditSelectedLayerStyle;
    procedure ShowSelectedLayerAttributes;
    procedure SyncParentCheck(node: TTreeNode);
    procedure UpdateStatus;
    procedure LoadProgress(const LayerName: string; Current, Total: Integer);
    procedure OpenFile(const FileName: string);
    procedure RebuildTree;
    function NodeLayerIndex(node: TTreeNode): Integer;
    function SelectedLayerIndex: Integer;
    procedure RemoveSelectedNode;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);
var
  Panel: TPanel;
  Split: TSplitter;
  miRemove: TMenuItem;
  miProperties: TMenuItem;
  miAttributes: TMenuItem;
begin
  FLayers := TObjectList<TVectorLayer>.Create;
  FIdentify := TIdentifyForm.Create(Self);
  FStyleForm := TLayerStyleForm.Create(Self);
  FAttributes := TAttributesForm.Create(Self);
  FNextColor := 0;

  { panel izquierdo con el arbol de capas }
  Panel := TPanel.Create(Self);
  Panel.Parent := Self;
  Panel.Align := alLeft;
  Panel.Width := 240;
  Panel.Caption := '';

  FTree := TTreeView.Create(Panel);
  FTree.Parent := Panel;
  FTree.Align := alClient;
  FTree.CheckBoxes := True;
  FTree.ReadOnly := True;
  FTree.HideSelection := False;
  FTree.RightClickSelect := True;
  FTree.OnMouseDown := TreeMouseDown;
  FTree.OnDblClick := TreeDblClick;

  { menu contextual del arbol }
  FPopup := TPopupMenu.Create(Self);

  miRemove := TMenuItem.Create(FPopup);
  miRemove.Caption := 'Quitar capa';
  miRemove.OnClick := RemoveLayerClick;
  FPopup.Items.Add(miRemove);

  miProperties := TMenuItem.Create(FPopup);
  miProperties.Caption := 'Propiedades...';
  miProperties.OnClick := PropertiesClick;
  FPopup.Items.Add(miProperties);

  miAttributes := TMenuItem.Create(FPopup);
  miAttributes.Caption := 'Atributos...';
  miAttributes.OnClick := AttributesClick;
  FPopup.Items.Add(miAttributes);

  FTree.PopupMenu := FPopup;

  Split := TSplitter.Create(Self);
  Split.Parent := Self;
  Split.Align := alLeft;
  Split.Width := 4;

  FCanvas := TMapCanvas.Create(Self);
  FCanvas.Parent := Self;
  FCanvas.Align := alClient;
  FCanvas.OnMouseMove := CanvasMouseMove;
  FCanvas.OnIdentify := CanvasIdentify;
  FCanvas.SetLayers(FLayers);

  OpenDialog1.Filter :=
    'Archivos vectoriales|*.shp;*.geojson;*.json;*.kml;*.kmz;*.gpkg;*.tab;*.mif;*.gml|' +
    'Todos los archivos|*.*';
  OpenDialog1.Options := OpenDialog1.Options + [ofAllowMultiSelect];

  StatusBar1.SimplePanel := True;
  OGRRegisterAll;
  FVersion := UTF8ToString(GDALVersionInfo('MDM-GDAL_beta'));
  Caption := 'MDM Viewer';
  UpdateStatus;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FLayers.Free;
end;

procedure TMainForm.UpdateStatus;
var
  i, total: Integer;
begin
  total := 0;
  for i := 0 to FLayers.Count - 1 do
    Inc(total, FLayers[i].FeatureCount);

  if FLayers.Count > 0 then
    StatusBar1.SimpleText := Format('GDAL %s | %d capas | %d entidades',
      [FVersion, FLayers.Count, total])
  else
    StatusBar1.SimpleText := Format('GDAL %s', [FVersion]);
end;

function TMainForm.NodeLayerIndex(node: TTreeNode): Integer;
begin
  if (node = nil) or (node.Data = nil) then
    Result := -1
  else
    Result := Integer(node.Data) - 1;
end;

procedure TMainForm.RebuildTree;
var
  i, j, start, groupCount: Integer;
  parent, child: TTreeNode;
begin
  FTree.Items.BeginUpdate;
  try
    FTree.Items.Clear;
    i := 0;
    while i < FLayers.Count do begin
      { Agrupar las capas consecutivas que vienen del mismo archivo. }
      start := i;
      groupCount := 1;
      while (start + groupCount < FLayers.Count) and
            (FLayers[start + groupCount].FileName = FLayers[start].FileName) do
        Inc(groupCount);

      if groupCount = 1 then begin
        { Archivo con una sola capa (shapefile): un solo nodo. }
        child := FTree.Items.Add(nil, ExtractFileName(FLayers[start].FileName));
        child.Data := Pointer(start + 1);
        child.Checked := FLayers[start].Visible;
      end
      else begin
        { Archivo con varias capas (gpkg): nodo archivo + subnodos capa. }
        parent := FTree.Items.Add(nil, ExtractFileName(FLayers[start].FileName));
        for j := start to start + groupCount - 1 do begin
          child := FTree.Items.AddChild(parent, FLayers[j].LayerName);
          child.Data := Pointer(j + 1);
          child.Checked := FLayers[j].Visible;
        end;
      end;

      i := start + groupCount;
    end;
  finally
    FTree.Items.EndUpdate;
  end;
end;

function TMainForm.SelectedLayerIndex: Integer;
begin
  Result := NodeLayerIndex(FTree.Selected);
end;

procedure TMainForm.SyncParentCheck(node: TTreeNode);
var
  parent: TTreeNode;
  i: Integer;
  allChecked: Boolean;
begin
  parent := node.Parent;
  if parent = nil then
    Exit;
  allChecked := True;
  for i := 0 to parent.Count - 1 do
    if not parent.Item[i].Checked then begin
      allChecked := False;
      Break;
    end;
  parent.Checked := allChecked;
end;

procedure TMainForm.TreeMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  node: TTreeNode;
  hit: THitTests;
  idx, i: Integer;
  newState: Boolean;
  changed: Boolean;
begin
  if Button <> mbLeft then
    Exit;

  node := FTree.GetNodeAt(X, Y);
  if node = nil then
    Exit;

  { Solo actuar al pulsar sobre el checkbox (icono de estado). }
  hit := FTree.GetHitTestInfoAt(X, Y);
  if not (htOnStateIcon in hit) then
    Exit;

  { FTree.Selected puede no cambiar al pulsar el checkbox; se usa el nodo
    bajo el cursor. El control ya alterno el checkbox antes de este evento,
    por lo que node.Checked es el estado nuevo. }
  newState := node.Checked;
  changed := False;

  if node.Data = nil then begin
    { Nodo archivo: aplicar el nuevo estado a todas sus capas hijas. }
    for i := 0 to node.Count - 1 do begin
      idx := NodeLayerIndex(node.Item[i]);
      if (idx >= 0) and (idx < FLayers.Count) then begin
        FLayers[idx].Visible := newState;
        node.Item[i].Checked := newState;
        changed := True;
      end;
    end;
  end
  else begin
    idx := Integer(node.Data) - 1;
    if (idx >= 0) and (idx < FLayers.Count) then begin
      FLayers[idx].Visible := newState;
      changed := True;
    end;
    SyncParentCheck(node);
  end;

  if changed then
    FCanvas.Invalidate;
end;

procedure TMainForm.TreeDblClick(Sender: TObject);
begin
  if SelectedLayerIndex >= 0 then
    EditSelectedLayerStyle;
end;

procedure TMainForm.RemoveLayerClick(Sender: TObject);
begin
  RemoveSelectedNode;
end;

procedure TMainForm.RemoveSelectedNode;
var
  node: TTreeNode;
  idx, i: Integer;
begin
  node := FTree.Selected;
  if node = nil then
    Exit;

  if node.Data = nil then begin
    { Nodo archivo: quitar todas sus capas (de mayor a menor indice). }
    for i := node.Count - 1 downto 0 do begin
      idx := NodeLayerIndex(node.Item[i]);
      if (idx >= 0) and (idx < FLayers.Count) then
        FLayers.Delete(idx);
    end;
  end
  else begin
    idx := Integer(node.Data) - 1;
    if (idx >= 0) and (idx < FLayers.Count) then
      FLayers.Delete(idx);
  end;

  RebuildTree;
  FCanvas.ZoomToFit;
  UpdateStatus;
end;

procedure TMainForm.PropertiesClick(Sender: TObject);
begin
  EditSelectedLayerStyle;
end;

procedure TMainForm.EditSelectedLayerStyle;
var
  idx: Integer;
begin
  idx := SelectedLayerIndex;
  if idx < 0 then
    Exit;
  FStyleForm.Execute(FLayers[idx]);
  FCanvas.Invalidate;
end;

procedure TMainForm.AttributesClick(Sender: TObject);
begin
  ShowSelectedLayerAttributes;
end;

procedure TMainForm.ShowSelectedLayerAttributes;
var
  idx: Integer;
begin
  idx := SelectedLayerIndex;
  if idx < 0 then
    Exit;
  FAttributes.ShowLayer(FLayers[idx]);
  FAttributes.Show;
end;

procedure TMainForm.LoadProgress(const LayerName: string; Current, Total: Integer);
begin
  if Total > 0 then
    StatusBar1.SimpleText := Format('Cargando %s: %d / %d', [LayerName, Current, Total])
  else
    StatusBar1.SimpleText := Format('Cargando %s: %d', [LayerName, Current]);
  Application.ProcessMessages;
end;

procedure TMainForm.OpenFile(const FileName: string);
var
  Layers: TArray<TVectorLayer>;
  i: Integer;
  c: TColor;
begin
  miFile.Enabled := False;
  miView.Enabled := False;
  try
    try
      Layers := TVectorLayer.LoadLayers(FileName, LoadProgress);
      for i := 0 to High(Layers) do begin
        c := LayerPalette[FNextColor mod Length(LayerPalette)];
        Layers[i].FillColor := c;
        Layers[i].LineColor := c;
        Inc(FNextColor);
        FLayers.Add(Layers[i]);
      end;
      RebuildTree;
      FCanvas.ZoomToFit;
      UpdateStatus;
    except
      on E: Exception do
        ShowMessage('Error al abrir el archivo:' + sLineBreak + E.Message);
    end;
  finally
    miFile.Enabled := True;
    miView.Enabled := True;
  end;
end;

procedure TMainForm.CanvasMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  w: TPointD;
  total: Integer;
  i: Integer;
begin
  if FLayers.Count = 0 then
    Exit;
  w := FCanvas.View.ScreenToWorld(X, Y);
  total := 0;
  for i := 0 to FLayers.Count - 1 do
    Inc(total, FLayers[i].FeatureCount);
  StatusBar1.SimpleText := Format('GDAL %s | %d capas | %d entidades | X=%.3f Y=%.3f',
    [FVersion, FLayers.Count, total, w.X, w.Y]);
end;

procedure TMainForm.CanvasIdentify(Sender: TObject; ScreenX, ScreenY: Integer);
var
  li, fi: Integer;
begin
  if not miViewIdentify.Checked then
    Exit;
  FCanvas.IdentifyAt(ScreenX, ScreenY, 5, li, fi);
  if (li >= 0) and (fi >= 0) then begin
    FIdentify.ShowFeature(FLayers[li], fi);
    FIdentify.Show;
  end;
end;

procedure TMainForm.miFileOpenClick(Sender: TObject);
var
  i: Integer;
begin
  if not OpenDialog1.Execute then
    Exit;
  if OpenDialog1.Files.Count > 0 then begin
    for i := 0 to OpenDialog1.Files.Count - 1 do
      OpenFile(OpenDialog1.Files[i]);
  end
  else
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

procedure TMainForm.miViewAttributesClick(Sender: TObject);
begin
  ShowSelectedLayerAttributes;
end;

procedure TMainForm.miHelpAboutClick(Sender: TObject);
begin
  ShowMessage('MDM-GDAL' + sLineBreak + sLineBreak +
    'Visor de datos vectoriales con GDAL ' + FVersion + sLineBreak +
    'Bindings Pascal adaptados de gdal-pascal (Alex Bruy).');
end;

end.
