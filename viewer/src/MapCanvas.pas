unit MapCanvas;

interface

uses
  System.Classes,
  System.Types,
  System.Generics.Collections,
  Winapi.Windows,
  Vcl.Controls,
  Vcl.Graphics,
  GeometryModel,
  MapView,
  VectorLayer;

type
  TIdentifyEvent = procedure(Sender: TObject; ScreenX, ScreenY: Integer) of object;

  {
    Control VCL que dibuja una lista de TVectorLayer y gestiona la interaccion:
    - rueda del raton  -> zoom anclado al cursor
    - arrastrar        -> pan
    - modo caja        -> arrastrar dibuja un rectangulo y hace zoom a esa region
    - clic sin mover   -> evento OnIdentify (se resuelve en Main)
  }
  TMapCanvas = class(TCustomControl)
  private
    FView: TMapView;
    FLayers: TList<TVectorLayer>;
    FRubberBandMode: Boolean;
    FOnIdentify: TIdentifyEvent;

    { estilo de la capa que se esta dibujando (se fija por capa antes de pintar) }
    FCurFill: TColor;
    FCurLine: TColor;
    FCurFillEnabled: Boolean;
    FCurLineWidth: Integer;

    FDown: Boolean;
    FPanning: Boolean;
    FRubberActive: Boolean;
    FMoved: Boolean;
    FDownX, FDownY: Integer;
    FLastX, FLastY: Integer;
    FRubberX1, FRubberY1: Integer;

    function WorldToScreenPts(const Pts: TPointArray): TArray<TPoint>;
    procedure DrawGeometry(const G: TFeatureGeometry);
    procedure DrawPointMarker(const P: TPointD);
    procedure DrawLine(const Pts: TPointArray);
    procedure DrawPolygon(const Rings: array of TPointArray);
    procedure DrawRubberBand;
    procedure ZoomToRect(X0, Y0, X1, Y1: Integer);
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure SetLayers(Value: TList<TVectorLayer>);
    procedure ZoomIn;
    procedure ZoomOut;
    procedure ZoomToFit;
    function IdentifyAt(ScreenX, ScreenY: Integer; TolerancePx: Double;
      out LayerIndex: Integer; out FeatureIndex: Integer): Double;

    property View: TMapView read FView;
    property Layers: TList<TVectorLayer> read FLayers;
    property RubberBandMode: Boolean read FRubberBandMode write FRubberBandMode;
    property OnIdentify: TIdentifyEvent read FOnIdentify write FOnIdentify;

    { re-promover eventos protegidos de TControl }
    property OnMouseMove;
    property OnMouseDown;
    property OnMouseUp;
  end;

implementation

constructor TMapCanvas.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FView := TMapView.Create;
  FRubberBandMode := False;
  FCurFill := $00FF0000;   // azul (BGR)
  FCurLine := $00FF0000;
  FCurFillEnabled := True;
  FCurLineWidth := 1;
  DoubleBuffered := True;
end;

destructor TMapCanvas.Destroy;
begin
  FView.Free;
  inherited Destroy;
end;

procedure TMapCanvas.Resize;
begin
  inherited Resize;
  FView.ViewportW := ClientWidth;
  FView.ViewportH := ClientHeight;
  Invalidate;
end;

procedure TMapCanvas.SetLayers(Value: TList<TVectorLayer>);
begin
  FLayers := Value;
  ZoomToFit;
end;

function TMapCanvas.WorldToScreenPts(const Pts: TPointArray): TArray<TPoint>;
var
  i: Integer;
  x, y: Double;
begin
  SetLength(Result, Length(Pts));
  for i := 0 to High(Pts) do begin
    FView.WorldToScreen(Pts[i], x, y);
    Result[i] := Point(Integer(Round(x)), Integer(Round(y)));
  end;
end;

procedure TMapCanvas.DrawPointMarker(const P: TPointD);
var
  x, y: Double;
  r: Integer;
begin
  FView.WorldToScreen(P, x, y);
  r := 3;
  Canvas.Brush.Color := FCurFill;
  Canvas.Pen.Color := FCurLine;
  Canvas.Pen.Width := FCurLineWidth;
  Canvas.Ellipse(Integer(Round(x)) - r, Integer(Round(y)) - r,
                 Integer(Round(x)) + r, Integer(Round(y)) + r);
