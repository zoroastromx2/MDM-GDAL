unit AttributesForm;

interface

uses
  System.Classes,
  System.SysUtils,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Grids,
  GeometryModel,
  VectorLayer;

const
  { Maximo de filas que se vuelcan en la grilla para no congelar la UI en
    capas enormes (la virtualizacion/paginacion completa queda como fase
    posterior). }
  AMaxAttributeRows = 10000;

type
  {
    Dialogo no modal que muestra la tabla de atributos completa de una capa:
    una fila por entidad, columnas = FID + campos. Los atributos se leen bajo
    demanda (recorrido unico del datasource) y se vuelcan en la grilla.
    Se construye por codigo.
  }
  TAttributesForm = class(TForm)
  private
    FGrid: TStringGrid;
    FLayer: TVectorLayer;
    FRow: Integer;
    FMaxRows: Integer;
    function AddRow(const Values: TStringArray): Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ShowLayer(const Layer: TVectorLayer);
  end;

implementation

constructor TAttributesForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'Atributos de la capa';
  Width := 640;
  Height := 420;
  Position := poOwnerFormCenter;

  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.FixedRows := 1;
  FGrid.FixedCols := 0;
  FGrid.RowCount := 2;
  FGrid.ColCount := 2;
  FGrid.Options := FGrid.Options + [goColSizing, goRowSelect, goThumbTracking];
end;

procedure TAttributesForm.ShowLayer(const Layer: TVectorLayer);
var
  i: Integer;
begin
  if Layer = nil then
    Exit;

  FLayer := Layer;
  FRow := 0;
  FMaxRows := Layer.FeatureCount;
  if FMaxRows > AMaxAttributeRows then
    FMaxRows := AMaxAttributeRows;

  FGrid.ColCount := 1 + Layer.FieldCount;
  FGrid.RowCount := FMaxRows + 1;

  FGrid.Cells[0, 0] := 'FID';
  for i := 0 to Layer.FieldCount - 1 do
    FGrid.Cells[i + 1, 0] := Layer.FieldNames[i];

  Layer.ForEachAttributeRow(AddRow);

  if FMaxRows < Layer.FeatureCount then
    Caption := Format('Atributos de la capa - %s (mostrando %d de %d)',
      [Layer.LayerName, FMaxRows, Layer.FeatureCount])
  else
    Caption := 'Atributos de la capa - ' + Layer.LayerName;
end;

function TAttributesForm.AddRow(const Values: TStringArray): Boolean;
var
  i: Integer;
begin
  Inc(FRow);
  if (FLayer <> nil) and (FRow - 1 < FLayer.FeatureCount) then
    FGrid.Cells[0, FRow] := IntToStr(FLayer.Features[FRow - 1].FID);
  for i := 0 to High(Values) do
    FGrid.Cells[i + 1, FRow] := Values[i];
  if (FRow mod 500) = 0 then begin
    Caption := Format('Cargando atributos... %d / %d', [FRow, FMaxRows]);
    Application.ProcessMessages;
  end;
  Result := FRow < FMaxRows;
end;

end.
