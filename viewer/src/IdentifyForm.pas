unit IdentifyForm;

interface

uses
  System.Classes,
  System.SysUtils,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Grids,
  GeometryModel;

type
  {
    Dialogo no modal que muestra los atributos (nombre/valor) de una entidad.
    Se construye por codigo (sin .dfm) para simplificar.
  }
  TIdentifyForm = class(TForm)
  private
    FGrid: TStringGrid;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ShowFeature(const Feature: TFeature);
  end;

implementation

constructor TIdentifyForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'Atributos de la entidad';
  Width := 440;
  Height := 340;
  Position := poOwnerFormCenter;

  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.ColCount := 2;
  FGrid.RowCount := 2;
  FGrid.FixedCols := 0;
  FGrid.FixedRows := 1;
  FGrid.Cells[0, 0] := 'Campo';
  FGrid.Cells[1, 0] := 'Valor';
  FGrid.ColWidths[0] := 150;
  FGrid.ColWidths[1] := 270;
  FGrid.Options := FGrid.Options + [goColSizing, goRowSelect];
end;

procedure TIdentifyForm.ShowFeature(const Feature: TFeature);
var
  i: Integer;
begin
  FGrid.RowCount := Length(Feature.Attributes) + 2;
  FGrid.Cells[0, 1] := 'FID';
  FGrid.Cells[1, 1] := IntToStr(Feature.FID);
  for i := 0 to High(Feature.Attributes) do begin
    FGrid.Cells[0, i + 2] := Feature.Attributes[i].Name;
    FGrid.Cells[1, i + 2] := Feature.Attributes[i].Value;
  end;
end;

end.
