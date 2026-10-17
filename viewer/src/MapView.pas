unit MapView;

interface

uses
  GeometryModel;

type
  {
    Estado de la vista del mapa y transformación mundo <-> pantalla.

    - El mundo usa coordenadas cartesianas/geográficas (Y crece hacia arriba).
    - La pantalla usa píxeles con origen arriba-izquierda (Y crece hacia abajo).
    - FCenterWorld es el punto del mundo situado en el centro del viewport.
    - FScale son los píxeles por unidad del mundo.

    Unidad pura: no depende de VCL ni de GDAL.
  }
  TMapView = class
  private
    FCenterWorld: TPointD;
    FScale: Double;
    FViewportW: Integer;
    FViewportH: Integer;
  public
    constructor Create;

    property CenterWorld: TPointD read FCenterWorld write FCenterWorld;
    property Scale: Double read FScale write FScale;
    property ViewportW: Integer read FViewportW write FViewportW;
    property ViewportH: Integer read FViewportH write FViewportH;

    procedure WorldToScreen(const P: TPointD; out X, Y: Double);
    function ScreenToWorld(const X, Y: Double): TPointD;

    procedure ZoomBy(Factor: Double; AnchorX, AnchorY: Double);
    procedure ZoomByFactor(Factor: Double);
    procedure PanBy(DxPx, DyPx: Double);
    procedure FitBounds(const MinPt, MaxPt: TPointD; VPx, VPy: Integer;
      Margin: Double = 0.05);
  end;

implementation

constructor TMapView.Create;
begin
  inherited Create;
  FCenterWorld := MakePoint(0, 0);
  FScale := 1;
  FViewportW := 100;
  FViewportH := 100;
end;

procedure TMapView.WorldToScreen(const P: TPointD; out X, Y: Double);
begin
  X := FViewportW / 2 + (P.X - FCenterWorld.X) * FScale;
  Y := FViewportH / 2 - (P.Y - FCenterWorld.Y) * FScale;
end;

function TMapView.ScreenToWorld(const X, Y: Double): TPointD;
begin
  Result.X := FCenterWorld.X + (X - FViewportW / 2) / FScale;
  Result.Y := FCenterWorld.Y - (Y - FViewportH / 2) / FScale;
end;

procedure TMapView.ZoomBy(Factor: Double; AnchorX, AnchorY: Double);
var
  W: TPointD;
begin
  if Factor <= 0 then
    Exit;
  W := ScreenToWorld(AnchorX, AnchorY);
  FScale := FScale * Factor;
  { Mantener el punto del mundo W bajo la pantalla (AnchorX, AnchorY). }
  FCenterWorld.X := W.X - (AnchorX - FViewportW / 2) / FScale;
  FCenterWorld.Y := W.Y + (AnchorY - FViewportH / 2) / FScale;
end;

procedure TMapView.ZoomByFactor(Factor: Double);
begin
  ZoomBy(Factor, FViewportW / 2, FViewportH / 2);
end;

procedure TMapView.PanBy(DxPx, DyPx: Double);
begin
  FCenterWorld.X := FCenterWorld.X - DxPx / FScale;
  FCenterWorld.Y := FCenterWorld.Y + DyPx / FScale;
end;

procedure TMapView.FitBounds(const MinPt, MaxPt: TPointD; VPx, VPy: Integer;
  Margin: Double);
var
  W, H, Sx, Sy: Double;
begin
  if VPx <= 0 then VPx := 1;
  if VPy <= 0 then VPy := 1;
  FViewportW := VPx;
  FViewportH := VPy;

  W := MaxPt.X - MinPt.X;
  H := MaxPt.Y - MinPt.Y;

  if Margin > 0 then begin
    W := W * (1 + 2 * Margin);
    H := H * (1 + 2 * Margin);
  end;

  FCenterWorld := MakePoint((MinPt.X + MaxPt.X) / 2, (MinPt.Y + MaxPt.Y) / 2);

  if (W <= 0) and (H <= 0) then
    FScale := 1
  else if W <= 0 then
    FScale := FViewportH / H
  else if H <= 0 then
    FScale := FViewportW / W
  else begin
    Sx := FViewportW / W;
    Sy := FViewportH / H;
    if Sx < Sy then
      FScale := Sx
    else
      FScale := Sy;
  end;
end;

end.