end;

procedure TMapCanvas.DrawLine(const Pts: TPointArray);
begin
  Canvas.Pen.Color := FCurLine;
  Canvas.Pen.Width := FCurLineWidth;
  Canvas.Brush.Style := bsClear;
  Canvas.Polyline(WorldToScreenPts(Pts));
  Canvas.Brush.Style := bsSolid;
end;

procedure TMapCanvas.DrawPolygon(const Rings: array of TPointArray);
var
  i, j, total: Integer;
  allPts: TArray<TPoint>;
  counts: TArray<Integer>;
  scr: TArray<TPoint>;
begin
  if Length(Rings) = 0 then
    Exit;

  total := 0;
  SetLength(counts, Length(Rings));
  for i := 0 to High(Rings) do begin
    counts[i] := Length(Rings[i]);
    Inc(total, Length(Rings[i]));
  end;

  SetLength(allPts, total);
  total := 0;
  for i := 0 to High(Rings) do begin
    scr := WorldToScreenPts(Rings[i]);
    for j := 0 to High(scr) do begin
      allPts[total] := scr[j];
      Inc(total);
    end;
  end;

  Canvas.Brush.Color := FCurFill;
  Canvas.Pen.Color := FCurLine;
  Canvas.Pen.Width := FCurLineWidth;
  if not FCurFillEnabled then
    Canvas.Brush.Style := bsClear;
  if Length(allPts) > 0 then
    PolyPolygon(Canvas.Handle, allPts[0], counts[0], Length(counts));
  Canvas.Brush.Style := bsSolid;
end;

procedure TMapCanvas.DrawGeometry(const G: TFeatureGeometry);
var
  i: Integer;
begin
  case G.Kind of
    gkPoint:
      if Length(G.Points) > 0 then
        DrawPointMarker(G.Points[0]);

    gkLineString:
      DrawLine(G.Points);

    gkPolygon:
      DrawPolygon(G.Rings);

    gkMultiPoint, gkMultiLineString, gkMultiPolygon:
      for i := 0 to High(G.Parts) do
        DrawGeometry(G.Parts[i]);
  end;
end;

procedure TMapCanvas.DrawRubberBand;
var
  r: TRect;
begin
  if not FRubberActive then
    Exit;
  r := Rect(FDownX, FDownY, FRubberX1, FRubberY1);
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Style := psDash;
  Canvas.Pen.Color := clBlack;
  Canvas.Pen.Width := 1;
  Canvas.Rectangle(r);
  Canvas.Pen.Style := psSolid;
  Canvas.Brush.Style := bsSolid;
end;

procedure TMapCanvas.Paint;
var
  li, i: Integer;
  layer: TVectorLayer;
begin
  inherited Paint;
  Canvas.Brush.Color := clWhite;
  Canvas.FillRect(ClientRect);

  FView.ViewportW := ClientWidth;
  FView.ViewportH := ClientHeight;

  if FLayers = nil then
    Exit;

  for li := 0 to FLayers.Count - 1 do begin
    layer := FLayers[li];
    if not layer.Visible then
      Continue;
    FCurFill := layer.FillColor;
    FCurLine := layer.LineColor;
    FCurFillEnabled := layer.FillEnabled;
    FCurLineWidth := layer.LineWidth;
    for i := 0 to layer.FeatureCount - 1 do
      DrawGeometry(layer.Features[i].Geometry);
  end;

  DrawRubberBand;
end;

procedure TMapCanvas.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited;
  if Button <> mbLeft then
    Exit;

  FDown := True;
  FMoved := False;
  FDownX := X;
  FDownY := Y;
  FLastX := X;
  FLastY := Y;

  if FRubberBandMode then begin
    FRubberActive := True;
    FRubberX1 := X;
    FRubberY1 := Y;
  end
  else begin
    FPanning := True;
  end;
end;

procedure TMapCanvas.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if not FDown then
    Exit;

  if (Abs(X - FDownX) > 3) or (Abs(Y - FDownY) > 3) then
    FMoved := True;

  if FPanning then begin
    FView.PanBy(X - FLastX, Y - FLastY);
    FLastX := X;
    FLastY := Y;
    Invalidate;
  end
  else if FRubberActive then begin
    FRubberX1 := X;
    FRubberY1 := Y;
    Invalidate;
  end;
