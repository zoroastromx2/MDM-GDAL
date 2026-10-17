program GdalViewer;

uses
  Vcl.Forms,
  Main in 'src\Main.pas' {MainForm};

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
