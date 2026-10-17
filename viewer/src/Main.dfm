object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'IRIS Viewer - Visor de datos vectoriales'
  ClientHeight = 600
  ClientWidth = 900
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = MainMenu1
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object StatusBar1: TStatusBar
    Left = 0
    Top = 578
    Width = 900
    Height = 22
    Panels = <>
    SimplePanel = True
  end
  object MainMenu1: TMainMenu
    Left = 88
    Top = 152
    object miFile: TMenuItem
      Caption = 'Archivo'
      object miFileOpen: TMenuItem
        Caption = 'Abrir...'
        OnClick = miFileOpenClick
      end
      object N1: TMenuItem
        Caption = '-'
      end
      object miFileExit: TMenuItem
        Caption = 'Salir'
        OnClick = miFileExitClick
      end
    end
    object miView: TMenuItem
      Caption = 'Ver'
      object miViewZoomIn: TMenuItem
        Caption = 'Acercar'
        OnClick = miViewZoomInClick
      end
      object miViewZoomOut: TMenuItem
        Caption = 'Alejar'
        OnClick = miViewZoomOutClick
      end
      object miViewFit: TMenuItem
        Caption = 'Ajustar a extensi'#243'n'
        OnClick = miViewFitClick
      end
      object N2: TMenuItem
        Caption = '-'
      end
      object miViewRubber: TMenuItem
        AutoCheck = True
        Caption = 'Zoom por caja'
        OnClick = miViewRubberClick
      end
    end
    object miHelp: TMenuItem
      Caption = 'Ayuda'
      object miHelpAbout: TMenuItem
        Caption = 'Acerca de...'
        OnClick = miHelpAboutClick
      end
    end
  end
  object OpenDialog1: TOpenDialog
    Left = 216
    Top = 144
  end
end
