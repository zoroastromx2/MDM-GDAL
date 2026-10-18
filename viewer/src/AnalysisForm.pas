unit AnalysisForm;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.Dialogs,
  VectorLayer,
  VectorAnalysis;

type
  TAnalysisOp = (aoBuffer, aoIntersection, aoUnion);

  {
    Diálogo modal que ejecuta un análisis vectorial (buffer / intersección /
    unión) sobre capas cargadas y devuelve la ruta del GeoPackage generado.
    Se construye por código.
  }
  TAnalysisForm = class(TForm)
  private
    FLayers: TList<TVectorLayer>;
    FOp: TAnalysisOp;
    FComboA: TComboBox;
    FComboB: TComboBox;
    FEditDist: TEdit;
    FEditOut: TEdit;
    procedure SaveClick(Sender: TObject);
    function SelectedLayer(Combo: TComboBox): TVectorLayer;
    procedure Run;
  public
    constructor Create(AOwner: TComponent); override;
    function Execute(const Layers: TList<TVectorLayer>; Op: TAnalysisOp;
      out OutFile: string): Boolean;
  end;

implementation

constructor TAnalysisForm.Create(AOwner: TComponent);
var
  lbl: TLabel;
  btn: TButton;
begin
  inherited CreateNew(AOwner);
  Caption := 'Análisis vectorial';
  Width := 400;
  Height := 300;
  Position := poOwnerFormCenter;
  BorderStyle := bsDialog;

  lbl := TLabel.Create(Self);
  lbl.Parent := Self;
  lbl.SetBounds(20, 20, 120, 20);
  lbl.Caption := 'Capa A:';

  FComboA := TComboBox.Create(Self);
  FComboA.Parent := Self;
  FComboA.SetBounds(140, 18, 230, 22);
  FComboA.Style := csDropDownList;

  lbl := TLabel.Create(Self);
  lbl.Parent := Self;
  lbl.SetBounds(20, 52, 120, 20);
  lbl.Caption := 'Capa B:';

  FComboB := TComboBox.Create(Self);
  FComboB.Parent := Self;
  FComboB.SetBounds(140, 50, 230, 22);
  FComboB.Style := csDropDownList;

  lbl := TLabel.Create(Self);
  lbl.Parent := Self;
  lbl.SetBounds(20, 84, 120, 20);
  lbl.Caption := 'Distancia:';

  FEditDist := TEdit.Create(Self);
  FEditDist.Parent := Self;
  FEditDist.SetBounds(140, 82, 100, 22);
  FEditDist.Text := '10';

  lbl := TLabel.Create(Self);
  lbl.Parent := Self;
  lbl.SetBounds(20, 116, 120, 20);
  lbl.Caption := 'Salida:';

  FEditOut := TEdit.Create(Self);
  FEditOut.Parent := Self;
  FEditOut.SetBounds(140, 114, 170, 22);
  FEditOut.ReadOnly := True;

  btn := TButton.Create(Self);
  btn.Parent := Self;
  btn.SetBounds(316, 112, 54, 26);
  btn.Caption := '...';
  btn.OnClick := SaveClick;

  btn := TButton.Create(Self);
  btn.Parent := Self;
  btn.SetBounds(140, 160, 90, 30);
  btn.Caption := 'Ejecutar';
  btn.Default := True;
  btn.ModalResult := mrOk;

  btn := TButton.Create(Self);
  btn.Parent := Self;
  btn.SetBounds(240, 160, 90, 30);
  btn.Caption := 'Cancelar';
  btn.Cancel := True;
  btn.ModalResult := mrCancel;
end;

procedure TAnalysisForm.SaveClick(Sender: TObject);
var
  dlg: TSaveDialog;
begin
  dlg := TSaveDialog.Create(Self);
  try
    dlg.Filter := 'GeoPackage|*.gpkg';
    dlg.DefaultExt := 'gpkg';
    if dlg.Execute then
      FEditOut.Text := dlg.FileName;
  finally
    dlg.Free;
  end;
end;

function TAnalysisForm.SelectedLayer(Combo: TComboBox): TVectorLayer;
begin
  if (Combo = nil) or (Combo.ItemIndex < 0) then
    Result := nil
  else
    Result := TVectorLayer(Combo.Items.Objects[Combo.ItemIndex]);
end;

procedure TAnalysisForm.Run;
var
  a, b: TVectorLayer;
  dist: Double;
  outName: string;
begin
  if FEditOut.Text = '' then begin
    ShowMessage('Seleccione un archivo de salida.');
    ModalResult := mrNone;
    Exit;
  end;

  a := SelectedLayer(FComboA);
  if a = nil then begin
    ShowMessage('Seleccione la capa A.');
    ModalResult := mrNone;
    Exit;
  end;

  outName := ChangeFileExt(ExtractFileName(FEditOut.Text), '');

  case FOp of
    aoBuffer: begin
      if not TryStrToFloat(FEditDist.Text, dist) or (dist <= 0) then begin
        ShowMessage('Distancia inválida (debe ser mayor que 0).');
        ModalResult := mrNone;
        Exit;
      end;
      TVectorAnalysis.Buffer(a, dist, FEditOut.Text, outName);
    end;
    aoIntersection, aoUnion: begin
      b := SelectedLayer(FComboB);
      if b = nil then begin
        ShowMessage('Seleccione la capa B.');
        ModalResult := mrNone;
        Exit;
      end;
      if FOp = aoIntersection then
        TVectorAnalysis.Intersection(a, b, FEditOut.Text, outName)
      else
        TVectorAnalysis.Union(a, b, FEditOut.Text, outName);
    end;
  end;
end;

function TAnalysisForm.Execute(const Layers: TList<TVectorLayer>; Op: TAnalysisOp;
  out OutFile: string): Boolean;
var
  i: Integer;
  tmp: string;
begin
  Result := False;
  OutFile := '';
  if (Layers = nil) or (Layers.Count = 0) then
    Exit;

  FLayers := Layers;
  FOp := Op;

  FComboA.Items.Clear;
  FComboB.Items.Clear;
  for i := 0 to Layers.Count - 1 do begin
    FComboA.Items.AddObject(Layers[i].LayerName, TObject(Layers[i]));
    FComboB.Items.AddObject(Layers[i].LayerName, TObject(Layers[i]));
  end;
  FComboA.ItemIndex := 0;
  FComboB.ItemIndex := 0;

  FEditDist.Enabled := (Op = aoBuffer);
  FComboB.Enabled := (Op <> aoBuffer);

  tmp := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) +
         'analisis.gpkg';
  FEditOut.Text := tmp;

  if ShowModal = mrOk then begin
    Run;
    if ModalResult = mrOk then begin
      OutFile := FEditOut.Text;
      Result := True;
    end;
  end;
end;

end.