end;

procedure TMapCanvas.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited;
  if Button <> mbLeft then
    Exit;

  if FRubberActive then begin
    if (Abs(X - FDownX) > 3) and (Abs(Y - FDownY) > 3) then
      ZoomToRect(FDownX, FDownY, X, Y);
    FRubberActive := False;
  end
  else if FPanning then begin
    FPanning := False;
    if not FMoved then begin
      if Assigned(FOnIdentify) then
        FOnIdentify(Self, X, Y);
    end;
  end;

  FDown := False;
  Invalidate;
end;

function TMapCanvas.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
var
  P: TPoint;
  Factor: Double;
begin
  Result := True;
  if (FLayers = nil) or (FLayers.Count = 0) then
    Exit;

  P := ScreenToClient(MousePos);
  if WheelDelta > 0 then
    Factor := 1.1
  else
    Factor := 1 / 1.1;
  FView.ZoomBy(Factor, P.X, P.Y);
  Invalidate;
end;

procedure TMapCanvas.ZoomToRect(X0, Y0, X1, Y1: Integer);
var
  w0, w1, minPt, maxPt: TPointD;
begin
  w0 := FView.ScreenToWorld(X0, Y0);
  w1 := FView.ScreenToWorld(X1, Y1);

  if w0.X < w1.X then begin minPt.X := w0.X; maxPt.X := w1.X; end
                 else begin minPt.X := w1.X; maxPt.X := w0.X; end;
  if w0.Y < w1.Y then begin minPt.Y := w0.Y; maxPt.Y := w1.Y; end
                 else begin minPt.Y := w1.Y; maxPt.Y := w0.Y; end;

  FView.FitBounds(minPt, maxPt, ClientWidth, ClientHeight, 0);
  Invalidate;
end;

procedure TMapCanvas.ZoomIn;
begin
  FView.ZoomByFactor(1.25);
  Invalidate;
end;

procedure TMapCanvas.ZoomOut;
begin
  FView.ZoomByFactor(0.8);
  Invalidate;
end;

procedure TMapCanvas.ZoomToFit;
var
  i: Integer;
  E: TExtent;
  found: Boolean;
begin
  ExtentReset(E);
  found := False;

  if FLayers <> nil then begin
    for i := 0 to FLayers.Count - 1 do begin
      if (not FLayers[i].Visible) or FLayers[i].Extent.IsEmpty then
        Continue;
      if not found then begin
        E := FLayers[i].Extent;
        found := True;
      end
      else begin
        if FLayers[i].Extent.MinX < E.MinX then E.MinX := FLayers[i].Extent.MinX;
        if FLayers[i].Extent.MinY < E.MinY then E.MinY := FLayers[i].Extent.MinY;
        if FLayers[i].Extent.MaxX > E.MaxX then E.MaxX := FLayers[i].Extent.MaxX;
        if FLayers[i].Extent.MaxY > E.MaxY then E.MaxY := FLayers[i].Extent.MaxY;
      end;
    end;
  end;

  if found then
    FView.FitBounds(MakePoint(E.MinX, E.MinY), MakePoint(E.MaxX, E.MaxY),
                    ClientWidth, ClientHeight);
  Invalidate;
end;

function TMapCanvas.IdentifyAt(ScreenX, ScreenY: Integer; TolerancePx: Double;
  out LayerIndex: Integer; out FeatureIndex: Integer): Double;
var
  w: TPointD;
  tol: Double;
  i, idx: Integer;
  d: Double;
begin
  LayerIndex := -1;
  FeatureIndex := -1;
  Result := 1e300;

  if (FLayers = nil) or (FLayers.Count = 0) then
    Exit;

  w := FView.ScreenToWorld(ScreenX, ScreenY);
  tol := TolerancePx / FView.Scale;

  for i := 0 to FLayers.Count - 1 do begin
    if not FLayers[i].Visible then
      Continue;
    d := FindNearestFeature(FLayers[i].Features, w, idx);
    if (idx >= 0) and (d < Result) then begin
      Result := d;
      LayerIndex := i;
      FeatureIndex := idx;
    end;
  end;

  if Result > tol then begin
    LayerIndex := -1;
    FeatureIndex := -1;
  end;
end;

end.
