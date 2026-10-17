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

type
  {
    Dialogo no modal que muestra la tabla de atributos completa de una capa:
    una fila por entidad, columnas = FID + campos. Se construye por codigo.
  }
  TAttributesForm = class(TForm)
  private
    FGrid: TStringGrid;
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
  cols, i, j: Integer;
  f: TFeature;
begin
  if Layer = nil then
    Exit;

  cols := 1 + Layer.FieldCount;
  FGrid.ColCount := cols;
  FGrid.RowCount := Layer.FeatureCount + 1;

  FGrid.Cells[0, 0] := 'FID';
  for i := 0 to Layer.FieldCount - 1 do
    FGrid.Cells[i + 1, 0] := Layer.FieldNames[i];

  for i := 0 to Layer.FeatureCount - 1 do begin
    f := Layer.Features[i];
    FGrid.Cells[0, i + 1] := IntToStr(f.FID);
    for j := 0 to High(f.Attributes) do
      FGrid.Cells[j + 1, i + 1] := f.Attributes[j].Value;
  end;

  Caption := 'Atributos de la capa - ' + Layer.LayerName;
end;

end.
