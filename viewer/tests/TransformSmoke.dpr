program TransformSmoke;

{$APPTYPE CONSOLE}

uses
  GeometryModel,
  MapView,
  SysUtils;

var
  Failed: Integer;
  Checks: Integer;

procedure Check(Cond: Boolean; const Msg: string);
begin
  Inc(Checks);
  if not Cond then begin
    Inc(Failed);
    WriteLn('FAIL: ', Msg);
  end;
end;

procedure CheckClose(A, B, Eps: Double; const Msg: string);
begin
  Check(Abs(A - B) <= Eps, Format('%s (got %.9f, want %.9f)', [Msg, A, B]));
end;

procedure TestGeometryModel;
var
  P: TPointD;
  G: TFeatureGeometry;
  Ring: TPointArray;
  F: TFeatureArray;
  E: TExtent;
begin
  P := MakePoint(3, 4);
  CheckClose(P.X, 3, 1e-9, 'MakePoint.X');
  CheckClose(P.Y, 4, 1e-9, 'MakePoint.Y');

  G := MakePolygon([]);
  Check(GeometryIsEmpty(G), 'empty polygon is empty');

  SetLength(Ring, 2);
  Ring[0] := MakePoint(0, 0);
  Ring[1] := MakePoint(1, 1);
  G := MakeLine(Ring);
  Check(not GeometryIsEmpty(G), 'line with points is not empty');

  SetLength(Ring, 4);
  Ring[0] := MakePoint(0, 0);
  Ring[1] := MakePoint(10, 0);
  Ring[2] := MakePoint(0, 10);
  Ring[3] := MakePoint(0, 0);
  G := MakePolygon([Ring]);
  SetLength(F, 1);
  F[0].Geometry := G;
  E := FeaturesExtent(F);

  Check(not E.IsEmpty, 'extent not empty');
  CheckClose(E.MinX, 0, 1e-9, 'extent MinX');
  CheckClose(E.MaxX, 10, 1e-9, 'extent MaxX');
  CheckClose(E.MinY, 0, 1e-9, 'extent MinY');
  CheckClose(E.MaxY, 10, 1e-9, 'extent MaxY');
  CheckClose(ExtentWidth(E), 10, 1e-9, 'extent width');
  CheckClose(ExtentHeight(E), 10, 1e-9, 'extent height');

  P := ExtentCenter(E);
  CheckClose(P.X, 5, 1e-9, 'extent center X');
  CheckClose(P.Y, 5, 1e-9, 'extent center Y');
end;

procedure TestMapView;
var
  V: TMapView;
  P, W, WBefore, WAfter: TPointD;
  s0x, s0y, s1x, s1y, sx, sy: Double;
begin
  V := TMapView.Create;
  try
    V.CenterWorld := MakePoint(100, 200);
    V.Scale := 2.5;
    V.ViewportW := 800;
    V.ViewportH := 600;

    { ida y vuelta mundo <-> pantalla }
    P := MakePoint(123.456, 789.012);
    V.WorldToScreen(P, sx, sy);
    W := V.ScreenToWorld(sx, sy);
    CheckClose(W.X, P.X, 1e-6, 'round-trip X');
    CheckClose(W.Y, P.Y, 1e-6, 'round-trip Y');

    { zoom anclado: el punto bajo el cursor no se mueve }
    WBefore := V.ScreenToWorld(300, 200);
    V.ZoomBy(2.0, 300, 200);
    WAfter := V.ScreenToWorld(300, 200);
    CheckClose(WBefore.X, WAfter.X, 1e-6, 'zoom anchored X');
    CheckClose(WBefore.Y, WAfter.Y, 1e-6, 'zoom anchored Y');

    { pan: un punto fijo del mundo se desplaza (dx, dy) en pantalla }
    P := MakePoint(50, 50);
    V.WorldToScreen(P, s0x, s0y);
    V.PanBy(120, -30);
    V.WorldToScreen(P, s1x, s1y);
    CheckClose(s1x - s0x, 120, 1e-6, 'pan X');
    CheckClose(s1y - s0y, -30, 1e-6, 'pan Y');

    { fit: las esquinas del bounding box quedan dentro del viewport }
    V.FitBounds(MakePoint(0, 0), MakePoint(10, 20), 800, 600, 0.1);
    V.WorldToScreen(MakePoint(0, 20), sx, sy);
    Check((sx >= 0) and (sx <= 800) and (sy >= 0) and (sy <= 600),
      'fit: esquina (0,20) dentro');
    V.WorldToScreen(MakePoint(10, 0), sx, sy);
    Check((sx >= 0) and (sx <= 800) and (sy >= 0) and (sy <= 600),
      'fit: esquina (10,0) dentro');
  finally
    V.Free;
  end;
end;

procedure TestHitTest;
var
  Outer, Hole, LinePts: TPointArray;
  Poly: TFeatureGeometry;
  Feats: TFeatureArray;
  idx: Integer;
  d: Double;
begin
  SetLength(Outer, 5);
  Outer[0] := MakePoint(0, 0);
  Outer[1] := MakePoint(10, 0);
  Outer[2] := MakePoint(10, 10);
  Outer[3] := MakePoint(0, 10);
  Outer[4] := MakePoint(0, 0);
  SetLength(Hole, 5);
  Hole[0] := MakePoint(2, 2);
  Hole[1] := MakePoint(4, 2);
  Hole[2] := MakePoint(4, 4);
  Hole[3] := MakePoint(2, 4);
  Hole[4] := MakePoint(2, 2);
  Poly := MakePolygon([Outer, Hole]);

  Check(PointInPolygon(MakePoint(5, 5), Poly.Rings), 'punto dentro del poligono');
  Check(not PointInPolygon(MakePoint(3, 3), Poly.Rings), 'punto dentro del agujero');
  Check(not PointInPolygon(MakePoint(15, 15), Poly.Rings), 'punto fuera del poligono');
  CheckClose(DistanceToGeometry(MakePoint(5, 5), Poly), 0, 1e-9,
    'distancia a punto interior = 0');

  SetLength(Feats, 2);
  Feats[0].Geometry := Poly;
  SetLength(LinePts, 2);
  LinePts[0] := MakePoint(20, 20);
  LinePts[1] := MakePoint(21, 20);
  Feats[1].Geometry := MakeLine(LinePts);

  d := FindNearestFeature(Feats, MakePoint(19, 20), idx);
  Check(idx = 1, 'la entidad mas cercana es la 1 (linea)');
  CheckClose(d, 1, 1e-6, 'distancia al punto mas cercano');
end;

begin
  Failed := 0;
  Checks := 0;

  TestGeometryModel;
  TestMapView;
  TestHitTest;

  if Failed = 0 then
    WriteLn(Format('OK: %d checks passed', [Checks]))
  else
    WriteLn(Format('%d of %d checks FAILED', [Failed, Checks]));

  if Failed > 0 then
    Halt(1);
end.
