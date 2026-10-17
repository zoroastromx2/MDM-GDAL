unit LayerStyleForm;

interface

uses
  System.Classes,
  System.SysUtils,
  System.UITypes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Dialogs,
  VectorLayer;

type
  {
    Dialogo modal que edita las propiedades de estilo de una TVectorLayer:
    color de relleno, color de linea, relleno (transparente) y ancho de linea.
    Se construye por codigo (sin .dfm), como IdentifyForm.
  }
  TLayerStyleForm = class(TForm)
  private
    FLayer: TVectorLayer;
    FFillColor: TColor;
    FLineColor: TColor;
    FFillSwatch: TShape;
    FLineSwatch: TShape;
    FNoFill: TCheckBox;
    FWidth: TComboBox;
    FOk: TButton;
    FCancel: TButton;
    procedure PickFill(Sender: TObject);
    procedure PickLine(Sender: TObject);
    procedure UpdateSwatches;
    procedure Apply;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Execute(Layer: TVectorLayer);
  end;

implementation

constructor TLayerStyleForm.Create(AOwner: TComponent);
var
  lbl: TLabel;
  btn: TButton;
begin
  inherited CreateNew(AOwner);
  Caption := 'Propiedades de la capa';
  Width := 360;
  Height := 250;
  Position := poOwnerFormCenter;
  BorderStyle := bsDialog;

  lbl := TLabel.Create(Self);
  lbl.Parent := Self;
  lbl.SetBounds(20, 22, 120, 20);
  lbl.Caption := 'Relleno:';

  FFillSwatch := TShape.Create(Self);
  FFillSwatch.Parent := Self;
  FFillSwatch.SetBounds(150, 20, 28, 24);
  FFillSwatch.Shape := stSquare;

  btn := TButton.Create(Self);
  btn.Parent := Self;
  btn.SetBounds(190, 18, 120, 28);
  btn.Caption := 'Cambiar...';
  btn.OnClick := PickFill;

  lbl := TLabel.Create(Self);
  lbl.Parent := Self;
  lbl.SetBounds(20, 58, 120, 20);
  lbl.Caption := 'L'#237'nea:';

  FLineSwatch := TShape.Create(Self);
  FLineSwatch.Parent := Self;
  FLineSwatch.SetBounds(150, 56, 28, 24);
  FLineSwatch.Shape := stSquare;

  btn := TButton.Create(Self);
  btn.Parent := Self;
  btn.SetBounds(190, 54, 120, 28);
  btn.Caption := 'Cambiar...';
  btn.OnClick := PickLine;

  FNoFill := TCheckBox.Create(Self);
  FNoFill.Parent := Self;
  FNoFill.SetBounds(20, 92, 300, 20);
  FNoFill.Caption := 'Sin relleno (transparente)';

  lbl := TLabel.Create(Self);
  lbl.Parent := Self;
  lbl.SetBounds(20, 124, 120, 20);
  lbl.Caption := 'Ancho de l'#237'nea:';

  FWidth := TComboBox.Create(Self);
  FWidth.Parent := Self;
  FWidth.SetBounds(150, 122, 100, 22);
  FWidth.Style := csDropDownList;
  FWidth.Items.Add('1');
  FWidth.Items.Add('2');
  FWidth.Items.Add('3');
  FWidth.Items.Add('4');
  FWidth.Items.Add('5');
  FWidth.Items.Add('8');
  FWidth.Items.Add('10');
  FWidth.ItemIndex := 0;

  FOk := TButton.Create(Self);
  FOk.Parent := Self;
  FOk.SetBounds(140, 170, 90, 30);
  FOk.Caption := 'Aceptar';
  FOk.Default := True;
  FOk.ModalResult := mrOk;

  FCancel := TButton.Create(Self);
  FCancel.Parent := Self;
  FCancel.SetBounds(240, 170, 90, 30);
  FCancel.Caption := 'Cancelar';
  FCancel.Cancel := True;
  FCancel.ModalResult := mrCancel;
end;

procedure TLayerStyleForm.PickFill(Sender: TObject);
var
  dlg: TColorDialog;
begin
  dlg := TColorDialog.Create(Self);
  try
    dlg.Color := FFillColor;
    if dlg.Execute then
      FFillColor := dlg.Color;
  finally
    dlg.Free;
  end;
  UpdateSwatches;
end;

procedure TLayerStyleForm.PickLine(Sender: TObject);
var
  dlg: TColorDialog;
begin
  dlg := TColorDialog.Create(Self);
  try
    dlg.Color := FLineColor;
    if dlg.Execute then
      FLineColor := dlg.Color;
  finally
    dlg.Free;
  end;
  UpdateSwatches;
end;

procedure TLayerStyleForm.UpdateSwatches;
begin
  FFillSwatch.Brush.Color := FFillColor;
  FLineSwatch.Brush.Color := FLineColor;
end;

procedure TLayerStyleForm.Apply;
var
  w: Integer;
begin
  if FLayer = nil then
    Exit;
  FLayer.FillColor := FFillColor;
  FLayer.LineColor := FLineColor;
  FLayer.FillEnabled := not FNoFill.Checked;
  w := StrToIntDef(FWidth.Text, 1);
  if w < 1 then w := 1;
  if w > 20 then w := 20;
  FLayer.LineWidth := w;
end;

procedure TLayerStyleForm.Execute(Layer: TVectorLayer);
var
  i: Integer;
begin
  FLayer := Layer;
  FFillColor := Layer.FillColor;
  FLineColor := Layer.LineColor;
  FNoFill.Checked := not Layer.FillEnabled;
  i := FWidth.Items.IndexOf(IntToStr(Layer.LineWidth));
  if i >= 0 then
    FWidth.ItemIndex := i
  else
    FWidth.ItemIndex := 0;
  UpdateSwatches;
  if ShowModal = mrOk then
    Apply;
end;

end.
