unit GeometryModel;

interface

type
  TPointD = record
    X: Double;
    Y: Double;
  end;

  TPointArray = array of TPointD;

  TGeometryKind = (
    gkPoint,
    gkLineString,
    gkPolygon,
    gkMultiPoint,
    gkMultiLineString,
    gkMultiPolygon
  );

  {
    Modelo geométrico puro, sin dependencias de VCL ni GDAL.

    - gkPoint            -> Points[0]
    - gkLineString       -> Points (lista de vértices)
    - gkPolygon          -> Rings: anillo exterior + agujeros (cada anillo cerrado)
    - gkMulti*           -> Parts: sub-geometrías simples (punto/línea/polígono)
  }
  TFeatureGeometry = record
    Kind: TGeometryKind;
    Points: TPointArray;                 { punto / línea }
    Rings: array of TPointArray;         { polígono }
    Parts: array of TFeatureGeometry;    { multi-* }
  end;

  TFeature = record
    FID: Int64;
    Geometry: TFeatureGeometry;
  end;
  TFeatureArray = array of TFeature;

  TExtent = record
    MinX: Double;
    MinY: Double;
    MaxX: Double;
    MaxY: Double;
    IsEmpty: Boolean;
  end;

function MakePoint(const X, Y: Double): TPointD;
function MakeLine(const Points: TPointArray): TFeatureGeometry;
function MakePolygon(const Rings: array of TPointArray): TFeatureGeometry;

function GeometryIsEmpty(const G: TFeatureGeometry): Boolean;

procedure ExtentReset(var E: TExtent);
procedure ExtentIncludePoint(var E: TExtent; const P: TPointD);
procedure GeometryExtent(const G: TFeatureGeometry; var E: TExtent);
function FeaturesExtent(const Features: TFeatureArray): TExtent;

function ExtentWidth(const E: TExtent): Double;
function ExtentHeight(const E: TExtent): Double;
function ExtentCenter(const E: TExtent): TPointD;

{ Hit-testing puro (sin VCL ni GDAL) }
function PointInRing(const P: TPointD; const Ring: TPointArray): Boolean;
function PointInPolygon(const P: TPointD; const Rings: array of TPointArray): Boolean;
function DistanceToGeometry(const P: TPointD; const G: TFeatureGeometry): Double;
function FindNearestFeature(const Features: TFeatureArray; const P: TPointD;
  out Index: Integer): Double;

implementation

function MakePoint(const X, Y: Double): TPointD;
begin
  Result.X := X;
  Result.Y := Y;
end;

function MakeLine(const Points: TPointArray): TFeatureGeometry;
begin
  Result.Kind := gkLineString;
  Result.Points := Points;
end;

function MakePolygon(const Rings: array of TPointArray): TFeatureGeometry;
var
  i: Integer;
begin
  Result.Kind := gkPolygon;
  SetLength(Result.Rings, Length(Rings));
  for i := 0 to High(Rings) do
    Result.Rings[i] := Rings[i];
end;

function GeometryIsEmpty(const G: TFeatureGeometry): Boolean;
begin
  case G.Kind of
    gkPoint:       Result := Length(G.Points) = 0;
    gkLineString:  Result := Length(G.Points) = 0;
    gkPolygon:     Result := Length(G.Rings) = 0;
    gkMultiPoint,
    gkMultiLineString,
    gkMultiPolygon: Result := Length(G.Parts) = 0;
  else
    Result := True;
  end;
end;

procedure ExtentReset(var E: TExtent);
begin
  E.MinX := 0;
  E.MinY := 0;
  E.MaxX := 0;
  E.MaxY := 0;
  E.IsEmpty := True;
end;

procedure ExtentIncludePoint(var E: TExtent; const P: TPointD);
begin
  if E.IsEmpty then begin
    E.MinX := P.X;
    E.MaxX := P.X;
    E.MinY := P.Y;
    E.MaxY := P.Y;
    E.IsEmpty := False;
  end
  else begin
    if P.X < E.MinX then E.MinX := P.X;
    if P.X > E.MaxX then E.MaxX := P.X;
    if P.Y < E.MinY then E.MinY := P.Y;
    if P.Y > E.MaxY then E.MaxY := P.Y;
  end;
end;

procedure GeometryExtent(const G: TFeatureGeometry; var E: TExtent);
var
  i, j: Integer;
begin
  case G.Kind of
    gkPoint, gkLineString:
      for i := 0 to High(G.Points) do
        ExtentIncludePoint(E, G.Points[i]);

    gkPolygon:
      for i := 0 to High(G.Rings) do
        for j := 0 to High(G.Rings[i]) do
          ExtentIncludePoint(E, G.Rings[i][j]);

    gkMultiPoint, gkMultiLineString, gkMultiPolygon:
      for i := 0 to High(G.Parts) do
        GeometryExtent(G.Parts[i], E);
  end;
end;

