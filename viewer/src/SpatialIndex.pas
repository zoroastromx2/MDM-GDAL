unit SpatialIndex;

interface

uses
  System.Generics.Collections,
  System.Generics.Defaults;

type
  TBBox = record
    MinX, MinY, MaxX, MaxY: Double;
  end;

  TIndexEntry = record
    Box: TBBox;
    Index: Integer;
  end;

  TNode = record
    IsLeaf: Boolean;
    Entries: array of TIndexEntry;   // hoja: Index = índice de entidad; interno: Index = nodo hijo
  end;

  {
    R-tree en memoria, construido por bulk-load (todos los bboxes se conocen de
    una vez, tras extraer las entidades). Puro: sin VCL ni GDAL.
  }
  TSpatialIndex = class
  private
    FNodes: array of TNode;
    FRoot: Integer;
    FMaxEntries: Integer;
    function AddNode(const Node: TNode): Integer;
    function BuildLevel(const Entries: array of TIndexEntry): Integer;
    function NodeBBox(NodeIndex: Integer): TBBox;
    procedure QueryNode(NodeIndex: Integer; const Box: TBBox;
      Results: TList<Integer>);
  public
    constructor Create(MaxEntries: Integer = 16);
    procedure Build(const Entries: array of TIndexEntry);
    function Query(const Box: TBBox): TArray<Integer>;
  end;

function MakeBox(const MinX, MinY, MaxX, MaxY: Double): TBBox;
function BBoxIntersects(const A, B: TBBox): Boolean;
function BBoxUnion(const A, B: TBBox): TBBox;

implementation

function MakeBox(const MinX, MinY, MaxX, MaxY: Double): TBBox;
begin
  Result.MinX := MinX;
  Result.MinY := MinY;
  Result.MaxX := MaxX;
  Result.MaxY := MaxY;
end;

function BBoxIntersects(const A, B: TBBox): Boolean;
begin
  Result := (A.MinX <= B.MaxX) and (A.MaxX >= B.MinX) and
            (A.MinY <= B.MaxY) and (A.MaxY >= B.MinY);
end;

function BBoxUnion(const A, B: TBBox): TBBox;
begin
  Result := A;
  if B.MinX < Result.MinX then Result.MinX := B.MinX;
  if B.MaxX > Result.MaxX then Result.MaxX := B.MaxX;
  if B.MinY < Result.MinY then Result.MinY := B.MinY;
  if B.MaxY > Result.MaxY then Result.MaxY := B.MaxY;
end;

constructor TSpatialIndex.Create(MaxEntries: Integer = 16);
begin
  inherited Create;
  FMaxEntries := MaxEntries;
  if FMaxEntries < 2 then
    FMaxEntries := 2;
  FRoot := -1;
end;

function TSpatialIndex.AddNode(const Node: TNode): Integer;
begin
  SetLength(FNodes, Length(FNodes) + 1);
  Result := High(FNodes);
  FNodes[Result] := Node;
end;

function TSpatialIndex.NodeBBox(NodeIndex: Integer): TBBox;
var
  i: Integer;
  node: TNode;
begin
  node := FNodes[NodeIndex];
  Result := node.Entries[0].Box;
  for i := 1 to High(node.Entries) do
    Result := BBoxUnion(Result, node.Entries[i].Box);
end;

function TSpatialIndex.BuildLevel(const Entries: array of TIndexEntry): Integer;
var
  n, groupCount, i, j, start, cnt, child: Integer;
  sorted: array of TIndexEntry;
  childEntries: array of TIndexEntry;
  node: TNode;
begin
  n := Length(Entries);

  if n <= FMaxEntries then begin
    node.IsLeaf := True;
    SetLength(node.Entries, n);
    for i := 0 to n - 1 do
      node.Entries[i] := Entries[i];
    Result := AddNode(node);
    Exit;
  end;

  { ordenar por centro X para empaquetar con localidad espacial }
  SetLength(sorted, n);
  for i := 0 to n - 1 do
    sorted[i] := Entries[i];
  TArray.Sort<TIndexEntry>(sorted, TComparer<TIndexEntry>.Construct(
    function(const A, B: TIndexEntry): Integer
    var
      ca, cb: Double;
    begin
      ca := A.Box.MinX + A.Box.MaxX;
      cb := B.Box.MinX + B.Box.MaxX;
      if ca < cb then
        Result := -1
      else if ca > cb then
        Result := 1
      else
        Result := 0;
    end));

  groupCount := (n + FMaxEntries - 1) div FMaxEntries;
  node.IsLeaf := False;
  SetLength(node.Entries, groupCount);
  for i := 0 to groupCount - 1 do begin
    start := i * FMaxEntries;
    cnt := FMaxEntries;
    if start + cnt > n then
      cnt := n - start;
    SetLength(childEntries, cnt);
    for j := 0 to cnt - 1 do
      childEntries[j] := sorted[start + j];
    child := BuildLevel(childEntries);
    node.Entries[i].Index := child;
    node.Entries[i].Box := NodeBBox(child);
  end;
  Result := AddNode(node);
end;

procedure TSpatialIndex.Build(const Entries: array of TIndexEntry);
begin
  FNodes := nil;
  if Length(Entries) = 0 then begin
    FRoot := -1;
    Exit;
  end;
  FRoot := BuildLevel(Entries);
end;

procedure TSpatialIndex.QueryNode(NodeIndex: Integer; const Box: TBBox;
  Results: TList<Integer>);
var
  i: Integer;
  node: TNode;
begin
  node := FNodes[NodeIndex];
  if node.IsLeaf then begin
    for i := 0 to High(node.Entries) do
      if BBoxIntersects(node.Entries[i].Box, Box) then
        Results.Add(node.Entries[i].Index);
  end
  else begin
    for i := 0 to High(node.Entries) do
      if BBoxIntersects(node.Entries[i].Box, Box) then
        QueryNode(node.Entries[i].Index, Box, Results);
  end;
end;

function TSpatialIndex.Query(const Box: TBBox): TArray<Integer>;
var
  results: TList<Integer>;
begin
  results := TList<Integer>.Create;
  try
    if FRoot >= 0 then
      QueryNode(FRoot, Box, results);
    Result := results.ToArray;
  finally
    results.Free;
  end;
end;

end.
