program Project1;

uses
  Forms,
  Unit1 in 'Unit1.pas' {FLentille};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFLentille, FLentille);
  Application.Run;
end.
