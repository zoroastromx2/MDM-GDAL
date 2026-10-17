unit MapCanvas;

interface

uses
  System.Classes,
  System.Types,
  Winapi.Windows,
  Vcl.Controls,
  Vcl.Graphics,
  GeometryModel,
  MapView,
  VectorLayer;

type
  TIdentifyEvent = procedure(Sender: TObject; ScreenX, ScreenY: Integer) of object;

  {
    Control VCL que dibuja una TVectorLayer y gestiona la interaccion:
    - rueda del raton  -> zoom anclado al cursor
    - arrastrar        -> pan
    - modo caja        -> arrastrar dibuja un rectangulo y hace zoom a esa region
    - clic sin mover   -> evento OnIdentify (se resuelve en tareas 6/7)
  }
  TMapCanvas = class(TCustomControl)
  private
    FView: TMapView;
    FLayer: TVectorLayer;
    FColor: TColor;
    FRubberBandMode: Boolean;
    FOnIdentify: TIdentifyEvent;

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

    procedure SetLayer(Value: TVectorLayer);
    procedure ZoomIn;
    procedure ZoomOut;
    procedure ZoomToFit;

    property View: TMapView read FView;
    property Layer: TVectorLayer read FLayer;
    property Color: TColor read FColor write FColor;
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
  FColor := clBlue;
  FRubberBandMode := False;
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

procedure TMapCanvas.SetLayer(Value: TVectorLayer);
begin
  FLayer := Value;
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
  Canvas.Brush.Color := FColor;
  Canvas.Pen.Color := FColor;
  Canvas.Ellipse(Integer(Round(x)) - r, Integer(Round(y)) - r,
                 Integer(Round(x)) + r, Integer(Round(y)) + r);
end;

procedure TMapCanvas.DrawLine(const Pts: TPointArray);
begin
  Canvas.Pen.Color := FColor;
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

  Canvas.Brush.Color := FColor;
  Canvas.Pen.Color := FColor;
  if Length(allPts) > 0 then
    PolyPolygon(Canvas.Handle, allPts[0], counts[0], Length(counts));
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
  Canvas.Rectangle(r);
  Canvas.Pen.Style := psSolid;
  Canvas.Brush.Style := bsSolid;
end;

procedure TMapCanvas.Paint;
var
  i: Integer;
begin
  inherited Paint;
  Canvas.Brush.Color := clWhite;
  Canvas.FillRect(ClientRect);

  FView.ViewportW := ClientWidth;
  FView.ViewportH := ClientHeight;

  if FLayer = nil then
    Exit;

  for i := 0 to FLayer.FeatureCount - 1 do
    DrawGeometry(FLayer.Features[i].Geometry);

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
  if FLayer = nil then
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
begin
  if (FLayer <> nil) and (not FLayer.Extent.IsEmpty) then
    FView.FitBounds(MakePoint(FLayer.Extent.MinX, FLayer.Extent.MinY),
                    MakePoint(FLayer.Extent.MaxX, FLayer.Extent.MaxY),
                    ClientWidth, ClientHeight);
  Invalidate;
end;

end.
