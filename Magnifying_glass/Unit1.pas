unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, Math;

type
  TFLentille = class(TForm)
    procedure FLentilleCreate(Sender: TObject);
    procedure FLentilleMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FLentilleKeyPress(Sender: TObject; var Key: Char);
    procedure FLentilleClose(Sender: TObject; var Action: TCloseAction);
    procedure FLentillePaint(Sender: TObject);
  private
    { Déclarations privées }
  public
    { Déclarations publiques }
  end;

var
  FLentille: TFLentille;

implementation

{$R *.dfm}

type
 tdwordarray=array[0..0] of dword;
 pdwordarray= ^tdwordarray;
 TMyPoint=record x,y:extended; end;

var
  TableLent     : array of TMyPoint;  // matrice de l'effet
  fond,buffer   : tbitmap;            // image originale-finale
  PFond,Pbuffer : pdwordarray;        // pointeur vers les images
  tailleligne   : integer;            // largeur de l'image
  diametre      : integer  = 200;     // diametre de la loupe
  Hauteur       : integer  = 72;      // intensité de l'effet
  parametre     : extended = 10;      // autre parametre
  Typeloupe     : integer  = 1;       // type de loupe
  filtre        : boolean  = true;    // anti aliasing oui/non
  inverse       : boolean  = false;   // couleur negatif oui/non

// précalcul de la matrice d'effet de lentille
procedure PreCalcul;
var
 ux,uy: integer;
 z,rayon,rx,ry,tx,ty,rayonmaxi:extended;
 angle:extended;
begin
 setlength( TableLent,diametre*diametre);
 fillchar(TableLent[0],diametre*diametre*sizeof(tmypoint),255);
 rayonmaxi:=sqrt(diametre*diametre)/2;
 for uy := 0 to diametre-1 do
  for ux := 0 to diametre-1 do
   begin
    rx:=ux-diametre/2;
    ry:=uy-diametre/2;
    rayon:=sqrt(rx*rx+ry*ry);
    tx:=0;
    ty:=0;
    if rayon>rayonmaxi then continue;
    case Typeloupe of
     1:
      begin
       z:=sqrt(diametre*diametre/4-rx*rx-ry*ry);
       if z=0 then continue;
       tx:=(Hauteur-z)*rx/z;
       ty:=(Hauteur-z)*ry/z;
      end;
     2:
      begin
       if hauteur=0 then exit;
       tx:=-rx*parametre/hauteur;
       ty:=-ry*parametre/hauteur;
      end;
     3:
      begin
       angle:=arctan2(ry,rx);
       rayon:=rayonmaxi-rayon;
       tx :=hauteur*rayon*cos(angle)/300;
       ty :=hauteur*rayon*sin(angle)/300;
      end;
     4:
      begin
       if hauteur=0 then exit;
       tx :=rx*parametre/hauteur;
       ty :=ry*parametre/hauteur;
      end;
     5:
      begin
       angle:=arctan2(ry,rx);
       tx :=rayon*cos(angle-(rayonmaxi-rayon)/hauteur)-rx;
       ty :=rayon*sin(angle-(rayonmaxi-rayon)/hauteur)-ry;
      end;
     6:
      begin
       angle:=arctan2(ry,rx);
       rayon:=rayonmaxi-rayon;
       z:=sin(rayon*parametre/rayonmaxi)*hauteur;
       tx :=cos(angle)*z;
       ty :=sin(angle)*z;
      end;
    end;
    TableLent[ux+uy*diametre].x:=tx;
    TableLent[ux+uy*diametre].y:=ty;
   end;
end;

// x et y sont-ils bien dans l'image???
function xyok(x,y:integer):boolean;
begin
 result:=(x>=0) and (y>=0) and (x<fond.Width) and (y<fond.Height);
end;

procedure TFLentille.FLentilleCreate(Sender: TObject);
begin
 // arrondi vers le bas pour le calcul par interpolation
 SetRoundMode(rmDown);
 //précalcul les coefficients de la lentille
 PreCalcul;
 // crée l'image de fond (capture de l'écran)
 fond:=tbitmap.Create;
 fond.Width:=screen.Width;
 fond.Height:=screen.Height;
 fond.PixelFormat:=pf32bit;
 // copie l'image de l'écran comme il est maintenant
 BitBlt(fond.Canvas.Handle,0,0,fond.Width,fond.Height,getdc(0),0,0,cmSrcCopy);
 pfond:=fond.ScanLine[fond.Height-1];

 buffer:=tbitmap.Create;
 buffer.Width:=screen.Width;
 buffer.Height:=screen.Height;
 buffer.PixelFormat:=pf32bit;
 pbuffer:=buffer.ScanLine[buffer.height-1];
 tailleligne:=BytesPerScanline(buffer.Width, 8, 32);
end;     

//cherche la couleur du pixel (x,y) par interpolation
function GetXYColorlinear(x,y:extended):tcolor;
var
 tx,ty:integer;
 dx1,dy1,dx2,dy2:integer;
 p1,p2,p3,p4:integer;
 c1,c2,c3,c4:tagRGBQUAD;
 zero:integer;