function FeaturesExtent(const Features: TFeatureArray): TExtent;
var
  i: Integer;
begin
  ExtentReset(Result);
  for i := 0 to High(Features) do
    GeometryExtent(Features[i].Geometry, Result);
end;

function ExtentWidth(const E: TExtent): Double;
begin
  if E.IsEmpty then
    Result := 0
  else
    Result := E.MaxX - E.MinX;
end;

function ExtentHeight(const E: TExtent): Double;
begin
  if E.IsEmpty then
    Result := 0
  else
    Result := E.MaxY - E.MinY;
end;

function ExtentCenter(const E: TExtent): TPointD;
begin
  if E.IsEmpty then begin
    Result.X := 0;
    Result.Y := 0;
  end
  else begin
    Result.X := (E.MinX + E.MaxX) / 2;
    Result.Y := (E.MinY + E.MaxY) / 2;
  end;
end;

function PointInRing(const P: TPointD; const Ring: TPointArray): Boolean;
var
  i, j, n: Integer;
begin
  n := Length(Ring);
  Result := False;
  if n < 3 then
    Exit;
  j := n - 1;
  for i := 0 to n - 1 do begin
    if ((Ring[i].Y > P.Y) <> (Ring[j].Y > P.Y)) and
       (P.X < (Ring[j].X - Ring[i].X) * (P.Y - Ring[i].Y) /
              (Ring[j].Y - Ring[i].Y) + Ring[i].X) then
      Result := not Result;
    j := i;
  end;
end;

function PointInPolygon(const P: TPointD; const Rings: array of TPointArray): Boolean;
var
  i: Integer;
begin
  if Length(Rings) = 0 then begin
    Result := False;
    Exit;
  end;
  if not PointInRing(P, Rings[0]) then begin
    Result := False;
    Exit;
  end;
  for i := 1 to High(Rings) do
    if PointInRing(P, Rings[i]) then begin
      Result := False;   // dentro de un agujero
      Exit;
    end;
  Result := True;
end;

function DistanceToSegment(const P, A, B: TPointD): Double;
var
  dx, dy, len2, t: Double;
  projX, projY: Double;
begin
  dx := B.X - A.X;
  dy := B.Y - A.Y;
  len2 := dx * dx + dy * dy;
  if len2 = 0 then begin
    Result := Sqrt(Sqr(P.X - A.X) + Sqr(P.Y - A.Y));
    Exit;
  end;
  t := ((P.X - A.X) * dx + (P.Y - A.Y) * dy) / len2;
  if t < 0 then
    t := 0
  else if t > 1 then
    t := 1;
  projX := A.X + t * dx;
  projY := A.Y + t * dy;
  Result := Sqrt(Sqr(P.X - projX) + Sqr(P.Y - projY));
end;

function DistanceToLine(const P: TPointD; const Line: TPointArray): Double;
var
  i: Integer;
  d: Double;
begin
  if Length(Line) = 0 then begin
    Result := 1e300;
    Exit;
  end;
  if Length(Line) = 1 then begin
    Result := Sqrt(Sqr(P.X - Line[0].X) + Sqr(P.Y - Line[0].Y));
    Exit;
  end;
  Result := DistanceToSegment(P, Line[0], Line[1]);
  for i := 1 to High(Line) - 1 do begin
    d := DistanceToSegment(P, Line[i], Line[i + 1]);
    if d < Result then
      Result := d;
  end;
end;

function DistanceToGeometry(const P: TPointD; const G: TFeatureGeometry): Double;
var
  i: Integer;
  d: Double;
begin
  case G.Kind of
    gkPoint:
      if Length(G.Points) > 0 then
        Result := Sqrt(Sqr(P.X - G.Points[0].X) + Sqr(P.Y - G.Points[0].Y))
      else
        Result := 1e300;

    gkLineString:
      Result := DistanceToLine(P, G.Points);

    gkPolygon:
      if PointInPolygon(P, G.Rings) then
        Result := 0
      else begin
        Result := 1e300;
        for i := 0 to High(G.Rings) do begin
          d := DistanceToLine(P, G.Rings[i]);
          if d < Result then
            Result := d;
        end;
      end;

    gkMultiPoint, gkMultiLineString, gkMultiPolygon:
      begin
        Result := 1e300;
        for i := 0 to High(G.Parts) do begin
          d := DistanceToGeometry(P, G.Parts[i]);
          if d < Result then
            Result := d;
        end;
      end;
  else
    Result := 1e300;
  end;
end;

function FindNearestFeature(const Features: TFeatureArray; const P: TPointD;
  out Index: Integer): Double;
var
  i: Integer;
  d: Double;
begin
  Index := -1;
  Result := 1e300;
  for i := 0 to High(Features) do begin
    d := DistanceToGeometry(P, Features[i].Geometry);
    if d < Result then begin
      Result := d;
      Index := i;
    end;
  end;
end;

end.