begin
 dx1:=round((1-(x-trunc(x)))*256);
 dy1:=round((1-(y-trunc(y)))*256);
 dx2:=256-dx1;
 dy2:=256-dy1;
 p1:=dx1*dy1;
 p2:=dx2*dy1;
 p3:=dx2*dy2;
 p4:=dx1*dy2;
 tx:=round(x);
 ty:=round(y);
 zero:=0;
 if xyok(tx,ty)     then c1:=tagRGBQUAD(pfond[tx  +(ty  )*tailleligne]) else c1:=tagRGBQUAD(zero);
 if xyok(tx+1,ty)   then c2:=tagRGBQUAD(pfond[tx+1+(ty  )*tailleligne]) else c2:=tagRGBQUAD(zero);
 if xyok(tx+1,ty+1) then c3:=tagRGBQUAD(pfond[tx+1+(ty+1)*tailleligne]) else c3:=tagRGBQUAD(zero);
 if xyok(tx,ty+1)   then c4:=tagRGBQUAD(pfond[tx  +(ty+1)*tailleligne]) else c4:=tagRGBQUAD(zero);
 tagRGBQUAD(result).rgbBlue:=(c1.rgbBlue        *p1+c2.rgbBlue    *p2+c3.rgbBlue    *p3+c4.rgbBlue    *p4) div 65536;
 tagRGBQUAD(result).rgbGreen:=(c1.rgbGreen      *p1+c2.rgbGreen   *p2+c3.rgbGreen   *p3+c4.rgbGreen   *p4) div 65536;
 tagRGBQUAD(result).rgbRed:=(c1.rgbRed          *p1+c2.rgbRed     *p2+c3.rgbRed     *p3+c4.rgbRed     *p4) div 65536;
 tagRGBQUAD(result).rgbReserved:=0;
end;

//cherche la couleur du pixel (x,y) par simple arroundi
function GetXYColor(x,y:extended):tcolor;
var
 tx,ty:integer;
begin
 tx:=round(x);
 ty:=round(y);
 if xyok(tx,ty)     then result:=pfond[tx+(ty)*tailleligne] else result:=0;
end;

//calcul la couleur negative de c
procedure negatif(var c:integer);
begin
 tagRGBQUAD(c).rgbBlue:=255-tagRGBQUAD(c).rgbBlue;
 tagRGBQUAD(c).rgbGreen:=255-tagRGBQUAD(c).rgbGreen;
 tagRGBQUAD(c).rgbRed:=255-tagRGBQUAD(c).rgbRed;
end;

procedure TFLentille.FLentilleMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
 ix,iy,c,offset: integer;
 a,b:extended;
begin
 // le buffer à la tête en bas...
 y:=fond.Height-y-diametre div 2;
 x:=x-diametre div 2;
 //dessine le fond
 buffer.Canvas.Draw(0,0,fond);
 // rajoute la lentille
  for iy := 0 to diametre-1 do
    for ix := 0 to diametre-1 do
     if xyok(ix+x,iy+y) then  // on ne trace pas les points en dehors de l'écran
      begin
       offset:=ix+iy*diametre;
       if not IsNan(TableLent[offset].x) then //nan = en dehors de la lentille
        begin
         //décalage du pixel courant
         a:=ix+x+TableLent[offset].x;
         b:=iy+y+TableLent[offset].y;
         // cherche la couleur du pixel à l'endroit (a,b)
         if filtre then c:=GetXYColorlinear(a,b)
                   else c:=GetXYColor(a,b);
         if inverse then negatif(c);
         //place le pixel de couleur c dans l'image
         pbuffer[ix+x+(iy+y)*tailleligne] :=c;
        end;
     end;
 //transfert le tout à l'écran
 Canvas.Draw(0,0,buffer);
end;

procedure TFLentille.FLentilleKeyPress(Sender: TObject; var Key: Char);
var
 mousepos:tpoint;
begin
 //change les paramètres de la lentille
 case key of
  #27:close;
  'a','A':hauteur:=hauteur+1;
  'q','Q':hauteur:=hauteur-1;
  'z','Z':diametre:=diametre+1;
  's','S':diametre:=diametre-1;
  'e','E':parametre:=parametre+0.1;
  'd','D':parametre:=parametre-0.1;
  '1'..'9':typeloupe:=byte(key)-48;
  'r','R':inverse:=not inverse;
  'f','F':filtre:=not filtre;
  end;
  //recalcul la matrice de la lentille
  PreCalcul;
  getcursorpos(mousepos);
  MouseMove([],mousepos.X,mousepos.Y);
end;

procedure TFLentille.FLentilleClose(Sender: TObject; var Action: TCloseAction);
begin
 // on detruit les objets
 OnPaint:=nil;
 OnMouseMove:=nil;
 fond.Free;
 buffer.Free;
end;

procedure TFLentille.FLentillePaint(Sender: TObject);
begin
 // on dessin simplement le buffer
 canvas.Draw(0,0,fond);
end;

end.